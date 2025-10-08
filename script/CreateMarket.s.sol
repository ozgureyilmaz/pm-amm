// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PredictionMarketAMM, IERC20} from "../src/PredictionMarketAMM.sol";

/**
 * @title CreateMarket
 * @dev Script to create a test prediction market
 */
contract CreateMarket is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address ammAddress = vm.envAddress("AMM_ADDRESS");
        address usdcAddress = vm.envAddress("USDC_ADDRESS");

        PredictionMarketAMM amm = PredictionMarketAMM(ammAddress);
        IERC20 usdc = IERC20(usdcAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Market parameters
        string memory question = "Will Bitcoin reach $100,000 by end of 2024?";
        uint256 endTime = block.timestamp + 30 days; // 30 days from now
        uint256 initialLiquidity = 10000 * 10 ** 6; // 10k USDC
        uint256 fee = 100; // 1%

        // Approve spending
        usdc.approve(ammAddress, initialLiquidity);

        // Create market
        uint256 marketId = amm.createMarket(question, endTime, initialLiquidity, fee);

        console.log("Market created with ID:", marketId);
        console.log("Question:", question);
        console.log("End time:", endTime);
        console.log("Initial liquidity:", initialLiquidity);
        console.log("Trading fee:", fee, "basis points");

        // Check initial prices
        uint256 yesPrice = amm.getPrice(marketId, true);
        uint256 noPrice = amm.getPrice(marketId, false);

        console.log("Initial YES price:", yesPrice);
        console.log("Initial NO price:", noPrice);

        vm.stopBroadcast();
    }
}
