// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console2 as console } from "forge-std/Script.sol";

import { PrecompileHandler } from "celo-foundry/PrecompileHandler.sol";

import { Contracts } from "script/utils/Contracts.sol";

import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import { FixidityLib } from "mento-core-2.2.0/common/FixidityLib.sol";

import { Broker } from "mento-core-2.2.0/swap/Broker.sol";
import { IBiPoolManager } from "mento-core-2.2.0/interfaces/IBiPoolManager.sol";
import { BiPoolManager } from "mento-core-2.2.0/swap/BiPoolManager.sol";
import { SortedOracles } from "mento-core-2.2.0/oracles/SortedOracles.sol";
import { BreakerBox } from "mento-core-2.2.0/oracles/BreakerBox.sol";

import { cKESChecksBase } from "./cKESChecks.base.sol";
import { cKESConfig, Config } from "./Config.sol";

contract cKESChecksSwap is cKESChecksBase {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  constructor() public {
    new PrecompileHandler();
    setUp();
  }

  function run() public {
    cKESConfig.cKES memory config = cKESConfig.get(contracts);

    console.log("\n== Starting cKES test swaps: ==");

    console.log(
      "KESUSD tradingMode: ",
      BreakerBox(breakerBox).getRateFeedTradingMode(config.rateFeedConfig.rateFeedID)
    );

    swapCUSDToCKES(config);
    swapCKEStoCUSD(config);
  }

  // *** Swap Checks *** //

  function swapCKEStoCUSD(cKESConfig.cKES memory config) internal {
    bytes32 exchangeID = getExchangeId(
      config.poolConfig.asset0,
      config.poolConfig.asset1,
      config.poolConfig.isConstantSum
    );
    address trader = vm.addr(5);
    address tokenIn = cKES;
    address tokenOut = cUSD;
    uint256 amountIn = 100e18;

    //TODO:
    // Give trader some cKES
    deal(cKES, trader, 1000e18, true);

    testAndPerformConstantProductSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.poolConfig.referenceRateFeedID
    );

    console.log("🟢 cKES -> cUSD swap successful 🚀");
  }

  function swapCUSDToCKES(cKESConfig.cKES memory config) internal {
    bytes32 exchangeID = getExchangeId(
      config.poolConfig.asset0,
      config.poolConfig.asset1,
      config.poolConfig.isConstantSum
    );
    address trader = vm.addr(5);
    address tokenIn = cUSD;
    address tokenOut = cKES;
    uint256 amountIn = 100e18;

    testAndPerformConstantProductSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.poolConfig.referenceRateFeedID
    );

    console.log("🟢 cKES -> CELO swap successful 🚀");
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
