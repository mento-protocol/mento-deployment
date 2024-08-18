// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console } from "forge-std/console.sol";
import { PrecompileHandler } from "celo-foundry/PrecompileHandler.sol";

import { Contracts } from "script/utils/v1/Contracts.sol";

import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import { FixidityLib } from "mento-core-2.2.0/common/FixidityLib.sol";

import { Broker } from "mento-core-2.2.0/swap/Broker.sol";
import { IBiPoolManager } from "mento-core-2.2.0/interfaces/IBiPoolManager.sol";
import { BiPoolManager } from "mento-core-2.2.0/swap/BiPoolManager.sol";
import { SortedOracles } from "mento-core-2.2.0/oracles/SortedOracles.sol";
import { BreakerBox } from "mento-core-2.2.0/oracles/BreakerBox.sol";

import { eXOFChecksBase } from "./eXOFChecks.base.sol";
import { eXOFConfig, Config } from "./Config.sol";

contract eXOFChecksSwap is eXOFChecksBase {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  constructor() public {
    new PrecompileHandler();
    setUp();
  }

  function run() public {
    eXOFConfig.eXOF memory config = eXOFConfig.get(contracts);

    console.log("\n== Starting eXOF test swaps: ==");

    console.log("EUROCXOF tradingMode: ", BreakerBox(breakerBox).getRateFeedTradingMode(config.EUROCXOF.rateFeedID));
    console.log("CELOXOF tradingMode: ", BreakerBox(breakerBox).getRateFeedTradingMode(config.CELOXOF.rateFeedID));
    console.log("EURXOF tradingMode: ", BreakerBox(breakerBox).getRateFeedTradingMode(config.EURXOF.rateFeedID));

    swapCeloToEXOF(config);
    swapEXOFtoCelo(config);
    swapBridgedEUROCtoEXOF(config);
    swapEXOFtoBridgedEUROC(config);
  }

  // *** Swap Checks *** //

  function swapCeloToEXOF(eXOFConfig.eXOF memory config) internal {
    bytes32 exchangeID = getExchangeId(config.eXOFCelo.asset0, config.eXOFCelo.asset1, config.eXOFCelo.isConstantSum);
    address trader = vm.addr(5);
    address tokenIn = celoToken;
    address tokenOut = eXOF;
    uint256 amountIn = 100e18;

    // Give trader some celo
    vm.deal(trader, amountIn);

    testAndPerformConstantProductSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.eXOFCelo.referenceRateFeedID
    );

    console.log("🟢 CELO -> eXOF swap successful 🚀");
  }

  function swapEXOFtoCelo(eXOFConfig.eXOF memory config) internal {
    bytes32 exchangeID = getExchangeId(config.eXOFCelo.asset0, config.eXOFCelo.asset1, config.eXOFCelo.isConstantSum);
    address trader = vm.addr(5);
    address tokenIn = eXOF;
    address tokenOut = celoToken;
    uint256 amountIn = 100e18;

    testAndPerformConstantProductSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.eXOFCelo.referenceRateFeedID
    );

    console.log("🟢 eXOF -> CELO swap successful 🚀");
  }

  function swapBridgedEUROCtoEXOF(eXOFConfig.eXOF memory config) internal {
    bytes32 exchangeID = getExchangeId(
      config.eXOFEUROC.asset0,
      config.eXOFEUROC.asset1,
      config.eXOFEUROC.isConstantSum
    );

    address trader = vm.addr(4);
    address tokenIn = bridgedEUROC;
    address tokenOut = eXOF;
    uint256 amountIn = 10e6;

    // Mint some EUROC to trader
    deal(tokenIn, trader, amountIn);

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.eXOFEUROC.referenceRateFeedID,
      true
    );

    console.log("🟢 bridgedEUROC -> eXOF swap successful 🚀");
  }

  function swapEXOFtoBridgedEUROC(eXOFConfig.eXOF memory config) internal {
    bytes32 exchangeID = getExchangeId(
      config.eXOFEUROC.asset0,
      config.eXOFEUROC.asset1,
      config.eXOFEUROC.isConstantSum
    );

    address trader = vm.addr(4);
    address tokenIn = eXOF;
    address tokenOut = bridgedEUROC;
    uint256 amountIn = 100e18;

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.eXOFEUROC.referenceRateFeedID,
      false
    );

    console.log("🟢 eXOF -> bridgedEUROC swap successful 🚀");
  }

  // *** Helper Functions *** //

  function testAndPerformConstantProductSwap(
    bytes32 exchangeID,
    address trader,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    address rateFeedID
  ) internal {
    uint256 amountOut = Broker(broker).getAmountOut(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn);
    IBiPoolManager.PoolExchange memory pool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeID);

    (uint256 numerator, uint256 denominator) = SortedOracles(sortedOraclesProxy).medianRate(rateFeedID);
    FixidityLib.Fraction memory rate = FixidityLib.newFixedFraction(numerator, denominator);

    FixidityLib.Fraction memory amountInAfterSpread = FixidityLib.newFixed(amountIn).multiply(
      FixidityLib.newFixedFraction(9950, 10000)
    );

    uint256 estimatedAmountOut;
    if (tokenIn == pool.asset0) {
      estimatedAmountOut = amountInAfterSpread.divide(rate).fromFixed();
    } else {
      estimatedAmountOut = amountInAfterSpread.multiply(rate).fromFixed();
    }

    FixidityLib.Fraction memory maxTolerance = FixidityLib.newFixedFraction(25, 1000);
    uint256 threshold = FixidityLib.newFixed(estimatedAmountOut).multiply(maxTolerance).fromFixed();

    assertApproxEq(amountOut, estimatedAmountOut, threshold);
    doSwapIn(exchangeID, trader, tokenIn, tokenOut, amountIn, amountOut);
  }

  function testAndPerformConstantSumSwap(
    bytes32 exchangeID,
    address trader,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    address rateFeedID,
    bool isInputTokenBridgedStable
  ) internal {
    uint256 amountOut = Broker(broker).getAmountOut(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn);
    (uint256 numerator, uint256 denominator) = SortedOracles(sortedOraclesProxy).medianRate(rateFeedID);
    uint256 estimatedAmountOut;

    if (isInputTokenBridgedStable) {
      estimatedAmountOut = FixidityLib
        .newFixed(amountIn.mul(1e12))
        .multiply(FixidityLib.wrap(numerator).divide(FixidityLib.wrap(denominator)))
        .fromFixed();
    } else {
      estimatedAmountOut = FixidityLib
        .newFixed(amountIn)
        .multiply(FixidityLib.wrap(denominator).divide(FixidityLib.wrap(numerator)))
        .fromFixed();
      estimatedAmountOut = estimatedAmountOut.div(1e12);
    }

    FixidityLib.Fraction memory maxTolerance = FixidityLib.newFixedFraction(25, 1000);
    uint256 threshold = FixidityLib.newFixed(estimatedAmountOut).multiply(maxTolerance).fromFixed();
    assertApproxEq(amountOut, estimatedAmountOut, threshold);
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
    IERC20(tokenIn).approve(address(broker), amountIn);
    Broker(broker).swapIn(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn, amountOut);
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
