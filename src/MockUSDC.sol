// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockUSDC
 * @dev Mock USDC token for testing the prediction market AMM
 */
contract MockUSDC is ERC20, Ownable {
    uint8 private _decimals;

    constructor(address _owner) ERC20("Mock USDC", "mUSDC") Ownable(_owner) {
        _decimals = 6; // USDC has 6 decimals
        _mint(_owner, 1000000 * 10 ** _decimals); // Mint 1M tokens to owner
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Mint tokens to any address (for testing purposes)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Faucet function - anyone can mint 1000 tokens for testing
     */
    function faucet() external {
        _mint(msg.sender, 1000 * 10 ** _decimals);
    }
}
