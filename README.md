# Prediction Market AMM

A decentralized Automated Market Maker (AMM) for binary prediction markets, implemented in Solidity using Foundry. Based on Paradigm's research on prediction market AMMs using Constant Product Market Maker (CPMM) mechanics.

## Features

- **Binary Prediction Markets**: Create markets for any yes/no question
- **CPMM Pricing**: Automated pricing using constant product formulas
- **Liquidity Provision**: Add/remove liquidity to earn fees
- **Flexible Resolution**: Manual, automated, and consensus-based resolution
- **TypeScript SDK**: Complete SDK for easy integration
- **Comprehensive Testing**: Full test suite with edge cases

## Architecture

### Core Contracts

- **`PredictionMarketAMM.sol`**: Main AMM contract handling market creation, trading, and liquidity
- **`PredictionMarketOracle.sol`**: Resolution oracle with multiple resolution methods
- **`MockUSDC.sol`**: Mock ERC20 token for testing

### Key Features

- **Market Creation**: Anyone can create prediction markets with custom parameters
- **Trading**: Buy YES/NO shares with automatic pricing via CPMM
- **Liquidity Management**: Provide liquidity to earn trading fees
- **Resolution**: Multiple resolution mechanisms (manual, automated, consensus)
- **Winnings**: Claim 1:1 winnings after market resolution

## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (for SDK)

### Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd pm-amm

# Install dependencies
forge install
```

### Build

```bash
forge build
```

### Test

```bash
forge test -v
```

### Deploy Locally

```bash
# Start local node
anvil

# Deploy contracts (in another terminal)
forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --private-key <anvil-private-key> --broadcast
```

## Usage Examples

### Creating a Market

```solidity
// Create a market about Bitcoin price
uint256 marketId = amm.createMarket(
    "Will Bitcoin reach $100k by end of 2024?",
    1735689600, // End time (timestamp)
    10000e6,    // Initial liquidity (10k USDC)
    100         // Fee (1%)
);
```

### Trading

```solidity
// Buy YES shares
(uint256 sharesOut,) = amm.getSharesOut(marketId, true, 100e6);
amm.trade(marketId, true, 100e6, sharesOut);

// Buy NO shares
(uint256 noShares,) = amm.getSharesOut(marketId, false, 100e6);
amm.trade(marketId, false, 100e6, noShares);
```

### Adding Liquidity

```solidity
// Add liquidity to earn fees
amm.addLiquidity(marketId, 1000e6);
```

### TypeScript SDK Usage

```typescript
import { PredictionMarketSDK } from 'prediction-market-amm-sdk';
import { ethers } from 'ethers';

// Initialize SDK
const provider = new ethers.JsonRpcProvider('http://localhost:8545');
const signer = new ethers.Wallet(privateKey, provider);
const contracts = {
  amm: '0x...',
  oracle: '0x...',
  collateralToken: '0x...'
};

const sdk = new PredictionMarketSDK(provider, contracts, signer);

// Create a market
const marketId = await sdk.createMarket({
  question: "Will it rain tomorrow?",
  endTime: BigInt(Math.floor(Date.now() / 1000) + 86400),
  initialLiquidity: BigInt(1000e6),
  fee: BigInt(100)
});

// Get price information
const priceInfo = await sdk.getPriceInfo(BigInt(marketId));
console.log(`YES: ${PredictionMarketSDK.formatPrice(priceInfo.yesPrice)}`);
console.log(`NO: ${PredictionMarketSDK.formatPrice(priceInfo.noPrice)}`);

// Execute a trade
await sdk.trade({
  marketId: BigInt(marketId),
  isYes: true,
  tokensIn: BigInt(100e6),
  minSharesOut: BigInt(0)
});
```

## API Reference

### PredictionMarketAMM Contract

#### Market Management
- `createMarket(question, endTime, initialLiquidity, fee)` - Create new market
- `resolveMarket(marketId, outcome)` - Resolve market outcome
- `getMarket(marketId)` - Get market information

#### Trading
- `trade(marketId, isYes, tokensIn, minSharesOut)` - Execute trade
- `getPrice(marketId, isYes)` - Get current price
- `getSharesOut(marketId, isYes, tokensIn)` - Calculate trade outcome

#### Liquidity
- `addLiquidity(marketId, amount)` - Add liquidity
- `removeLiquidity(marketId, lpTokens)` - Remove liquidity
- `getUserShares(marketId, user)` - Get user's shares

#### Winnings
- `claimWinnings(marketId)` - Claim winnings after resolution

### TypeScript SDK

#### Core Methods
- `createMarket(params)` - Create new market
- `trade(params)` - Execute trade
- `addLiquidity(params)` - Add liquidity
- `getMarket(marketId)` - Get market info
- `getPriceInfo(marketId)` - Get current prices
- `getTradeQuote(marketId, isYes, tokensIn)` - Get trade quote

#### Utility Methods
- `formatPrice(price)` - Format price as percentage
- `formatAmount(amount, decimals)` - Format token amount
- `parseAmount(amount, decimals)` - Parse string to BigInt

## Deployment

### Environment Setup

Create `.env` file:
```bash
PRIVATE_KEY=your_private_key
ALCHEMY_API_KEY=your_alchemy_key
ETHERSCAN_API_KEY=your_etherscan_key
```

### Deploy to Testnet

```bash
# Deploy to Sepolia
forge script script/Deploy.s.sol:Deploy --rpc-url sepolia --private-key $PRIVATE_KEY --broadcast --verify

# Create a test market
AMM_ADDRESS=0x... USDC_ADDRESS=0x... forge script script/CreateMarket.s.sol:CreateMarket --rpc-url sepolia --private-key $PRIVATE_KEY --broadcast
```

## Testing

Run the comprehensive test suite:

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vv

# Run specific test
forge test --match-test testTradeYes

# Generate gas report
forge test --gas-report
```

## Economics

### CPMM Pricing

The AMM uses a Constant Product Market Maker formula:

- **Price**: `P_yes = L_no / (L_yes + L_no)`
- **Shares Out**: `shares = L_target - (L_target * L_other) / (L_other + tokens_in)`

Where:
- `L_yes` = YES token liquidity
- `L_no` = NO token liquidity  
- `tokens_in` = Input tokens (after fees)

### Fee Structure

- Trading fees are set per market (0-10%)
- Fees are distributed to liquidity providers
- No protocol fees (can be added later)

## Security Considerations

- ✅ ReentrancyGuard on all state-changing functions
- ✅ SafeERC20 for all token transfers
- ✅ Comprehensive input validation
- ✅ Access controls for market resolution
- ✅ Pausable functionality for emergencies

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Resources

- [Paradigm's Prediction Market AMM Paper](https://www.paradigm.xyz/2021/08/eos-automated-market-maker)
- [Foundry Documentation](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)

## Contact

For questions or support, please open an issue on GitHub.
