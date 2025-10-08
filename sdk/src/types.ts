export interface Market {
  id: bigint;
  question: string;
  endTime: bigint;
  liquidityYes: bigint;
  liquidityNo: bigint;
  totalShares: bigint;
  resolved: boolean;
  outcome: boolean;
  creator: string;
  fee: bigint;
}

export interface UserShares {
  lpShares: bigint;
  yesShares: bigint;
  noShares: bigint;
}

export interface TradeParams {
  marketId: bigint;
  isYes: boolean;
  tokensIn: bigint;
  minSharesOut: bigint;
  deadline?: bigint;
}

export interface LiquidityParams {
  marketId: bigint;
  amount: bigint;
}

export interface MarketCreationParams {
  question: string;
  endTime: bigint;
  initialLiquidity: bigint;
  fee: bigint;
}

export interface PriceInfo {
  yesPrice: bigint;
  noPrice: bigint;
  impliedProbability: number;
}

export interface TradeQuote {
  sharesOut: bigint;
  effectivePrice: bigint;
  priceImpact: number;
  fee: bigint;
}

export interface ContractAddresses {
  amm: string;
  oracle: string;
  collateralToken: string;
}

export interface NetworkConfig {
  rpcUrl: string;
  contracts: ContractAddresses;
  blockExplorer?: string;
}

export enum ResolutionMethod {
  MANUAL = 0,
  AUTOMATED = 1,
  CONSENSUS = 2
}

export enum ResolutionStatus {
  PENDING = 0,
  SUBMITTED = 1,
  DISPUTED = 2,
  RESOLVED = 3
}

export interface Resolution {
  outcome: boolean;
  status: ResolutionStatus;
  method: ResolutionMethod;
  submitter: string;
  timestamp: bigint;
  evidence: string;
  votesYes: bigint;
  votesNo: bigint;
}