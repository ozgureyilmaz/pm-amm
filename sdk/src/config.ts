import { NetworkConfig } from './types';

export const NETWORKS: Record<string, NetworkConfig> = {
  localhost: {
    rpcUrl: 'http://localhost:8545',
    contracts: {
      amm: '', // To be filled after deployment
      oracle: '', // To be filled after deployment
      collateralToken: '', // To be filled after deployment
    },
    blockExplorer: 'http://localhost:8545'
  },
  sepolia: {
    rpcUrl: 'https://eth-sepolia.g.alchemy.com/v2/your-api-key',
    contracts: {
      amm: '', // To be filled after deployment
      oracle: '', // To be filled after deployment
      collateralToken: '0x...', // Real USDC on Sepolia or mock
    },
    blockExplorer: 'https://sepolia.etherscan.io'
  },
  polygon: {
    rpcUrl: 'https://polygon-mainnet.g.alchemy.com/v2/your-api-key',
    contracts: {
      amm: '', // To be filled after deployment
      oracle: '', // To be filled after deployment
      collateralToken: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174', // Real USDC on Polygon
    },
    blockExplorer: 'https://polygonscan.com'
  }
};

export const DEFAULT_SLIPPAGE = 0.01; // 1%
export const DEFAULT_DEADLINE = 20 * 60; // 20 minutes
export const PRECISION = BigInt(1e18);
export const USDC_DECIMALS = 6;