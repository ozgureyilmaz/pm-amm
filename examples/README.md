# Example Usage Scripts

This directory contains example scripts for interacting with the Prediction Market AMM.

## Scripts

### `basic-trading.js`
Demonstrates basic trading operations:
- Creating a market
- Getting price quotes
- Executing trades
- Checking balances

### `liquidity-management.js`
Shows liquidity provider operations:
- Adding liquidity
- Earning fees
- Removing liquidity

### `market-resolution.js`
Examples of market resolution:
- Manual resolution
- Consensus voting
- Claiming winnings

## Usage

```bash
# Install dependencies
npm install ethers

# Run examples (make sure contracts are deployed first)
node examples/basic-trading.js
node examples/liquidity-management.js
node examples/market-resolution.js
```

## Configuration

Update the contract addresses in each script after deployment:

```javascript
const contracts = {
  amm: '0x...', // Your deployed AMM address
  oracle: '0x...', // Your deployed Oracle address
  collateralToken: '0x...' // Your collateral token address
};
```