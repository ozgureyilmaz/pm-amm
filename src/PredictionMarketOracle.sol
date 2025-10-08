// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IPredictionMarketAMM {
    function resolveMarket(uint256 marketId, bool outcome) external;
    function nextMarketId() external view returns (uint256);
}

/**
 * @title PredictionMarketOracle
 * @dev Oracle contract for resolving prediction markets
 * Supports multiple resolution mechanisms: manual, automated, and consensus-based
 */
contract PredictionMarketOracle is Ownable, ReentrancyGuard {
    // Events
    event ResolutionSubmitted(uint256 indexed marketId, address indexed submitter, bool outcome, string evidence);

    event MarketResolved(uint256 indexed marketId, bool outcome, ResolutionMethod method);

    event ResolverAdded(address indexed resolver);
    event ResolverRemoved(address indexed resolver);

    // Enums
    enum ResolutionMethod {
        MANUAL,
        AUTOMATED,
        CONSENSUS
    }

    enum ResolutionStatus {
        PENDING,
        SUBMITTED,
        DISPUTED,
        RESOLVED
    }

    // Structs
    struct Resolution {
        uint256 marketId;
        bool outcome;
        ResolutionStatus status;
        ResolutionMethod method;
        address submitter;
        uint256 timestamp;
        string evidence;
        uint256 votesYes;
        uint256 votesNo;
        mapping(address => bool) hasVoted;
        mapping(address => bool) votes;
    }

    struct MarketConfig {
        ResolutionMethod method;
        uint256 resolutionDelay;
        uint256 disputePeriod;
        bool requiresConsensus;
        uint256 minVoters;
    }

    // State variables
    IPredictionMarketAMM public immutable PREDICTION_MARKET;

    mapping(uint256 => Resolution) public resolutions;
    mapping(uint256 => MarketConfig) public marketConfigs;
    mapping(address => bool) public authorizedResolvers;
    mapping(address => uint256) public resolverStakes;

    uint256 public constant MIN_RESOLUTION_DELAY = 1 hours;
    uint256 public constant MAX_DISPUTE_PERIOD = 7 days;
    uint256 public defaultDisputePeriod = 24 hours;
    uint256 public requiredStake = 1000e6; // 1000 USDC

    modifier onlyAuthorizedResolver() {
        require(authorizedResolvers[msg.sender], "Not authorized resolver");
        _;
    }

    modifier validMarket(uint256 marketId) {
        require(marketId < PREDICTION_MARKET.nextMarketId(), "Market does not exist");
        _;
    }

    constructor(address _predictionMarket, address _owner) Ownable(_owner) {
        PREDICTION_MARKET = IPredictionMarketAMM(_predictionMarket);
    }

    /**
     * @dev Configure resolution method for a market
     */
    function configureMarket(
        uint256 marketId,
        ResolutionMethod method,
        uint256 resolutionDelay,
        uint256 disputePeriod,
        bool requiresConsensus,
        uint256 minVoters
    ) external onlyOwner validMarket(marketId) {
        require(resolutionDelay >= MIN_RESOLUTION_DELAY, "Resolution delay too short");
        require(disputePeriod <= MAX_DISPUTE_PERIOD, "Dispute period too long");

        marketConfigs[marketId] = MarketConfig({
            method: method,
            resolutionDelay: resolutionDelay,
            disputePeriod: disputePeriod,
            requiresConsensus: requiresConsensus,
            minVoters: minVoters
        });
    }

    /**
     * @dev Submit a resolution for a market
     */
    function submitResolution(uint256 marketId, bool outcome, string calldata evidence)
        external
        onlyAuthorizedResolver
        nonReentrant
        validMarket(marketId)
    {
        Resolution storage resolution = resolutions[marketId];
        require(resolution.status == ResolutionStatus.PENDING, "Resolution already submitted");

        MarketConfig memory config = marketConfigs[marketId];

        resolution.marketId = marketId;
        resolution.outcome = outcome;
        resolution.status = ResolutionStatus.SUBMITTED;
        resolution.method = config.method;
        resolution.submitter = msg.sender;
        resolution.timestamp = block.timestamp;
        resolution.evidence = evidence;

        emit ResolutionSubmitted(marketId, msg.sender, outcome, evidence);

        // If manual resolution and no dispute period, resolve immediately
        if (config.method == ResolutionMethod.MANUAL && config.disputePeriod == 0) {
            _resolveMarket(marketId);
        }
    }

    /**
     * @dev Vote on a consensus-based resolution
     */
    function vote(uint256 marketId, bool outcome) external onlyAuthorizedResolver {
        Resolution storage resolution = resolutions[marketId];
        require(resolution.status == ResolutionStatus.SUBMITTED, "Resolution not submitted");
        require(!resolution.hasVoted[msg.sender], "Already voted");

        MarketConfig memory config = marketConfigs[marketId];
        require(config.method == ResolutionMethod.CONSENSUS, "Not consensus resolution");
        require(block.timestamp <= resolution.timestamp + config.disputePeriod, "Voting period ended");

        resolution.hasVoted[msg.sender] = true;
        resolution.votes[msg.sender] = outcome;

        if (outcome) {
            resolution.votesYes++;
        } else {
            resolution.votesNo++;
        }

        // Check if we have enough votes to resolve
        uint256 totalVotes = resolution.votesYes + resolution.votesNo;
        if (totalVotes >= config.minVoters) {
            bool consensusOutcome = resolution.votesYes > resolution.votesNo;
            resolution.outcome = consensusOutcome;
            _resolveMarket(marketId);
        }
    }

    /**
     * @dev Finalize resolution after dispute period
     */
    function finalizeResolution(uint256 marketId) external {
        Resolution storage resolution = resolutions[marketId];
        require(resolution.status == ResolutionStatus.SUBMITTED, "Resolution not submitted");

        MarketConfig memory config = marketConfigs[marketId];
        require(block.timestamp >= resolution.timestamp + config.resolutionDelay, "Resolution delay not passed");

        if (config.method == ResolutionMethod.CONSENSUS) {
            require(block.timestamp >= resolution.timestamp + config.disputePeriod, "Dispute period not ended");

            // Use majority vote or original submission if tied
            if (resolution.votesYes != resolution.votesNo) {
                resolution.outcome = resolution.votesYes > resolution.votesNo;
            }
        }

        _resolveMarket(marketId);
    }

    /**
     * @dev Internal function to resolve market in the main contract
     */
    function _resolveMarket(uint256 marketId) internal {
        Resolution storage resolution = resolutions[marketId];
        resolution.status = ResolutionStatus.RESOLVED;

        PREDICTION_MARKET.resolveMarket(marketId, resolution.outcome);

        emit MarketResolved(marketId, resolution.outcome, resolution.method);
    }

    /**
     * @dev Dispute a resolution (extends dispute period)
     */
    function disputeResolution(uint256 marketId, string calldata reason) external onlyAuthorizedResolver {
        Resolution storage resolution = resolutions[marketId];
        require(resolution.status == ResolutionStatus.SUBMITTED, "Resolution not submitted");

        MarketConfig memory config = marketConfigs[marketId];
        require(block.timestamp <= resolution.timestamp + config.disputePeriod, "Dispute period ended");

        resolution.status = ResolutionStatus.DISPUTED;
        // Could implement additional dispute logic here
    }

    // Admin functions
    function addResolver(address resolver) external onlyOwner {
        authorizedResolvers[resolver] = true;
        emit ResolverAdded(resolver);
    }

    function removeResolver(address resolver) external onlyOwner {
        authorizedResolvers[resolver] = false;
        emit ResolverRemoved(resolver);
    }

    function setDefaultDisputePeriod(uint256 period) external onlyOwner {
        require(period <= MAX_DISPUTE_PERIOD, "Period too long");
        defaultDisputePeriod = period;
    }

    function setRequiredStake(uint256 stake) external onlyOwner {
        requiredStake = stake;
    }

    // View functions
    function getResolution(uint256 marketId)
        external
        view
        returns (
            bool outcome,
            ResolutionStatus status,
            ResolutionMethod method,
            address submitter,
            uint256 timestamp,
            string memory evidence,
            uint256 votesYes,
            uint256 votesNo
        )
    {
        Resolution storage resolution = resolutions[marketId];
        return (
            resolution.outcome,
            resolution.status,
            resolution.method,
            resolution.submitter,
            resolution.timestamp,
            resolution.evidence,
            resolution.votesYes,
            resolution.votesNo
        );
    }

    function hasVoted(uint256 marketId, address voter) external view returns (bool) {
        return resolutions[marketId].hasVoted[voter];
    }

    function getVote(uint256 marketId, address voter) external view returns (bool) {
        require(resolutions[marketId].hasVoted[voter], "Has not voted");
        return resolutions[marketId].votes[voter];
    }
}
