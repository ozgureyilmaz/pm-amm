import { ethers } from 'ethers';
import { 
  Market, 
  UserShares, 
  TradeParams, 
  LiquidityParams, 
  MarketCreationParams, 
  PriceInfo, 
  TradeQuote, 
  ContractAddresses,
  Resolution
} from './types';
import { PREDICTION_MARKET_AMM_ABI, PREDICTION_MARKET_ORACLE_ABI, ERC20_ABI } from './abi';

export class PredictionMarketSDK {
  private provider: ethers.Provider;
  private signer?: ethers.Signer;
  private contracts: ContractAddresses;
  private ammContract: ethers.Contract;
  private oracleContract: ethers.Contract;
  private collateralContract: ethers.Contract;

  constructor(
    provider: ethers.Provider,
    contracts: ContractAddresses,
    signer?: ethers.Signer
  ) {
    this.provider = provider;
    this.signer = signer;
    this.contracts = contracts;

    this.ammContract = new ethers.Contract(
      contracts.amm,
      PREDICTION_MARKET_AMM_ABI,
      signer || provider
    );

    this.oracleContract = new ethers.Contract(
      contracts.oracle,
      PREDICTION_MARKET_ORACLE_ABI,
      signer || provider
    );

    this.collateralContract = new ethers.Contract(
      contracts.collateralToken,
      ERC20_ABI,
      signer || provider
    );
  }
  async getMarket(marketId: bigint): Promise<Market> {
    const result = await this.ammContract.getMarket(marketId);
    return {
      id: result[0],
      question: result[1],
      endTime: result[2],
      liquidityYes: result[3],
      liquidityNo: result[4],
      totalShares: result[5],
      resolved: result[6],
      outcome: result[7],
      creator: result[8],
      fee: result[9]
    };
  }

  async getUserShares(marketId: bigint, userAddress: string): Promise<UserShares> {
    const result = await this.ammContract.getUserShares(marketId, userAddress);
    return {
      lpShares: result[0],
      yesShares: result[1],
      noShares: result[2]
    };
  }

  async getPriceInfo(marketId: bigint): Promise<PriceInfo> {
    const [yesPrice, noPrice] = await Promise.all([
      this.ammContract.getPrice(marketId, true),
      this.ammContract.getPrice(marketId, false)
    ]);

    const PRECISION = BigInt(1e18);
    const impliedProbability = Number(yesPrice) / Number(PRECISION);

    return {
      yesPrice,
      noPrice,
      impliedProbability
    };
  }

  async getTradeQuote(marketId: bigint, isYes: boolean, tokensIn: bigint): Promise<TradeQuote> {
    const result = await this.ammContract.getSharesOut(marketId, isYes, tokensIn);
    const sharesOut = result[0];
    const effectivePrice = result[1];

    // Calculate fee
    const market = await this.getMarket(marketId);
    const fee = (tokensIn * market.fee) / BigInt(10000);

    // Calculate price impact
    const currentPrice = await this.ammContract.getPrice(marketId, isYes);
    const priceDiff = BigInt(effectivePrice) - BigInt(currentPrice);
    const priceImpact = currentPrice > 0n ? Number((priceDiff * 100n) / BigInt(currentPrice)) : 0;

    return {
      sharesOut,
      effectivePrice,
      priceImpact,
      fee
    };
  }

  async createMarket(params: MarketCreationParams): Promise<string> {
    if (!this.signer) throw new Error('Signer required for this operation');

    await this.approveCollateral(params.initialLiquidity);

    const tx = await this.ammContract.createMarket(
      params.question,
      params.endTime,
      params.initialLiquidity,
      params.fee
    );

    const receipt = await tx.wait();
    const event = receipt.logs.find((log: any) => 
      log.topics[0] === ethers.id('MarketCreated(uint256,string,uint256,address)')
    );

    if (event) {
      const marketId = ethers.AbiCoder.defaultAbiCoder().decode(['uint256'], event.topics[1])[0];
      return marketId.toString();
    }

    throw new Error('Market creation failed');
  }

  async trade(params: TradeParams): Promise<string> {
    if (!this.signer) throw new Error('Signer required for this operation');

    await this.approveCollateral(params.tokensIn);

    const deadline = params.deadline || BigInt(Math.floor(Date.now() / 1000) + 1200); // Default: 20 minutes

    const tx = await this.ammContract.trade(
      params.marketId,
      params.isYes,
      params.tokensIn,
      params.minSharesOut,
      deadline
    );

    return tx.hash;
  }

  async addLiquidity(params: LiquidityParams): Promise<string> {
    if (!this.signer) throw new Error('Signer required for this operation');

    await this.approveCollateral(params.amount);

    const tx = await this.ammContract.addLiquidity(params.marketId, params.amount);
    return tx.hash;
  }

