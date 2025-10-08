// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PredictionMarketAMM} from "../src/PredictionMarketAMM.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {PredictionMarketOracle} from "../src/PredictionMarketOracle.sol";

/**
 * @title Deploy
 * @dev Deployment script for the Prediction Market AMM system
 */
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Mock USDC (only for testnet/local)
        MockUSDC usdc = new MockUSDC(deployer);
        console.log("MockUSDC deployed to:", address(usdc));

        // Deploy Prediction Market AMM
        PredictionMarketAMM amm = new PredictionMarketAMM(address(usdc), deployer);
        console.log("PredictionMarketAMM deployed to:", address(amm));

        // Deploy Oracle
        PredictionMarketOracle oracle = new PredictionMarketOracle(address(amm), deployer);
        console.log("PredictionMarketOracle deployed to:", address(oracle));

        // Setup permissions
        amm.setAuthorizedResolver(address(oracle), true);
        amm.setAuthorizedResolver(deployer, true); // Allow manual resolution for testing

        // Mint some test tokens to deployer
        usdc.mint(deployer, 1000000 * 10 ** 6); // 1M USDC

        console.log("Setup completed!");
        console.log("- AMM authorized resolvers: Oracle and deployer");
        console.log("- Minted 1M USDC to deployer");

        vm.stopBroadcast();
    }
}
