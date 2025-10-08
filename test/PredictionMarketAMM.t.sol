// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PredictionMarketAMM} from "../src/PredictionMarketAMM.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {PredictionMarketOracle} from "../src/PredictionMarketOracle.sol";

contract PredictionMarketAMMTest is Test {
    PredictionMarketAMM public amm;
    MockUSDC public usdc;
    PredictionMarketOracle public oracle;

    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);

    uint256 constant INITIAL_LIQUIDITY = 1000e6;
    uint256 constant TRADE_AMOUNT = 100e6;
    string constant MARKET_QUESTION = "Will BTC reach $100k by end of 2024?";
    uint256 constant MARKET_END_TIME = 1735689600;
    uint256 constant MARKET_FEE = 100;
    uint256 constant TRADE_DEADLINE = type(uint256).max;

    event MarketCreated(uint256 indexed marketId, string question, uint256 endTime, address indexed creator);
    event Trade(
        uint256 indexed marketId, address indexed trader, bool isYes, uint256 sharesOut, uint256 tokensIn, uint256 price
    );

    function setUp() public {
        vm.startPrank(owner);

        usdc = new MockUSDC(owner);
        amm = new PredictionMarketAMM(address(usdc), owner);
        oracle = new PredictionMarketOracle(address(amm), owner);

        amm.setAuthorizedResolver(address(oracle), true);

        usdc.mint(alice, 10000e6);
        usdc.mint(bob, 10000e6);
        usdc.mint(charlie, 10000e6);
        usdc.mint(address(this), 10000e6);

        vm.stopPrank();

        vm.prank(alice);
        usdc.approve(address(amm), type(uint256).max);

        vm.prank(bob);
        usdc.approve(address(amm), type(uint256).max);

        vm.prank(charlie);
        usdc.approve(address(amm), type(uint256).max);

        vm.prank(owner);
        usdc.approve(address(oracle), type(uint256).max);

        usdc.approve(address(amm), type(uint256).max);
    }

    function testCreateMarket() public {
        vm.startPrank(alice);

        uint256 initialBalance = usdc.balanceOf(alice);

        vm.expectEmit(true, true, true, true);
        emit MarketCreated(0, MARKET_QUESTION, MARKET_END_TIME, alice);

        uint256 marketId = amm.createMarket(MARKET_QUESTION, MARKET_END_TIME, INITIAL_LIQUIDITY, MARKET_FEE);

        assertEq(marketId, 0);
        assertEq(usdc.balanceOf(alice), initialBalance - INITIAL_LIQUIDITY);

        (
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
        ) = amm.getMarket(marketId);

        assertEq(id, 0);
        assertEq(question, MARKET_QUESTION);
        assertEq(endTime, MARKET_END_TIME);
        assertEq(liquidityYes, INITIAL_LIQUIDITY / 2);
        assertEq(liquidityNo, INITIAL_LIQUIDITY / 2);
        assertEq(totalShares, INITIAL_LIQUIDITY);
        assertEq(resolved, false);
        assertEq(creator, alice);
        assertEq(fee, MARKET_FEE);

        vm.stopPrank();
    }

    function testGetPriceInitial() public {
        vm.prank(alice);
        uint256 marketId = amm.createMarket(MARKET_QUESTION, MARKET_END_TIME, INITIAL_LIQUIDITY, MARKET_FEE);

        uint256 yesPrice = amm.getPrice(marketId, true);
        uint256 noPrice = amm.getPrice(marketId, false);

        assertEq(yesPrice, 0.5e18);
        assertEq(noPrice, 0.5e18);
        assertEq(yesPrice + noPrice, 1e18);
    }

    function testTradeYes() public {
        vm.prank(alice);
        uint256 marketId = amm.createMarket(MARKET_QUESTION, MARKET_END_TIME, INITIAL_LIQUIDITY, MARKET_FEE);

        uint256 initialYesPrice = amm.getPrice(marketId, true);
        (uint256 expectedShares, uint256 effectivePrice) = amm.getSharesOut(marketId, true, TRADE_AMOUNT);

        vm.startPrank(bob);
        uint256 initialBalance = usdc.balanceOf(bob);

        vm.expectEmit(true, true, true, true);
        emit Trade(marketId, bob, true, expectedShares, TRADE_AMOUNT, effectivePrice);

        amm.trade(marketId, true, TRADE_AMOUNT, expectedShares, TRADE_DEADLINE);

        // Check balances
        assertEq(usdc.balanceOf(bob), initialBalance - TRADE_AMOUNT);

        // Check user shares
        (, uint256 yesShares,) = amm.getUserShares(marketId, bob);
        assertEq(yesShares, expectedShares);

        // Price should have moved up for YES
        uint256 newYesPrice = amm.getPrice(marketId, true);
        assertGt(newYesPrice, initialYesPrice);

        vm.stopPrank();
    }

    function testTradeNo() public {
        vm.prank(alice);
        uint256 marketId = amm.createMarket(MARKET_QUESTION, MARKET_END_TIME, INITIAL_LIQUIDITY, MARKET_FEE);

        uint256 initialNoPrice = amm.getPrice(marketId, false);
        (uint256 expectedShares,) = amm.getSharesOut(marketId, false, TRADE_AMOUNT);

        vm.prank(bob);
        amm.trade(marketId, false, TRADE_AMOUNT, expectedShares, TRADE_DEADLINE);

        // Check user shares
        (,, uint256 noShares) = amm.getUserShares(marketId, bob);
        assertEq(noShares, expectedShares);

        // Price should have moved up for NO
        uint256 newNoPrice = amm.getPrice(marketId, false);
        assertGt(newNoPrice, initialNoPrice);
    }

    function testAddLiquidity() public {
        vm.prank(alice);
        uint256 marketId = amm.createMarket(MARKET_QUESTION, MARKET_END_TIME, INITIAL_LIQUIDITY, MARKET_FEE);

        vm.startPrank(bob);
        uint256 additionalLiquidity = 500e6;
        uint256 initialBalance = usdc.balanceOf(bob);

        amm.addLiquidity(marketId, additionalLiquidity);

        assertEq(usdc.balanceOf(bob), initialBalance - additionalLiquidity);

        // Check LP shares
        (uint256 lpShares,,) = amm.getUserShares(marketId, bob);
        assertGt(lpShares, 0);

        vm.stopPrank();
    }

    function testRemoveLiquidity() public {
        vm.prank(alice);
        uint256 marketId = amm.createMarket(MARKET_QUESTION, MARKET_END_TIME, INITIAL_LIQUIDITY, MARKET_FEE);

        // Get initial LP shares
        (uint256 initialLpShares,,) = amm.getUserShares(marketId, alice);

        vm.startPrank(alice);
        uint256 sharesToRemove = initialLpShares / 2;
        uint256 initialBalance = usdc.balanceOf(alice);

        amm.removeLiquidity(marketId, sharesToRemove);

        // Should receive some collateral back
        assertGt(usdc.balanceOf(alice), initialBalance);

        // LP shares should be reduced
        (uint256 newLpShares,,) = amm.getUserShares(marketId, alice);
        assertEq(newLpShares, initialLpShares - sharesToRemove);

        vm.stopPrank();
    }

    function testMarketResolution() public {
        vm.prank(alice);
        uint256 marketId = amm.createMarket(MARKET_QUESTION, MARKET_END_TIME, INITIAL_LIQUIDITY, MARKET_FEE);

        // Bob buys YES shares
        vm.prank(bob);
        (uint256 expectedShares,) = amm.getSharesOut(marketId, true, TRADE_AMOUNT);
        amm.trade(marketId, true, TRADE_AMOUNT, expectedShares, TRADE_DEADLINE);

        // Charlie buys NO shares
        vm.prank(charlie);
        (uint256 expectedNoShares,) = amm.getSharesOut(marketId, false, TRADE_AMOUNT);
        amm.trade(marketId, false, TRADE_AMOUNT, expectedNoShares, TRADE_DEADLINE);

        // Fast forward past market end time
        vm.warp(MARKET_END_TIME + 1);

        // Resolve market in favor of YES
        vm.prank(owner);
        amm.resolveMarket(marketId, true);

        // Check resolution
        (,,,,,, bool resolved, bool outcome,,) = amm.getMarket(marketId);
        assertTrue(resolved);
        assertTrue(outcome);

        // YES price should be 1, NO price should be 0
        assertEq(amm.getPrice(marketId, true), 1e18);
        assertEq(amm.getPrice(marketId, false), 0);
    }

    function testClaimWinnings() public {
        vm.prank(alice);
        uint256 marketId = amm.createMarket(MARKET_QUESTION, MARKET_END_TIME, INITIAL_LIQUIDITY, MARKET_FEE);

        // Bob buys YES shares
        vm.startPrank(bob);
        (uint256 expectedShares,) = amm.getSharesOut(marketId, true, TRADE_AMOUNT);
        amm.trade(marketId, true, TRADE_AMOUNT, expectedShares, TRADE_DEADLINE);
        vm.stopPrank();

        // Check Bob has shares before resolution
        (, uint256 yesSharesBefore,) = amm.getUserShares(marketId, bob);
        assertEq(yesSharesBefore, expectedShares);

        // Fast forward and resolve in favor of YES
        vm.warp(MARKET_END_TIME + 1);
        vm.prank(owner);
        amm.resolveMarket(marketId, true);

        // Check Bob still has shares after resolution
        (, uint256 yesSharesAfter,) = amm.getUserShares(marketId, bob);
        assertEq(yesSharesAfter, expectedShares);

        // Bob claims winnings
        vm.startPrank(bob);
        uint256 initialBalance = usdc.balanceOf(bob);

        amm.claimWinnings(marketId);

        // Should receive winning shares as collateral
        assertEq(usdc.balanceOf(bob), initialBalance + expectedShares);

        // Shares should be cleared
        (, uint256 yesShares,) = amm.getUserShares(marketId, bob);
        assertEq(yesShares, 0);

        vm.stopPrank();
    }

    function testSlippageProtection() public {
        vm.prank(alice);
        uint256 marketId = amm.createMarket(MARKET_QUESTION, MARKET_END_TIME, INITIAL_LIQUIDITY, MARKET_FEE);

        vm.startPrank(bob);
        (uint256 expectedShares,) = amm.getSharesOut(marketId, true, TRADE_AMOUNT);

        // Try to trade with higher minimum shares than expected (should fail)
        vm.expectRevert("Slippage exceeded");
        amm.trade(marketId, true, TRADE_AMOUNT, expectedShares + 1, TRADE_DEADLINE);

        // Trade with correct minimum should succeed
        amm.trade(marketId, true, TRADE_AMOUNT, expectedShares, TRADE_DEADLINE);

        vm.stopPrank();
    }

    function testCannotTradeAfterExpiry() public {
        vm.prank(alice);
        uint256 marketId = amm.createMarket(MARKET_QUESTION, MARKET_END_TIME, INITIAL_LIQUIDITY, MARKET_FEE);

        // Fast forward past expiry
        vm.warp(MARKET_END_TIME + 1);

        vm.prank(bob);
        vm.expectRevert("Market expired");
        amm.trade(marketId, true, TRADE_AMOUNT, 0, TRADE_DEADLINE);
    }

    function testCannotTradeAfterResolution() public {
        vm.prank(alice);
        uint256 marketId = amm.createMarket(MARKET_QUESTION, MARKET_END_TIME, INITIAL_LIQUIDITY, MARKET_FEE);

        // Fast forward and resolve
        vm.warp(MARKET_END_TIME + 1);
        vm.prank(owner);
        amm.resolveMarket(marketId, true);

        vm.prank(bob);
        vm.expectRevert("Market already resolved");
        amm.trade(marketId, true, TRADE_AMOUNT, 0, TRADE_DEADLINE);
    }

    function testFeeCollection() public {
        vm.prank(alice);
        uint256 marketId = amm.createMarket(MARKET_QUESTION, MARKET_END_TIME, INITIAL_LIQUIDITY, MARKET_FEE);

        uint256 contractBalanceBefore = usdc.balanceOf(address(amm));

        vm.prank(bob);
        (uint256 expectedShares,) = amm.getSharesOut(marketId, true, TRADE_AMOUNT);
        amm.trade(marketId, true, TRADE_AMOUNT, expectedShares, TRADE_DEADLINE);

        uint256 contractBalanceAfter = usdc.balanceOf(address(amm));

        // Contract should receive the full trade amount (including fees)
        assertEq(contractBalanceAfter, contractBalanceBefore + TRADE_AMOUNT);
    }

    function testPriceCalculationConsistency() public {
        vm.prank(alice);
        uint256 marketId = amm.createMarket(MARKET_QUESTION, MARKET_END_TIME, INITIAL_LIQUIDITY, MARKET_FEE);

        // Prices should always sum to ~1 (allowing for small rounding errors)
        uint256 yesPrice = amm.getPrice(marketId, true);
        uint256 noPrice = amm.getPrice(marketId, false);

        assertApproxEqAbs(yesPrice + noPrice, 1e18, 1); // Allow 1 wei difference for rounding

        // After some trades, prices should still sum to ~1
        vm.prank(bob);
        (uint256 expectedShares,) = amm.getSharesOut(marketId, true, TRADE_AMOUNT);
        amm.trade(marketId, true, TRADE_AMOUNT, expectedShares, TRADE_DEADLINE);

        yesPrice = amm.getPrice(marketId, true);
        noPrice = amm.getPrice(marketId, false);

        assertApproxEqAbs(yesPrice + noPrice, 1e18, 1);
    }
}
