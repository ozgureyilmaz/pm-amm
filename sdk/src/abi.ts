export const PREDICTION_MARKET_AMM_ABI = [
  // Events
  "event MarketCreated(uint256 indexed marketId, string question, uint256 endTime, address indexed creator)",
  "event Trade(uint256 indexed marketId, address indexed trader, bool isYes, uint256 sharesOut, uint256 tokensIn, uint256 price)",
  "event LiquidityAdded(uint256 indexed marketId, address indexed provider, uint256 amount, uint256 lpTokens)",
  "event LiquidityRemoved(uint256 indexed marketId, address indexed provider, uint256 lpTokens, uint256 amount)",
  "event MarketResolved(uint256 indexed marketId, bool outcome, address indexed resolver)",

  // Market Management
  "function createMarket(string calldata question, uint256 endTime, uint256 initialLiquidity, uint256 fee) external returns (uint256 marketId)",
  "function resolveMarket(uint256 marketId, bool outcome) external",

  // Trading
  "function trade(uint256 marketId, bool isYes, uint256 tokensIn, uint256 minSharesOut, uint256 deadline) external",
  "function getSharesOut(uint256 marketId, bool isYes, uint256 tokensIn) external view returns (uint256 sharesOut, uint256 effectivePrice)",
  "function getPrice(uint256 marketId, bool isYes) external view returns (uint256 price)",

  // Liquidity
  "function addLiquidity(uint256 marketId, uint256 amount) external",
  "function removeLiquidity(uint256 marketId, uint256 lpTokens) external",

  // Winnings
  "function claimWinnings(uint256 marketId) external",

  // View Functions
  "function getMarket(uint256 marketId) external view returns (uint256 id, string memory question, uint256 endTime, uint256 liquidityYes, uint256 liquidityNo, uint256 totalShares, bool resolved, bool outcome, address creator, uint256 fee)",
  "function getUserShares(uint256 marketId, address user) external view returns (uint256 userLpShares, uint256 userYesShares, uint256 userNoShares)",
  "function nextMarketId() external view returns (uint256)",
  "function COLLATERAL_TOKEN() external view returns (address)",

  // Admin
  "function setAuthorizedResolver(address resolver, bool authorized) external",
  "function pause() external",
  "function unpause() external",
  "function owner() external view returns (address)"
] as const;

export const PREDICTION_MARKET_ORACLE_ABI = [
  // Events
  "event ResolutionSubmitted(uint256 indexed marketId, address indexed submitter, bool outcome, string evidence)",
  "event MarketResolved(uint256 indexed marketId, bool outcome, uint8 method)",

  // Resolution Management
  "function submitResolution(uint256 marketId, bool outcome, string calldata evidence) external",
  "function vote(uint256 marketId, bool outcome) external",
  "function finalizeResolution(uint256 marketId) external",
  "function disputeResolution(uint256 marketId, string calldata reason) external",

  // Configuration
  "function configureMarket(uint256 marketId, uint8 method, uint256 resolutionDelay, uint256 disputePeriod, bool requiresConsensus, uint256 minVoters) external",

  // View Functions
  "function getResolution(uint256 marketId) external view returns (bool outcome, uint8 status, uint8 method, address submitter, uint256 timestamp, string memory evidence, uint256 votesYes, uint256 votesNo)",
  "function hasVoted(uint256 marketId, address voter) external view returns (bool)",
  "function getVote(uint256 marketId, address voter) external view returns (bool)",

  // Admin
  "function addResolver(address resolver) external",
  "function removeResolver(address resolver) external",
  "function setDefaultDisputePeriod(uint256 period) external",
  "function authorizedResolvers(address) external view returns (bool)"
] as const;

export const ERC20_ABI = [
  "function name() external view returns (string)",
  "function symbol() external view returns (string)",
  "function decimals() external view returns (uint8)",
  "function totalSupply() external view returns (uint256)",
  "function balanceOf(address owner) external view returns (uint256)",
  "function transfer(address to, uint256 value) external returns (bool)",
  "function transferFrom(address from, address to, uint256 value) external returns (bool)",
  "function approve(address spender, uint256 value) external returns (bool)",
  "function allowance(address owner, address spender) external view returns (uint256)",

  // Mock USDC specific
  "function mint(address to, uint256 amount) external",
  "function faucet() external"
] as const;