  async removeLiquidity(marketId: bigint, lpTokens: bigint): Promise<string> {
    if (!this.signer) throw new Error('Signer required for this operation');

    const tx = await this.ammContract.removeLiquidity(marketId, lpTokens);
    return tx.hash;
  }

  async claimWinnings(marketId: bigint): Promise<string> {
    if (!this.signer) throw new Error('Signer required for this operation');

    const tx = await this.ammContract.claimWinnings(marketId);
    return tx.hash;
  }

  async getResolution(marketId: bigint): Promise<Resolution> {
    const result = await this.oracleContract.getResolution(marketId);
    return {
      outcome: result[0],
      status: result[1],
      method: result[2],
      submitter: result[3],
      timestamp: result[4],
      evidence: result[5],
      votesYes: result[6],
      votesNo: result[7]
    };
  }

  async submitResolution(marketId: bigint, outcome: boolean, evidence: string): Promise<string> {
    if (!this.signer) throw new Error('Signer required for this operation');

    const tx = await this.oracleContract.submitResolution(marketId, outcome, evidence);
    return tx.hash;
  }

  async vote(marketId: bigint, outcome: boolean): Promise<string> {
    if (!this.signer) throw new Error('Signer required for this operation');

    const tx = await this.oracleContract.vote(marketId, outcome);
    return tx.hash;
  }

  async getCollateralBalance(address: string): Promise<bigint> {
    return await this.collateralContract.balanceOf(address);
  }

  async getCollateralAllowance(owner: string, spender: string): Promise<bigint> {
    return await this.collateralContract.allowance(owner, spender);
  }

  async approveCollateral(amount: bigint): Promise<string> {
    if (!this.signer) throw new Error('Signer required for this operation');

    const tx = await this.collateralContract.approve(this.contracts.amm, amount);
    await tx.wait();
    return tx.hash;
  }

  async mintCollateral(amount: bigint): Promise<string> {
    if (!this.signer) throw new Error('Signer required for this operation');

    const tx = await this.collateralContract.mint(await this.signer.getAddress(), amount);
    return tx.hash;
  }

  async faucet(): Promise<string> {
    if (!this.signer) throw new Error('Signer required for this operation');

    const tx = await this.collateralContract.faucet();
    return tx.hash;
  }

  async getNextMarketId(): Promise<bigint> {
    return await this.ammContract.nextMarketId();
  }

  async getAllMarkets(): Promise<Market[]> {
    const nextId = await this.getNextMarketId();
    const markets: Market[] = [];

    for (let i = 0n; i < nextId; i++) {
      try {
        const market = await this.getMarket(i);
        markets.push(market);
      } catch (error) {
        console.warn(`Failed to fetch market ${i}:`, error);
      }
    }

    return markets;
  }

  onMarketCreated(callback: (marketId: bigint, question: string, endTime: bigint, creator: string) => void) {
    this.ammContract.on('MarketCreated', callback);
  }

  onTrade(callback: (marketId: bigint, trader: string, isYes: boolean, sharesOut: bigint, tokensIn: bigint, price: bigint) => void) {
    this.ammContract.on('Trade', callback);
  }

  onMarketResolved(callback: (marketId: bigint, outcome: boolean, resolver: string) => void) {
    this.ammContract.on('MarketResolved', callback);
  }

  removeAllListeners() {
    this.ammContract.removeAllListeners();
    this.oracleContract.removeAllListeners();
  }

  static formatPrice(price: bigint): string {
    const PRECISION = BigInt(1e18);
    return ((Number(price) / Number(PRECISION)) * 100).toFixed(2) + '%';
  }

  static formatAmount(amount: bigint, decimals: number = 6): string {
    const divisor = BigInt(10 ** decimals);
    const wholePart = amount / divisor;
    const fractionalPart = amount % divisor;
    
    if (fractionalPart === 0n) {
      return wholePart.toString();
    }
    
    const fractionalStr = fractionalPart.toString().padStart(decimals, '0');
    const trimmed = fractionalStr.replace(/0+$/, '');
    
    return trimmed ? `${wholePart}.${trimmed}` : wholePart.toString();
  }

  static parseAmount(amount: string, decimals: number = 6): bigint {
    const parts = amount.split('.');
    const wholePart = BigInt(parts[0] || '0');
    const fractionalPart = parts[1] || '';
    
    const paddedFractional = fractionalPart.padEnd(decimals, '0').slice(0, decimals);
    const fractionalBigInt = BigInt(paddedFractional);
    
    return wholePart * BigInt(10 ** decimals) + fractionalBigInt;
  }
}