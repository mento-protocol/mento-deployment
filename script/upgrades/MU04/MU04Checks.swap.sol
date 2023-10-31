// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console2 as console } from "forge-std/Script.sol";
import { PrecompileHandler } from "celo-foundry/PrecompileHandler.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { FixidityLib } from "mento-core-2.2.0/common/FixidityLib.sol";

import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import { IBiPoolManager } from "mento-core-2.2.0/interfaces/IBiPoolManager.sol";

import { Broker } from "mento-core-2.2.0/swap/Broker.sol";
import { BiPoolManager } from "mento-core-2.2.0/swap/BiPoolManager.sol";
import { SortedOracles } from "mento-core-2.2.0/oracles/SortedOracles.sol";
import { BreakerBox } from "mento-core-2.2.0/oracles/BreakerBox.sol";

import { MU04ChecksBase } from "./MU04Checks.base.sol";
import { MU04Config, Config } from "./Config.sol";

contract MU04ChecksSwap is MU04ChecksBase {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  constructor() public {
    new PrecompileHandler();
    setUp();
  }

  function run() public {
    MU04Config.MU04 memory config = MU04Config.get(contracts);

    console.log("\n== Starting MU04 test swaps: ==");

    for (uint i = 0; i < config.pools.length; i++) {
      console.log(
        "Pool: %s/%s has TradingMode: %s",
        config.pools[i].asset0,
        config.pools[i].asset1,
        BreakerBox(breakerBox).getRateFeedTradingMode(config.pools[i].referenceRateFeedID)
      );
    }

    swapCeloTocUSD(config);
    swapcUSDtoCelo(config);

    swapCeloTocEUR(config);
    swapcEURtoCELO(config);

    swapCeloTocBRL(config);
    swapcBrlToCELO(config);

    swapBridgedUSDCTocUSD(config);
    swapcUSDtoBridgedUSDC(config);

    swapBridgedUSDCTocEUR(config);
    swapcEURtoBridgedUSDC(config);

    swapBridgedUSDCTocBRL(config);
    swapcBRLtoBridgedUSDC(config);

    swapBridgedEUROCTocEUR(config);
    swapcEURtoBridgedEUROC(config);

    swapCeloToEXOF(config);
    swapEXOFtoCelo(config);

    swapBridgedEUROCtoEXOF(config);
    swapEXOFtoBridgedEUROC(config);
  }

  function swapCeloTocUSD(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cUSDCelo.asset0, config.cUSDCelo.asset1, config.cUSDCelo.isConstantSum);

    address trader = vm.addr(5);
    address tokenIn = celoToken;
    address tokenOut = cUSDProxy;
    uint256 amountIn = 10e18;

    // Give trader some celo
    vm.deal(trader, amountIn);

    testAndPerformConstantProductSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cUSDCelo.referenceRateFeedID,
      FixidityLib.wrap(config.cUSDCelo.spread.unwrap())
    );

    console.log("\t🟢 CELO -> cUSD swap successful 🚀");
  }

  function swapcUSDtoCelo(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cUSDCelo.asset0, config.cUSDCelo.asset1, config.cUSDCelo.isConstantSum);

    address trader = vm.addr(5);
    address tokenIn = cUSDProxy;
    address tokenOut = celoToken;
    uint256 amountIn = 1e18;

    testAndPerformConstantProductSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cUSDCelo.referenceRateFeedID,
      FixidityLib.wrap(config.cUSDCelo.spread.unwrap())
    );

    console.log("\t🟢 cUSD -> CELO swap successful 🚀");
  }

  function swapCeloTocEUR(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cEURCelo.asset0, config.cEURCelo.asset1, config.cEURCelo.isConstantSum);

    address trader = vm.addr(5);
    address tokenIn = celoToken;
    address tokenOut = cEURProxy;
    uint256 amountIn = 10e18;

    // Give trader some celo
    vm.deal(trader, amountIn);

    testAndPerformConstantProductSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cEURCelo.referenceRateFeedID,
      FixidityLib.wrap(config.cEURCelo.spread.unwrap())
    );

    console.log("\t🟢 CELO -> cEUR swap successful 🚀");
  }

  function swapcEURtoCELO(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cEURCelo.asset0, config.cEURCelo.asset1, config.cEURCelo.isConstantSum);

    address trader = vm.addr(5);
    address tokenIn = cEURProxy;
    address tokenOut = celoToken;
    uint256 amountIn = 1e18;

    testAndPerformConstantProductSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cEURCelo.referenceRateFeedID,
      FixidityLib.wrap(config.cEURCelo.spread.unwrap())
    );

    console.log("\t🟢 cEUR -> CELO swap successful 🚀");
  }

  function swapCeloTocBRL(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cBRLCelo.asset0, config.cBRLCelo.asset1, config.cBRLCelo.isConstantSum);

    address trader = vm.addr(5);
    address tokenIn = celoToken;
    address tokenOut = cBRLProxy;
    uint256 amountIn = 10e18;

    // Give trader some celo
    vm.deal(trader, amountIn);

    testAndPerformConstantProductSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cBRLCelo.referenceRateFeedID,
      FixidityLib.wrap(config.cBRLCelo.spread.unwrap())
    );

    console.log("\t🟢 CELO -> cBRL swap successful 🚀");
  }

  function swapcBrlToCELO(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cBRLCelo.asset0, config.cBRLCelo.asset1, config.cBRLCelo.isConstantSum);

    address trader = vm.addr(5);
    address tokenIn = cBRLProxy;
    address tokenOut = celoToken;
    uint256 amountIn = 1e18;

    testAndPerformConstantProductSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cBRLCelo.referenceRateFeedID,
      FixidityLib.wrap(config.cBRLCelo.spread.unwrap())
    );

    console.log("\t🟢 cBRL -> CELO swap successful 🚀");
  }

  function swapBridgedUSDCTocUSD(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cUSDUSDC.asset0, config.cUSDUSDC.asset1, config.cUSDUSDC.isConstantSum);

    address trader = vm.addr(1);
    address tokenIn = bridgedUSDC;
    address tokenOut = cUSDProxy;
    uint256 amountIn = 100e6;

    // Mint some USDC to trader
    deal(bridgedUSDC, trader, amountIn, true);

    testAndPerformConstantSumSwap(exchangeID, trader, tokenIn, tokenOut, amountIn, config.cUSDUSDC.referenceRateFeedID);

    console.log("\t🟢 bridgedUSDC -> cUSD swap successful 🚀");
  }

  function swapcUSDtoBridgedUSDC(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cUSDUSDC.asset0, config.cUSDUSDC.asset1, config.cUSDUSDC.isConstantSum);

    address trader = vm.addr(1);
    address tokenIn = cUSDProxy;
    address tokenOut = bridgedUSDC;
    uint256 amountIn = 10e18;

    // Mint some USDC to the reserve
    deal(bridgedUSDC, reserveProxy, 1000e18, true);

    testAndPerformConstantSumSwap(exchangeID, trader, tokenIn, tokenOut, amountIn, config.cUSDUSDC.referenceRateFeedID);

    console.log("\t🟢 cUSD -> bridgedUSDC swap successful 🚀");
  }

  function swapBridgedUSDCTocEUR(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cEURUSDC.asset0, config.cEURUSDC.asset1, config.cEURUSDC.isConstantSum);

    address trader = vm.addr(3);
    address tokenIn = bridgedUSDC;
    address tokenOut = cEURProxy;
    uint256 amountIn = 100e6;

    // Mint some USDC to trader
    deal(bridgedUSDC, trader, amountIn, true);

    testAndPerformConstantSumSwap(exchangeID, trader, tokenIn, tokenOut, amountIn, config.cEURUSDC.referenceRateFeedID);

    console.log("\t🟢 bridgedUSDC -> cEUR swap successful 🚀");
  }

  function swapcEURtoBridgedUSDC(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cEURUSDC.asset0, config.cEURUSDC.asset1, config.cEURUSDC.isConstantSum);

    address trader = vm.addr(3);
    address tokenIn = cEURProxy;
    address tokenOut = bridgedUSDC;
    uint256 amountIn = 10e18;

    testAndPerformConstantSumSwap(exchangeID, trader, tokenIn, tokenOut, amountIn, config.cEURUSDC.referenceRateFeedID);

    console.log("\t🟢 cEUR -> bridgedUSDC swap successful 🚀");
  }

  function swapBridgedUSDCTocBRL(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cBRLUSDC.asset0, config.cBRLUSDC.asset1, config.cBRLUSDC.isConstantSum);

    address trader = vm.addr(4);
    address tokenIn = bridgedUSDC;
    address tokenOut = cBRLProxy;
    uint256 amountIn = 100e6;

    // Mint some USDC to trader
    deal(bridgedUSDC, trader, amountIn, true);

    testAndPerformConstantSumSwap(exchangeID, trader, tokenIn, tokenOut, amountIn, config.cBRLUSDC.referenceRateFeedID);

    console.log("\t🟢 bridgedUSDC -> cBRL swap successful 🚀");
  }

  function swapcBRLtoBridgedUSDC(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cBRLUSDC.asset0, config.cBRLUSDC.asset1, config.cBRLUSDC.isConstantSum);

    address trader = vm.addr(4);
    address tokenIn = cBRLProxy;
    address tokenOut = bridgedUSDC;
    uint256 amountIn = 10e18;

    testAndPerformConstantSumSwap(exchangeID, trader, tokenIn, tokenOut, amountIn, config.cBRLUSDC.referenceRateFeedID);

    console.log("\t🟢 cBRL -> bridgedUSDC swap successful 🚀");
  }

  function swapBridgedEUROCTocEUR(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(
      config.cEUREUROC.asset0,
      config.cEUREUROC.asset1,
      config.cEUREUROC.isConstantSum
    );

    address trader = vm.addr(1);
    address tokenIn = bridgedEUROC;
    address tokenOut = cEURProxy;
    uint256 amountIn = 100e6;

    // Mint some EUROC to trader
    deal(bridgedEUROC, trader, amountIn, true);

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cEUREUROC.referenceRateFeedID
    );

    console.log("\t🟢 bridgedEUROC -> cEUR swap successful 🚀");
  }

  function swapcEURtoBridgedEUROC(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(
      config.cEUREUROC.asset0,
      config.cEUREUROC.asset1,
      config.cEUREUROC.isConstantSum
    );

    address trader = vm.addr(1);
    address tokenIn = cEURProxy;
    address tokenOut = bridgedEUROC;
    uint256 amountIn = 10e18;

    // Mint some USDC to the reserve
    deal(bridgedEUROC, reserveProxy, 1000e18, true);

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cEUREUROC.referenceRateFeedID
    );

    console.log("\t🟢 cEUR -> bridgedEUROC swap successful 🚀");
  }

  function swapCeloToEXOF(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.eXOFCelo.asset0, config.eXOFCelo.asset1, config.eXOFCelo.isConstantSum);
    address trader = vm.addr(5);
    address tokenIn = celoToken;
    address tokenOut = eXOFProxy;
    uint256 amountIn = 100e18;

    // Give trader some celo
    vm.deal(trader, amountIn);

    testAndPerformConstantProductSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.eXOFCelo.referenceRateFeedID,
      FixidityLib.wrap(config.eXOFCelo.spread.unwrap())
    );

    console.log("\t🟢 CELO -> eXOF swap successful 🚀");
  }

  function swapEXOFtoCelo(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.eXOFCelo.asset0, config.eXOFCelo.asset1, config.eXOFCelo.isConstantSum);
    address trader = vm.addr(5);
    address tokenIn = eXOFProxy;
    address tokenOut = celoToken;
    uint256 amountIn = 100e18;

    testAndPerformConstantProductSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.eXOFCelo.referenceRateFeedID,
      FixidityLib.wrap(config.eXOFCelo.spread.unwrap())
    );

    console.log("\t🟢 eXOF -> CELO swap successful 🚀");
  }

  function swapBridgedEUROCtoEXOF(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(
      config.eXOFEUROC.asset0,
      config.eXOFEUROC.asset1,
      config.eXOFEUROC.isConstantSum
    );

    address trader = vm.addr(4);
    address tokenIn = bridgedEUROC;
    address tokenOut = eXOFProxy;
    uint256 amountIn = 10e6;

    // Mint some EUROC to trader
    deal(tokenIn, trader, amountIn);

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.eXOFEUROC.referenceRateFeedID
    );

    console.log("\t🟢 bridgedEUROC -> eXOF swap successful 🚀");
  }

  function swapEXOFtoBridgedEUROC(MU04Config.MU04 memory config) internal {
    bytes32 exchangeID = getExchangeId(
      config.eXOFEUROC.asset0,
      config.eXOFEUROC.asset1,
      config.eXOFEUROC.isConstantSum
    );

    address trader = vm.addr(4);
    address tokenIn = eXOFProxy;
    address tokenOut = bridgedEUROC;
    uint256 amountIn = 100e18;

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.eXOFEUROC.referenceRateFeedID
    );

    console.log("\t🟢 eXOF -> bridgedEUROC swap successful 🚀");
  }

  // *** Helper Functions *** //

  function testAndPerformConstantProductSwap(
    bytes32 exchangeID,
    address trader,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    address rateFeedID,
    FixidityLib.Fraction memory spread
  ) internal {
    uint256 amountOut = Broker(brokerProxy).getAmountOut(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn);
    IBiPoolManager.PoolExchange memory pool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeID);
    (uint256 numerator, uint256 denominator) = SortedOracles(sortedOraclesProxy).medianRate(rateFeedID);
    FixidityLib.Fraction memory rate = FixidityLib.newFixedFraction(numerator, denominator);

    {
      FixidityLib.Fraction memory netAmountIn = FixidityLib.newFixed(amountIn).multiply(
        FixidityLib.fixed1().subtract(spread)
      );

      uint256 estimatedAmountOut;
      if (tokenIn == pool.asset0) {
        estimatedAmountOut = netAmountIn.divide(rate).fromFixed();
      } else {
        estimatedAmountOut = netAmountIn.multiply(rate).fromFixed();
      }
      FixidityLib.Fraction memory maxTolerance = FixidityLib.newFixedFraction(25, 10000);
      uint256 threshold = FixidityLib.newFixed(estimatedAmountOut).multiply(maxTolerance).fromFixed();

      assertApproxEqAbs(amountOut, estimatedAmountOut, threshold);
    }
    doSwapIn(exchangeID, trader, tokenIn, tokenOut, amountIn, amountOut);
  }

  function testAndPerformConstantSumSwap(
    bytes32 exchangeID,
    address trader,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    address rateFeedID
  ) internal {
    uint256 amountOut = Broker(brokerProxy).getAmountOut(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn);
    IBiPoolManager.PoolExchange memory pool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeID);
    (uint256 numerator, uint256 denominator) = SortedOracles(sortedOraclesProxy).medianRate(rateFeedID);
    FixidityLib.Fraction memory rate = FixidityLib.newFixedFraction(numerator, denominator);

    uint256 estimatedAmountOut;
    if (tokenIn == pool.asset0) {
      estimatedAmountOut = FixidityLib.newFixed(amountIn).divide(rate).fromFixed();
      estimatedAmountOut = estimatedAmountOut.div(1e12);
    } else {
      estimatedAmountOut = FixidityLib.newFixed(amountIn.mul(1e12)).multiply(rate).fromFixed();
    }

    FixidityLib.Fraction memory maxTolerance = FixidityLib.newFixedFraction(25, 1000);
    uint256 threshold = FixidityLib.newFixed(estimatedAmountOut).multiply(maxTolerance).fromFixed();

    assertApproxEqAbs(amountOut, estimatedAmountOut, threshold);
    doSwapIn(exchangeID, trader, tokenIn, tokenOut, amountIn, amountOut);
  }

  function doSwapIn(
    bytes32 exchangeID,
    address trader,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOut
  ) internal {
    uint256 beforeBuyingTokenOut = IERC20(tokenOut).balanceOf(trader);
    uint256 beforeSellingTokenIn = IERC20(tokenIn).balanceOf(trader);

    vm.startPrank(trader);
    IERC20(tokenIn).approve(address(brokerProxy), amountIn);
    Broker(brokerProxy).swapIn(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn, amountOut);
    assertEq(IERC20(tokenOut).balanceOf(trader), beforeBuyingTokenOut + amountOut);
    assertEq(IERC20(tokenIn).balanceOf(trader), beforeSellingTokenIn - amountIn);
    vm.stopPrank();
  }

  function assertApproxEq(uint256 a, uint256 b, uint256 maxDelta) internal view {
    uint256 delta = a > b ? a - b : b - a;

    if (delta > maxDelta) {
      console.log("Diff(%s) between amounts is greater than %s", delta, maxDelta);
    }

    require(delta <= maxDelta, "Values are not approximately equal. See logs for more information.");
  }
}
