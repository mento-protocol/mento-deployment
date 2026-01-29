// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { Test } from "forge-std/Test.sol";
import { Script } from "script/utils/mento/Script.sol";
import { console2 as console } from "forge-std/Script.sol";

import { IBiPoolManager, FixidityLib } from "mento-core-2.6.5/interfaces/IBiPoolManager.sol";
import { IValueDeltaBreaker } from "mento-core-2.6.5/interfaces/IValueDeltaBreaker.sol";
import { IProxy } from "mento-core-2.5.0/common/interfaces/IProxy.sol";

import { MGP13Config } from "./Config.sol";

contract MGP13Checks is Script, Test {
  MGP13Config private config;
  IBiPoolManager private biPoolManager;
  address private biPoolManagerProxy;
  address private expectedBiPoolManagerImpl;
  address private valueDeltaBreaker;

  constructor() {
    config = new MGP13Config();
    config.load();
    biPoolManagerProxy = config.biPoolManagerProxy();
    expectedBiPoolManagerImpl = config.currentBiPoolManagerImpl();
    biPoolManager = IBiPoolManager(biPoolManagerProxy);
    valueDeltaBreaker = config.valueDeltaBreaker();
  }

  function run() public {
    require(
      IProxy(biPoolManagerProxy)._getImplementation() == expectedBiPoolManagerImpl,
      "BiPoolManager proxy implementation mismatch"
    );

    console.log("==========================================");
    console.log(unicode"👀 MGP-13 — Proposal Checks");
    console.log("");
    console.log(unicode"🟢 BiPoolManager proxy implementation restored to:");
    console.log("\t", expectedBiPoolManagerImpl);
    console.log("");

    MGP13Config.SpreadOverride[] memory spreadOverrides = config.spreadOverrides();

    console.log(unicode"🟢 Spread updated for (%d) exchanges:", spreadOverrides.length);
    for (uint256 i = 0; i < spreadOverrides.length; i++) {
      MGP13Config.SpreadOverride memory overrideConfig = spreadOverrides[i];
      IBiPoolManager.PoolExchange memory exchange = biPoolManager.getPoolExchange(overrideConfig.exchangeId);

      require(exchange.asset0 == overrideConfig.asset0, "asset0 mismatch on spread override");
      require(exchange.asset1 == overrideConfig.asset1, "asset1 mismatch on spread override");
      require(
        FixidityLib.equals(exchange.config.spread, overrideConfig.newSpread),
        "updated spread mismatch on spread override"
      );

      console.log("\t", overrideConfig.name);
    }

    console.log("");

    MGP13Config.ValueDeltaBreakerThresholdOverride[] memory thresholdOverrides = config
      .valueDeltaBreakerThresholdOverrides();
    require(thresholdOverrides.length > 0, "No value delta breaker overrides configured");

    console.log(unicode"🟢 ValueDeltaBreaker threshold updated for (%d) feeds:", thresholdOverrides.length);
    for (uint256 i = 0; i < thresholdOverrides.length; i++) {
      uint256 currentThreshold = IValueDeltaBreaker(valueDeltaBreaker).rateChangeThreshold(
        thresholdOverrides[i].rateFeedID
      );
      require(currentThreshold == thresholdOverrides[i].newThreshold, "ValueDeltaBreaker threshold mismatch");
      console.log("\t", thresholdOverrides[i].rateFeedID);
    }

    console.log("");
  }
}
