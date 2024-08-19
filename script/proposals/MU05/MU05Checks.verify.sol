// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console } from "forge-std/console.sol";
import { FixidityLib } from "mento-core-2.2.0/common/FixidityLib.sol";

import { Reserve } from "mento-core-2.2.0/swap/Reserve.sol";
import { TradingLimits } from "mento-core-2.2.0/libraries/TradingLimits.sol";

import { MU05ChecksBase } from "./MU05Checks.base.sol";
import { MU05Config, Config } from "./Config.sol";

/**
 * @title IBrokerWithCasts
 * @notice Interface for Broker with tuple -> struct casting
 * @dev This is used to access the internal trading limits
 * config as a struct as opposed to a tuple.
 */
interface IBrokerWithCasts {
  function tradingLimitsConfig(bytes32 id) external view returns (TradingLimits.Config memory);
}

contract MU05ChecksVerify is MU05ChecksBase {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;

  constructor() public {
    setUp();
  }

  function run() public {
    console.log("\nStarting MU05 checks:");
    MU05Config.MU05 memory config = MU05Config.get(contracts);

    verifyReserveCollateralAssets();
    verifyTradingLimits(config);
  }

  function verifyReserveCollateralAssets() internal {
    console.log("\n== Verifying Reserve Collateral Assets ==");

    require(Reserve(reserveProxy).isCollateralAsset(nativeUSDC), "❗️❌ Reserve collateral asset not set correctly");

    // mint some native USDC to the main reserve in order to verify spending ratios
    deal(nativeUSDC, reserveProxy, 100e6);
    verifyCollateralSpendingRatio(nativeUSDC, 1e24);
    console.log("🟢 Asset: %s successfully added to collateral asset list", nativeUSDC);
  }

  function verifyTradingLimits(MU05Config.MU05 memory config) internal view {
    console.log("\n== Verifying TradingLimits changes in Broker ==");
    IBrokerWithCasts _broker = IBrokerWithCasts(brokerProxy);

    for (uint256 i = 0; i < config.pools.length; i++) {
      bytes32 exchangeId = getExchangeId(config.pools[i].asset0, config.pools[i].asset1, config.pools[i].isConstantSum);
      Config.Pool memory poolConfig = config.pools[i];

      bytes32 asset0LimitId = exchangeId ^ bytes32(uint256(uint160(config.pools[i].asset0)));
      TradingLimits.Config memory asset0ActualLimit = _broker.tradingLimitsConfig(asset0LimitId);

      bytes32 asset1LimitId = exchangeId ^ bytes32(uint256(uint160(config.pools[i].asset1)));
      TradingLimits.Config memory asset1ActualLimit = _broker.tradingLimitsConfig(asset1LimitId);

      checkTradingLimt(poolConfig.asset0limits, asset0ActualLimit);
      checkTradingLimt(poolConfig.asset1limits, asset1ActualLimit);
    }

    console.log("🟢 Trading limits correctly updated for all exchanges 🔒");
  }

  function verifyCollateralSpendingRatio(address collateralAsset, uint256 expectedRatio) internal {
    console.log("\n== Verifying Collateral Spending Ratio for %s ==", collateralAsset);
    // @notice verifying spending ratios by trying to move the allowed, and more than the allowed amount
    // the variable holding the ratios is private

    address[] memory otherReserveAddresses = Reserve(reserveProxy).getOtherReserveAddresses();
    address payable otherReserve = address(uint160(otherReserveAddresses[0]));
    uint256 reserveBalance = Reserve(reserveProxy).getReserveAddressesCollateralAssetBalance(collateralAsset);

    uint256 spendingLimit = FixidityLib.wrap(expectedRatio).multiply(FixidityLib.newFixed(reserveBalance)).fromFixed();
    uint256 exceedingAmount = spendingLimit + 1;

    vm.prank(reserveSpender);
    vm.expectRevert("Exceeding spending limit");
    Reserve(reserveProxy).transferCollateralAsset(collateralAsset, otherReserve, exceedingAmount);
    console.log("🟢 Couldn't transfer more than the allowed amount");

    vm.prank(reserveSpender);
    Reserve(reserveProxy).transferCollateralAsset(collateralAsset, otherReserve, spendingLimit);
    console.log("🟢 Successfully transferred the max allowed amount");

    console.log("🟢 Spending ratio for Asset: %s successfully set to ", collateralAsset, expectedRatio);
  }

  function checkTradingLimt(
    Config.TradingLimit memory expectedTradingLimit,
    TradingLimits.Config memory actualTradingLimit
  ) internal pure {
    if (expectedTradingLimit.limit0 != actualTradingLimit.limit0) {
      console.log("limit0 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.limit1 != actualTradingLimit.limit1) {
      console.log("limit1 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.limitGlobal != actualTradingLimit.limitGlobal) {
      console.log("limitGlobal was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.timeStep0 != actualTradingLimit.timestep0) {
      console.log("timestep0 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.timeStep1 != actualTradingLimit.timestep1) {
      console.log("timestep1 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }

    uint8 tradingLimitFlags = Config.tradingLimitConfigToFlag(expectedTradingLimit);
    if (tradingLimitFlags != actualTradingLimit.flags) {
      console.log("flags were not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
  }
}
