const { ethers } = require('ethers');
const { PredictionMarketSDK } = require('../sdk/dist');

async function main() {
  // Configuration
  const provider = new ethers.JsonRpcProvider('http://localhost:8545');
  const privateKey = '0x...'; // Your private key
  const signer = new ethers.Wallet(privateKey, provider);
  
  const contracts = {
    amm: '0x...', // Update with deployed address
    oracle: '0x...',
    collateralToken: '0x...'
  };

  // Initialize SDK
  const sdk = new PredictionMarketSDK(provider, contracts, signer);

  try {
    console.log('🎯 Basic Trading Example');
    console.log('========================');

    // 1. Get some test tokens
    console.log('\n1. Getting test tokens...');
    await sdk.faucet();
    const balance = await sdk.getCollateralBalance(await signer.getAddress());
    console.log(`Balance: ${PredictionMarketSDK.formatAmount(balance)} USDC`);

    // 2. Create a market
    console.log('\n2. Creating market...');
    const marketId = await sdk.createMarket({
      question: "Will the next block number be even?",
      endTime: BigInt(Math.floor(Date.now() / 1000) + 3600), // 1 hour from now
      initialLiquidity: PredictionMarketSDK.parseAmount('1000'), // 1000 USDC
      fee: BigInt(100) // 1%
    });
    console.log(`Market created with ID: ${marketId}`);

    // 3. Check initial prices
    console.log('\n3. Initial market prices:');
    const priceInfo = await sdk.getPriceInfo(BigInt(marketId));
    console.log(`YES: ${PredictionMarketSDK.formatPrice(priceInfo.yesPrice)}`);
    console.log(`NO: ${PredictionMarketSDK.formatPrice(priceInfo.noPrice)}`);
    console.log(`Implied Probability: ${(priceInfo.impliedProbability * 100).toFixed(2)}%`);

    // 4. Get a trade quote
    console.log('\n4. Getting trade quote for 100 USDC on YES...');
    const tradeAmount = PredictionMarketSDK.parseAmount('100');
    const quote = await sdk.getTradeQuote(BigInt(marketId), true, tradeAmount);
    console.log(`Shares out: ${PredictionMarketSDK.formatAmount(quote.sharesOut)}`);
    console.log(`Effective price: ${PredictionMarketSDK.formatPrice(quote.effectivePrice)}`);
    console.log(`Price impact: ${quote.priceImpact.toFixed(4)}%`);
    console.log(`Fee: ${PredictionMarketSDK.formatAmount(quote.fee)} USDC`);

    // 5. Execute the trade
    console.log('\n5. Executing trade...');
    const tradeTx = await sdk.trade({
      marketId: BigInt(marketId),
      isYes: true,
      tokensIn: tradeAmount,
      minSharesOut: BigInt(0) // Accept any slippage for demo
    });
    console.log(`Trade executed: ${tradeTx}`);

    // 6. Check updated prices
    console.log('\n6. Updated market prices after trade:');
    const newPriceInfo = await sdk.getPriceInfo(BigInt(marketId));
    console.log(`YES: ${PredictionMarketSDK.formatPrice(newPriceInfo.yesPrice)}`);
    console.log(`NO: ${PredictionMarketSDK.formatPrice(newPriceInfo.noPrice)}`);

    // 7. Check user shares
    console.log('\n7. User shares:');
    const userShares = await sdk.getUserShares(BigInt(marketId), await signer.getAddress());
    console.log(`LP Shares: ${PredictionMarketSDK.formatAmount(userShares.lpShares)}`);
    console.log(`YES Shares: ${PredictionMarketSDK.formatAmount(userShares.yesShares)}`);
    console.log(`NO Shares: ${PredictionMarketSDK.formatAmount(userShares.noShares)}`);

    console.log('\n✅ Basic trading example completed successfully!');

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    sdk.removeAllListeners();
  }
}

main().catch(console.error);