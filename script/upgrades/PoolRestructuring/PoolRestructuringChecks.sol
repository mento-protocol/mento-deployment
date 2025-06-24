// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable var-name-mixedcase, func-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { GovernanceScript } from "script/utils/Script.sol";

import { IBiPoolManager, FixidityLib } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";
import { ValueDeltaBreaker } from "mento-core-2.5.0/oracles/breakers/ValueDeltaBreaker.sol";
import { TradingLimits } from "mento-core-2.5.0/libraries/TradingLimits.sol";

import { PoolRestructuringConfig } from "./Config.sol";
import { Config } from "script/utils/Config.sol";

interface IBrokerWithCasts {
  function tradingLimitsConfig(bytes32 id) external view returns (TradingLimits.Config memory);
}

contract PoolRestructuringChecks is GovernanceScript, Test {
  using TradingLimits for TradingLimits.Config;
  using Contracts for Contracts.Cache;

  PoolRestructuringConfig private config;

  address private brokerProxy;
  address private biPoolManagerProxy;
  address private valueDeltaBreaker;

  mapping(address => bytes32) public referenceRateFeedIDToExchangeId;

  function prepare() public {
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");

    config = new PoolRestructuringConfig();
    config.load();

    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    valueDeltaBreaker = contracts.deployed("ValueDeltaBreaker");

    setReferenceRateFeedIDToExchangeId();
  }

  function run() public {
    prepare();

    console2.log("\n");

    checkPoolsAreDeletedAndRecreatedWithNewSpread();
    checkValueDeltaBreakersThresholds();
    checkTradingLimits();

    console2.log("\n");
    console2.log("✅ All checks passed\n");
  }

  function setReferenceRateFeedIDToExchangeId() public {
    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);
    bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();

    for (uint256 i = 0; i < exchangeIds.length; i++) {
      bytes32 exchangeId = exchangeIds[i];
      IBiPoolManager.PoolExchange memory currentExchange = biPoolManager.getPoolExchange(exchangeId);

      referenceRateFeedIDToExchangeId[currentExchange.config.referenceRateFeedID] = exchangeId;
    }
  }

  function checkPoolsAreDeletedAndRecreatedWithNewSpread() internal {
    console2.log("====🔍 Checking current pools state... ====");

    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);

    bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();
    for (uint256 i = 0; i < exchangeIds.length; i++) {
      bytes32 exchangeId = exchangeIds[i];
      IBiPoolManager.PoolExchange memory exchange = biPoolManager.getPoolExchange(exchangeId);

      if (config.shouldBeDeleted(exchange)) {
        // If this pool was supposed to be deleted but it's still there, it means it was part of the ones that
        // had to be re-created with a new spread.
        require(
          config.shouldRecreateWithNewSpread(exchange),
          "❌ Failed to delete pool without a newly proposed spread"
        );

        (, FixidityLib.Fraction memory targetSpread) = config.getCurrentAndTargetSpread(exchange);
        require(FixidityLib.equals(exchange.config.spread, targetSpread), "❌ Re-created pool with wrong spread");

        console2.log("✅ Re-created pool %s with new spread", config.getFeedName(exchange.config.referenceRateFeedID));
      }
    }

    uint256 poolsDeletedButNotRecreated = config.poolsToDelete().length - config.spreadOverrides().length;
    console2.log("✅ Other non-USD pools (%d) were permanently deleted\n", poolsDeletedButNotRecreated);
  }

  function checkValueDeltaBreakersThresholds() internal {
    console2.log("====🔍 Checking updated ValueDeltaBreaker thresholds... ====");

    PoolRestructuringConfig.ValueDeltaBreakerOverride[] memory overrides = config.valueDeltaBreakerOverrides();
    for (uint256 i = 0; i < overrides.length; i++) {
      uint256 currentThreshold = ValueDeltaBreaker(valueDeltaBreaker).rateChangeThreshold(overrides[i].rateFeedId);
      require(currentThreshold == overrides[i].targetThreshold, "❌ ValueDeltaBreaker threshold not updated");

      console2.log("✅ Threshold updated for %s feed", config.getFeedName(overrides[i].rateFeedId));
    }
    console2.log("\n");
  }

  function checkTradingLimits() internal {
    console2.log("====🔍 Checking updated trading limits... ====");

    IBrokerWithCasts _broker = IBrokerWithCasts(brokerProxy);
    PoolRestructuringConfig.TradingLimitsOverride[] memory overrides = config.tradingLimitsOverrides();

    for (uint256 i = 0; i < overrides.length; i++) {
      bytes32 exchangeId = referenceRateFeedIDToExchangeId[overrides[i].referenceRateFeedID];

      bytes32 asset0LimitId = exchangeId ^ bytes32(uint256(uint160(overrides[i].asset0)));
      TradingLimits.Config memory asset0ActualLimit = _broker.tradingLimitsConfig(asset0LimitId);

      bytes32 asset1LimitId = exchangeId ^ bytes32(uint256(uint160(overrides[i].asset1)));
      TradingLimits.Config memory asset1ActualLimit = _broker.tradingLimitsConfig(asset1LimitId);

      checkTradingLimt(overrides[i].asset0Config, asset0ActualLimit);
      checkTradingLimt(overrides[i].asset1Config, asset1ActualLimit);

      console2.log("✅ Trading limits updated for %s feed", config.getFeedName(overrides[i].referenceRateFeedID));
    }
  }

  function checkTradingLimt(
    Config.TradingLimit memory expectedTradingLimit,
    TradingLimits.Config memory actualTradingLimit
  ) internal view {
    if (expectedTradingLimit.limit0 != actualTradingLimit.limit0) {
      console2.log("limit0 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.limit1 != actualTradingLimit.limit1) {
      console2.log("limit1 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.limitGlobal != actualTradingLimit.limitGlobal) {
      console2.log("limitGlobal was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.timeStep0 != actualTradingLimit.timestep0) {
      console2.log("timestep0 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.timeStep1 != actualTradingLimit.timestep1) {
      console2.log("timestep1 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }

    uint8 tradingLimitFlags = Config.tradingLimitConfigToFlag(expectedTradingLimit);
    if (tradingLimitFlags != actualTradingLimit.flags) {
      console2.log("flags were not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
  }
}
