// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console2 as console } from "forge-std/Script.sol";

import { PrecompileHandler } from "celo-foundry/PrecompileHandler.sol";

import { Contracts } from "script/utils/Contracts.sol";

import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "mento-core-2.3.1/common/interfaces/IERC20Metadata.sol";
import { IStableTokenV2 } from "mento-core-2.3.1/interfaces/IStableTokenV2.sol";

import { FixidityLib } from "mento-core-2.3.1/common/FixidityLib.sol";

import { Broker } from "mento-core-2.3.1/swap/Broker.sol";
import { IBiPoolManager } from "mento-core-2.3.1/interfaces/IBiPoolManager.sol";
import { BiPoolManager } from "mento-core-2.3.1/swap/BiPoolManager.sol";
import { SortedOracles } from "mento-core-2.3.1/common/SortedOracles.sol";
import { BreakerBox } from "mento-core-2.3.1/oracles/BreakerBox.sol";

import { FX01ChecksBase } from "./FX01Checks.base.sol";
import { FX01Config, Config } from "./Config.sol";

import { Chain } from "script/utils/Chain.sol";

contract FX01ChecksSwap is FX01ChecksBase {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  constructor() public {
    new PrecompileHandler();
    setUp();
  }

  function run() public {
    FX01Config.FX01 memory config = FX01Config.get(contracts);

    console.log("\n== Starting cGBP, cZAR, cCAD & cAUD test swaps: ==");

    for (uint256 i = 0; i < config.pools.length; i++) {
      Config.Pool memory pool = config.pools[i];
      bytes32 exchangeId = getExchangeId(pool.asset0, pool.asset1, pool.isConstantSum);

      // cUSD to asset1
      performTestSwap(pool.asset0, pool.asset1, exchangeId, pool);

      // asset1 to cUSD
      performTestSwap(pool.asset1, pool.asset0, exchangeId, pool);
    }
  }

  // *** Swap Checks *** //
  function performTestSwap(address tokenIn, address tokenOut, bytes32 exchangeID, Config.Pool memory config) internal {
    address trader = vm.addr(5);
    uint256 amountIn = 100e18;
    string memory tokenInSymbol = IERC20Metadata(tokenIn).symbol();
    string memory tokenOutSymbol = IERC20Metadata(tokenOut).symbol();

    if (tokenIn == cUSD) {
      deal(tokenIn, trader, amountIn);
    } else {
      vm.startPrank(broker);
      IStableTokenV2(tokenIn).mint(trader, amountIn);
      vm.stopPrank();
    }

    console.log("=========================== BEFORE SWAP ====================================");
    console.log("============================================================================");
    console.log(tokenInSymbol, "balance: ", IERC20(tokenIn).balanceOf(trader));
    console.log(tokenOutSymbol, "balance: ", IERC20(tokenOut).balanceOf(trader));
    console.log("============================================================================\r\n");

    testAndPerformConstantSumSwap(exchangeID, trader, tokenIn, tokenOut, amountIn, config.referenceRateFeedID);

    console.log("============================ AFTER SWAP ====================================");
    console.log("============================================================================");
    console.log(tokenInSymbol, "balance: ", IERC20(tokenIn).balanceOf(trader));
    console.log(tokenOutSymbol, "balance: ", IERC20(tokenOut).balanceOf(trader));
    console.log("============================================================================\r\n");
    console.log("🟢 %s -> %s swap successful 🚀", tokenInSymbol, tokenOutSymbol);
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
    uint256 amountOut = Broker(broker).getAmountOut(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn);

    // This is the asset 1 to USD rate
    (uint256 numerator, uint256 denominator) = SortedOracles(sortedOraclesProxy).medianRate(rateFeedID);
    uint256 estimatedAmountOut;

    // If asset 0 is cUSD flip the rate]
    if (tokenIn == cUSD) {
      (numerator, denominator) = (denominator, numerator);
    }

    estimatedAmountOut = FixidityLib
      .newFixed(amountIn)
      .multiply(FixidityLib.wrap(numerator).divide(FixidityLib.wrap(denominator)))
      .fromFixed();

    console.log("\r=========================== AMOUNTS ====================================");
    console.log("============================================================================");
    console.log("Amount In: ", amountIn);
    console.log("Broker amount out(Broker.getAmountOut)", amountOut);
    console.log("Estimated amount out(amountIn * num/dennom): ", estimatedAmountOut);

    assertApproxEqRel(amountOut, estimatedAmountOut, 25 * 1e15 /* 0.025 or 2.5% */);
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
    uint256 actualAmountOut = Broker(broker).swapIn(
      biPoolManagerProxy,
      exchangeID,
      tokenIn,
      tokenOut,
      amountIn,
      amountOut
    );
    console.log("Actual amount out: ", actualAmountOut);
    console.log("============================================================================\r\n");
    assertEq(IERC20(tokenOut).balanceOf(trader), beforeBuyingTokenOut + amountOut);
    assertEq(IERC20(tokenIn).balanceOf(trader), beforeSellingTokenIn - amountIn);
    vm.stopPrank();
  }
}
