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

import { MU05ChecksBase } from "./MU05Checks.base.sol";
import { MU05Config } from "./Config.sol";

contract MU05ChecksSwap is MU05ChecksBase {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  constructor() public {
    new PrecompileHandler();
    setUp();
  }

  function run() public {
    MU05Config.MU05 memory config = MU05Config.get(contracts);

    console.log("\n== Starting MU05 test swaps: ==");

    for (uint i = 0; i < config.pools.length; i++) {
      console.log(
        "Pool: %s/%s has TradingMode: %s",
        config.pools[i].asset0,
        config.pools[i].asset1,
        BreakerBox(breakerBox).getRateFeedTradingMode(config.pools[i].referenceRateFeedID)
      );
    }

    swapNativeUSDCTocUSD(config);
    swapcUSDtoNativeUSDC(config);

    swapNativeUSDCTocEUR(config);
    swapcEURtoNativeUSDC(config);

    swapNativeUSDCTocBRL(config);
    swapcBRLtoNativeUSDC(config);
  }

  function swapNativeUSDCTocUSD(MU05Config.MU05 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cUSDUSDC.asset0, config.cUSDUSDC.asset1, config.cUSDUSDC.isConstantSum);

    address trader = vm.addr(1);
    address tokenIn = nativeUSDC;
    address tokenOut = cUSDProxy;
    uint256 amountIn = 100e6;

    // Mint some USDC to trader
    deal(nativeUSDC, trader, amountIn, true);

    testAndPerformConstantSumSwap(exchangeID, trader, tokenIn, tokenOut, amountIn, config.cUSDUSDC.referenceRateFeedID);

    console.log("\t🟢 native USDC -> cUSD swap successful 🚀");
  }

  function swapcUSDtoNativeUSDC(MU05Config.MU05 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cUSDUSDC.asset0, config.cUSDUSDC.asset1, config.cUSDUSDC.isConstantSum);

    address trader = vm.addr(1);
    address tokenIn = cUSDProxy;
    address tokenOut = nativeUSDC;
    uint256 amountIn = 10e18;

    // Mint some USDC to the reserve
    deal(nativeUSDC, reserveProxy, 1000e18, true);

    testAndPerformConstantSumSwap(exchangeID, trader, tokenIn, tokenOut, amountIn, config.cUSDUSDC.referenceRateFeedID);

    console.log("\t🟢 cUSD -> native USDC swap successful 🚀");
  }

  function swapNativeUSDCTocEUR(MU05Config.MU05 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cEURUSDC.asset0, config.cEURUSDC.asset1, config.cEURUSDC.isConstantSum);

    address trader = vm.addr(3);
    address tokenIn = nativeUSDC;
    address tokenOut = cEURProxy;
    uint256 amountIn = 100e6;

    // Mint some USDC to trader
    deal(nativeUSDC, trader, amountIn, true);

    testAndPerformConstantSumSwap(exchangeID, trader, tokenIn, tokenOut, amountIn, config.cEURUSDC.referenceRateFeedID);

    console.log("\t🟢 native USDC -> cEUR swap successful 🚀");
  }

  function swapcEURtoNativeUSDC(MU05Config.MU05 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cEURUSDC.asset0, config.cEURUSDC.asset1, config.cEURUSDC.isConstantSum);

    address trader = vm.addr(3);
    address tokenIn = cEURProxy;
    address tokenOut = nativeUSDC;
    uint256 amountIn = 10e18;

    testAndPerformConstantSumSwap(exchangeID, trader, tokenIn, tokenOut, amountIn, config.cEURUSDC.referenceRateFeedID);

    console.log("\t🟢 cEUR -> native USDC swap successful 🚀");
  }

  function swapNativeUSDCTocBRL(MU05Config.MU05 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cBRLUSDC.asset0, config.cBRLUSDC.asset1, config.cBRLUSDC.isConstantSum);

    address trader = vm.addr(4);
    address tokenIn = nativeUSDC;
    address tokenOut = cBRLProxy;
    uint256 amountIn = 100e6;

    // Mint some USDC to trader
    deal(nativeUSDC, trader, amountIn, true);

    testAndPerformConstantSumSwap(exchangeID, trader, tokenIn, tokenOut, amountIn, config.cBRLUSDC.referenceRateFeedID);

    console.log("\t🟢 native USDC -> cBRL swap successful 🚀");
  }

  function swapcBRLtoNativeUSDC(MU05Config.MU05 memory config) internal {
    bytes32 exchangeID = getExchangeId(config.cBRLUSDC.asset0, config.cBRLUSDC.asset1, config.cBRLUSDC.isConstantSum);

    address trader = vm.addr(4);
    address tokenIn = cBRLProxy;
    address tokenOut = nativeUSDC;
    uint256 amountIn = 10e18;

    testAndPerformConstantSumSwap(exchangeID, trader, tokenIn, tokenOut, amountIn, config.cBRLUSDC.referenceRateFeedID);

    console.log("\t🟢 cBRL -> native USDC swap successful 🚀");
  }

  // *** Helper Functions *** //

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
