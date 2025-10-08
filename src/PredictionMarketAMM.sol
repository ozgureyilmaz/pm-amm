// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract PredictionMarketAMM is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    event MarketCreated(uint256 indexed marketId, string question, uint256 endTime, address indexed creator);
    event Trade(
        uint256 indexed marketId, address indexed trader, bool isYes, uint256 sharesOut, uint256 tokensIn, uint256 price
    );
    event LiquidityAdded(uint256 indexed marketId, address indexed provider, uint256 amount, uint256 lpTokens);
    event LiquidityRemoved(uint256 indexed marketId, address indexed provider, uint256 lpTokens, uint256 amount);
    event MarketResolved(uint256 indexed marketId, bool outcome, address indexed resolver);

    struct Market {
        uint256 id;
        string question;
        uint256 endTime;
        uint256 liquidityYes;
        uint256 liquidityNo;
        uint256 totalShares;
        bool resolved;
        bool outcome;
        address creator;
        uint256 fee;
    }

    IERC20 public immutable COLLATERAL_TOKEN;
    uint256 public nextMarketId;
    uint256 public constant MAX_FEE = 1000;
    uint256 public constant MIN_LIQUIDITY = 100e6;
    uint256 private constant PRECISION = 1e18;

    mapping(uint256 => Market) public markets;
    mapping(address => bool) public authorizedResolvers;
    mapping(uint256 => mapping(address => uint256)) public lpShares;
    mapping(uint256 => mapping(address => uint256)) public yesShares;
    mapping(uint256 => mapping(address => uint256)) public noShares;

    modifier onlyAuthorizedResolver() {
        require(authorizedResolvers[msg.sender] || msg.sender == owner(), "Not authorized resolver");
        _;
    }

    modifier marketExists(uint256 marketId) {
        require(marketId < nextMarketId, "Market does not exist");
        _;
    }

    modifier marketNotResolved(uint256 marketId) {
        require(!markets[marketId].resolved, "Market already resolved");
        _;
    }

    modifier marketNotExpired(uint256 marketId) {
        require(block.timestamp < markets[marketId].endTime, "Market expired");
        _;
    }

    constructor(address _collateralToken, address _owner) Ownable(_owner) {
        COLLATERAL_TOKEN = IERC20(_collateralToken);
    }

    function createMarket(string calldata question, uint256 endTime, uint256 initialLiquidity, uint256 fee)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 marketId)
    {
        require(endTime > block.timestamp, "End time must be in future");
        require(fee <= MAX_FEE, "Fee too high");
        require(initialLiquidity >= MIN_LIQUIDITY, "Insufficient initial liquidity");

        marketId = nextMarketId++;
        Market storage market = markets[marketId];

        market.id = marketId;
        market.question = question;
        market.endTime = endTime;
        market.creator = msg.sender;
        market.fee = fee;
        market.liquidityYes = initialLiquidity / 2;
        market.liquidityNo = initialLiquidity / 2;
        market.totalShares = initialLiquidity;

        lpShares[marketId][msg.sender] = initialLiquidity;
        COLLATERAL_TOKEN.safeTransferFrom(msg.sender, address(this), initialLiquidity);

        emit MarketCreated(marketId, question, endTime, msg.sender);
        emit LiquidityAdded(marketId, msg.sender, initialLiquidity, initialLiquidity);
    }

    function getPrice(uint256 marketId, bool isYes) public view marketExists(marketId) returns (uint256 price) {
        Market storage market = markets[marketId];

        if (market.resolved) {
            return (isYes == market.outcome) ? PRECISION : 0;
        }

        uint256 totalLiquidity = market.liquidityYes + market.liquidityNo;
        if (totalLiquidity == 0) return PRECISION / 2;

        if (isYes) {
            price = (market.liquidityNo * PRECISION) / totalLiquidity;
        } else {
            price = (market.liquidityYes * PRECISION) / totalLiquidity;
        }
    }

    function getSharesOut(uint256 marketId, bool isYes, uint256 tokensIn)
        public
        view
        marketExists(marketId)
        marketNotResolved(marketId)
        returns (uint256 sharesOut, uint256 effectivePrice)
    {
        Market storage market = markets[marketId];

        uint256 feeAmount = (tokensIn * market.fee) / 10000;
        uint256 netTokensIn = tokensIn - feeAmount;

        uint256 currentLiquidityTarget = isYes ? market.liquidityYes : market.liquidityNo;
        uint256 currentLiquidityOther = isYes ? market.liquidityNo : market.liquidityYes;

        uint256 newLiquidityOther = currentLiquidityOther + netTokensIn;
        uint256 newLiquidityTarget = (currentLiquidityTarget * currentLiquidityOther) / newLiquidityOther;

        sharesOut = currentLiquidityTarget - newLiquidityTarget;
        effectivePrice = sharesOut > 0 ? (tokensIn * PRECISION) / sharesOut : 0;
    }

    function trade(uint256 marketId, bool isYes, uint256 tokensIn, uint256 minSharesOut, uint256 deadline)
        external
        nonReentrant
        whenNotPaused
        marketExists(marketId)
        marketNotResolved(marketId)
        marketNotExpired(marketId)
    {
        require(block.timestamp <= deadline, "Transaction expired");
        require(tokensIn > 0, "Token amount must be positive");

        (uint256 sharesOut, uint256 effectivePrice) = getSharesOut(marketId, isYes, tokensIn);
        require(sharesOut >= minSharesOut, "Slippage exceeded");
        require(sharesOut > 0, "No shares available");

        Market storage market = markets[marketId];

        uint256 feeAmount = (tokensIn * market.fee) / 10000;
        uint256 netTokensIn = tokensIn - feeAmount;

        if (isYes) {
            market.liquidityNo += netTokensIn;
            market.liquidityYes -= sharesOut;
            yesShares[marketId][msg.sender] += sharesOut;
        } else {
            market.liquidityYes += netTokensIn;
            market.liquidityNo -= sharesOut;
            noShares[marketId][msg.sender] += sharesOut;
        }

        COLLATERAL_TOKEN.safeTransferFrom(msg.sender, address(this), tokensIn);
        emit Trade(marketId, msg.sender, isYes, sharesOut, tokensIn, effectivePrice);
    }

    function addLiquidity(uint256 marketId, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        marketExists(marketId)
        marketNotResolved(marketId)
    {
        require(amount > 0, "Amount must be positive");

        Market storage market = markets[marketId];

        uint256 lpTokens;
        if (market.totalShares == 0) {
            lpTokens = amount;
            market.liquidityYes = amount / 2;
            market.liquidityNo = amount / 2;
        } else {
            uint256 totalLiquidity = market.liquidityYes + market.liquidityNo;
            lpTokens = (amount * market.totalShares) / totalLiquidity;

            uint256 yesAmount = (amount * market.liquidityYes) / totalLiquidity;
            uint256 noAmount = amount - yesAmount;

            market.liquidityYes += yesAmount;
            market.liquidityNo += noAmount;
        }

        market.totalShares += lpTokens;
        lpShares[marketId][msg.sender] += lpTokens;

        COLLATERAL_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        emit LiquidityAdded(marketId, msg.sender, amount, lpTokens);
    }

    function removeLiquidity(uint256 marketId, uint256 lpTokens) external nonReentrant marketExists(marketId) {
        require(lpTokens > 0, "LP tokens must be positive");

        Market storage market = markets[marketId];
        require(lpShares[marketId][msg.sender] >= lpTokens, "Insufficient LP tokens");

        uint256 totalLiquidity = market.liquidityYes + market.liquidityNo;
        uint256 amountOut = (lpTokens * totalLiquidity) / market.totalShares;

        if (!market.resolved) {
            uint256 yesAmount = (lpTokens * market.liquidityYes) / market.totalShares;
            uint256 noAmount = (lpTokens * market.liquidityNo) / market.totalShares;

            market.liquidityYes -= yesAmount;
            market.liquidityNo -= noAmount;
        }

        lpShares[marketId][msg.sender] -= lpTokens;
        market.totalShares -= lpTokens;

        COLLATERAL_TOKEN.safeTransfer(msg.sender, amountOut);
        emit LiquidityRemoved(marketId, msg.sender, lpTokens, amountOut);
    }

    function resolveMarket(uint256 marketId, bool outcome)
        external
        onlyAuthorizedResolver
        marketExists(marketId)
        marketNotResolved(marketId)
    {
        Market storage market = markets[marketId];
        require(block.timestamp >= market.endTime, "Market not yet expired");

        market.resolved = true;
        market.outcome = outcome;

        emit MarketResolved(marketId, outcome, msg.sender);
    }

    function claimWinnings(uint256 marketId) external nonReentrant marketExists(marketId) {
        Market storage market = markets[marketId];
        require(market.resolved, "Market not resolved");

        uint256 winningShares = market.outcome ? yesShares[marketId][msg.sender] : noShares[marketId][msg.sender];
        require(winningShares > 0, "No winning shares");

        if (market.outcome) {
            yesShares[marketId][msg.sender] = 0;
        } else {
            noShares[marketId][msg.sender] = 0;
        }

        COLLATERAL_TOKEN.safeTransfer(msg.sender, winningShares);
    }

    function setAuthorizedResolver(address resolver, bool authorized) external onlyOwner {
        authorizedResolvers[resolver] = authorized;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getMarket(uint256 marketId)
        external
        view
        marketExists(marketId)
        returns (
            uint256 id,
            string memory question,
            uint256 endTime,
            uint256 liquidityYes,
            uint256 liquidityNo,
            uint256 totalShares,
            bool resolved,
            bool outcome,
            address creator,
            uint256 fee
        )
    {
        Market storage market = markets[marketId];
        return (
            market.id,
            market.question,
            market.endTime,
            market.liquidityYes,
            market.liquidityNo,
            market.totalShares,
            market.resolved,
            market.outcome,
            market.creator,
            market.fee
        );
    }

    function getUserShares(uint256 marketId, address user)
        external
        view
        marketExists(marketId)
        returns (uint256 userLpShares, uint256 userYesShares, uint256 userNoShares)
    {
        return (lpShares[marketId][user], yesShares[marketId][user], noShares[marketId][user]);
    }
}
