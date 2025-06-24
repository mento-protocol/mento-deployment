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
import { BreakerBox } from "mento-core-2.5.0/oracles/BreakerBox.sol";
import { MedianDeltaBreaker } from "mento-core-2.5.0/oracles/breakers/MedianDeltaBreaker.sol";
import { ValueDeltaBreaker } from "mento-core-2.5.0/oracles/breakers/ValueDeltaBreaker.sol";
import { TradingLimits } from "mento-core-2.5.0/libraries/TradingLimits.sol";

import { Config } from "script/utils/Config.sol";
import { NewPoolsCfg } from "./NewPoolsCfg.sol";

import { CfgHelper } from "script/upgrades/PoolRestructuring/CfgHelper.sol";
import { PoolsCleanupCfg } from "script/upgrades/PoolRestructuring/PoolsCleanupCfg.sol";
import { TradingLimitsCfg } from "script/upgrades/PoolRestructuring/TradingLimitsCfg.sol";
import { ValueDeltaBreakerCfg } from "script/upgrades/PoolRestructuring/ValueDeltaBreakerCfg.sol";

interface IBrokerWithCasts {
  function tradingLimitsConfig(bytes32 id) external view returns (TradingLimits.Config memory);
}

contract PoolRestructuringChecks is GovernanceScript, Test {
  using TradingLimits for TradingLimits.Config;
  using Contracts for Contracts.Cache;

  uint256 private constant PRE_EXISTING_POOLS = 24;

  CfgHelper private cfgHelper;
  PoolsCleanupCfg private poolsCleanupCfg;
  TradingLimitsCfg private tradingLimitsCfg;
  ValueDeltaBreakerCfg private valueDeltaBreakerCfg;

  address private brokerProxy;
  address private biPoolManagerProxy;
  address private valueDeltaBreaker;
  address private breakerBox;
  address private medianDeltaBreaker;

  address private constantSum;

  mapping(address => bytes32) public referenceRateFeedIDToExchangeId;

  function prepare() public {
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts");
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.loadSilent("eXOF-00-Create-Proxies", "latest");

    cfgHelper = new CfgHelper();
    cfgHelper.load();

    poolsCleanupCfg = new PoolsCleanupCfg(cfgHelper);
    tradingLimitsCfg = new TradingLimitsCfg(cfgHelper);
    valueDeltaBreakerCfg = new ValueDeltaBreakerCfg();

    brokerProxy = contracts.deployed("BrokerProxy");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    valueDeltaBreaker = contracts.deployed("ValueDeltaBreaker");
    breakerBox = contracts.deployed("BreakerBox");
    medianDeltaBreaker = contracts.deployed("MedianDeltaBreaker");

    constantSum = contracts.deployed("ConstantSumPricingModule");

    setReferenceRateFeedIDToExchangeId();
  }

  function run() public {
    prepare();

    console2.log("\n");

    checkPoolsAreDeletedAndRecreatedWithNewSpread();
    checkValueDeltaBreakersThresholds();
    checkTradingLimits();

    NewPoolsCfg.NewPools memory newPoolsCfg = NewPoolsCfg.get(contracts);
    verifyExchanges(newPoolsCfg.pools);

    verifyCircuitBreaker(newPoolsCfg.rateFeedsConfig);

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

      if (poolsCleanupCfg.shouldBeDeleted(exchange)) {
        // If this pool was supposed to be deleted but it's still there, it means it was part of the ones that
        // had to be re-created with a new spread.
        require(
          poolsCleanupCfg.shouldRecreateWithNewSpread(exchange),
          "❌ Failed to delete pool without a newly proposed spread"
        );

        (, FixidityLib.Fraction memory targetSpread) = poolsCleanupCfg.getCurrentAndTargetSpread(exchange);
        require(FixidityLib.equals(exchange.config.spread, targetSpread), "❌ Re-created pool with wrong spread");

        console2.log(
          "✅ Re-created pool %s with new spread",
          cfgHelper.getFeedName(exchange.config.referenceRateFeedID)
        );
      }
    }

    uint256 poolsDeletedButNotRecreated = poolsCleanupCfg.poolsToDelete().length -
      poolsCleanupCfg.spreadOverrides().length;
    console2.log("✅ Other non-USD pools (%d) were permanently deleted\n", poolsDeletedButNotRecreated);
  }

  function checkValueDeltaBreakersThresholds() internal {
    console2.log("====🔍 Checking updated ValueDeltaBreaker thresholds... ====");

    ValueDeltaBreakerCfg.Override[] memory overrides = valueDeltaBreakerCfg.valueDeltaBreakerOverrides();
    for (uint256 i = 0; i < overrides.length; i++) {
      uint256 currentThreshold = ValueDeltaBreaker(valueDeltaBreaker).rateChangeThreshold(overrides[i].rateFeedId);
      require(currentThreshold == overrides[i].targetThreshold, "❌ ValueDeltaBreaker threshold not updated");

      console2.log("✅ Threshold updated for %s feed", cfgHelper.getFeedName(overrides[i].rateFeedId));
    }
  }

  function verifyExchanges(Config.Pool[] memory poolConfigs) internal {
    console2.log("===🔍 Verifying exchanges ===");

    NewPoolsCfg.NewPools memory newPoolsCfg = NewPoolsCfg.get(contracts);

    bytes32[] memory exchanges = IBiPoolManager(biPoolManagerProxy).getExchangeIds();
    // check configured pools against the config
    require(
      exchanges.length ==
        PRE_EXISTING_POOLS -
          poolsCleanupCfg.poolsToDelete().length + // pools that were deleted
          poolsCleanupCfg.spreadOverrides().length + // pools that were re-created with a new spread
          newPoolsCfg.pools.length, // 3 new cUSD pools
      "Number of expected pools does not match the number of deployed pools."
    );

    for (uint256 i = 0; i < newPoolsCfg.pools.length; i++) {
      bytes32 exchangeId = getExchangeId(
        newPoolsCfg.pools[i].asset0,
        newPoolsCfg.pools[i].asset1,
        newPoolsCfg.pools[i].isConstantSum
      );

      verifyPoolExchange(exchangeId, newPoolsCfg.pools[i]);
      verifyPoolConfig(exchangeId, newPoolsCfg.pools[i]);
      verifyTradingLimits(exchangeId, newPoolsCfg.pools[i]);
    }
    console2.log("\n");
  }

  function verifyCircuitBreaker(Config.RateFeed[] memory rateFeedConfigs) internal view {
    console2.log("===🔍 Checking circuit breaker ===");

    for (uint256 i = 0; i < rateFeedConfigs.length; i++) {
      verifyBreakersAreEnabled(rateFeedConfigs[i]);
      verifyMedianDeltaBreaker(rateFeedConfigs[i]);
    }
  }

  function verifyPoolExchange(bytes32 exchangeId, Config.Pool memory expectedPoolConfig) internal view {
    IBiPoolManager.PoolExchange memory deployedPool = IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);

    // verify asset0 of the deployed pool against the config
    if (deployedPool.asset0 != expectedPoolConfig.asset0) {
      console2.log(
        "The asset0 of deployed pool: %s does not match the expected asset0: %s.",
        deployedPool.asset0,
        expectedPoolConfig.asset0
      );
      revert("asset0 of pool does not match the expected asset0. See logs.");
    }

    // verify asset1 of the deployed pool against the config
    if (deployedPool.asset1 != expectedPoolConfig.asset1) {
      console2.log(
        "The asset1 of deployed pool: %s does not match the expected asset1: %s.",
        deployedPool.asset1,
        expectedPoolConfig.asset1
      );
      revert("asset1 of pool does not match the expected asset1. See logs.");
    }

    // Ensure the pricing module is the constant product
    if (address(deployedPool.pricingModule) != constantSum) {
      console2.log(
        "The pricing module of deployed pool: %s does not match the expected pricing module: %s.",
        address(deployedPool.pricingModule),
        constantSum
      );
      revert("pricing module of pool does not match the expected pricing module. See logs.");
    }

    console2.log(
      "🟢 PoolExchange for %s has correct assets and pricing 🤘🏼",
      cfgHelper.getFeedName(deployedPool.config.referenceRateFeedID)
    );
  }

  function verifyPoolConfig(bytes32 exchangeId, Config.Pool memory expectedPoolConfig) internal view {
    IBiPoolManager.PoolExchange memory deployedPool = IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);

    // if (deployedPool.config.spread.unwrap() != expectedPoolConfig.spread.unwrap()) {
    //   console2.log(
    //     "The spread of deployed pool: %s does not match the expected spread: %s.",
    //     deployedPool.config.spread.unwrap(),
    //     expectedPoolConfig.spread.unwrap()
    //   );
    //   revert("spread of pool does not match the expected spread. See logs.");
    // }

    // console2.log("Expected spread: %s", expectedPoolConfig.spread.unwrap());
    // console2.log("Deployed spread: %s", deployedPool.config.spread.unwrap());
    // if (FixidityLib.equals(deployedPool.config.spread, expectedPoolConfig.spread)) {
    //   console2.log("✅ Spread is correct");
    // } else {
    //   console2.log("❌ Spread is incorrect");
    // }

    if (deployedPool.config.referenceRateFeedID != expectedPoolConfig.referenceRateFeedID) {
      console2.log(
        "The referenceRateFeedID of deployed pool: %s does not match the expected referenceRateFeedID: %s.",
        deployedPool.config.referenceRateFeedID,
        expectedPoolConfig.referenceRateFeedID
      );
      revert("referenceRateFeedID of pool does not match the expected referenceRateFeedID. See logs.");
    }

    if (deployedPool.config.minimumReports != expectedPoolConfig.minimumReports) {
      console2.log(
        "The minimumReports of deployed pool: %s does not match the expected minimumReports: %s.",
        deployedPool.config.minimumReports,
        expectedPoolConfig.minimumReports
      );
      revert("minimumReports of pool does not match the expected minimumReports. See logs.");
    }

    if (deployedPool.config.referenceRateResetFrequency != expectedPoolConfig.referenceRateResetFrequency) {
      console2.log(
        "The referenceRateResetFrequency of deployed pool: %s does not match the expected: %s.",
        deployedPool.config.referenceRateResetFrequency,
        expectedPoolConfig.referenceRateResetFrequency
      );
      revert("referenceRateResetFrequency of pool does not match the expected referenceRateResetFrequency. See logs.");
    }

    if (deployedPool.config.stablePoolResetSize != expectedPoolConfig.stablePoolResetSize) {
      console2.log(
        "The stablePoolResetSize of deployed pool: %s does not match the expected stablePoolResetSize: %s.",
        deployedPool.config.stablePoolResetSize,
        expectedPoolConfig.stablePoolResetSize
      );
      revert("stablePoolResetSize of pool does not match the expected stablePoolResetSize. See logs.");
    }

    console2.log("🟢 %s config is correct🤘🏼", cfgHelper.getFeedName(deployedPool.config.referenceRateFeedID));
  }

  function verifyTradingLimits(bytes32 exchangeId, Config.Pool memory expectedPoolConfig) internal view {
    IBrokerWithCasts _broker = IBrokerWithCasts(address(brokerProxy));

    IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);

    bytes32 asset0LimitId = exchangeId ^ bytes32(uint256(uint160(pool.asset0)));
    TradingLimits.Config memory asset0ActualLimit = _broker.tradingLimitsConfig(asset0LimitId);

    bytes32 asset1LimitId = exchangeId ^ bytes32(uint256(uint160(pool.asset1)));
    TradingLimits.Config memory asset1ActualLimit = _broker.tradingLimitsConfig(asset1LimitId);

    checkTradingLimt(expectedPoolConfig.asset0limits, asset0ActualLimit);
    checkTradingLimt(expectedPoolConfig.asset1limits, asset1ActualLimit);

    console2.log("🟢 Trading limits set for %s 🔒\n", cfgHelper.getFeedName(pool.config.referenceRateFeedID));
  }

  function verifyBreakersAreEnabled(Config.RateFeed memory expectedRateFeedConfig) internal view {
    // verify that MedianDeltaBreaker is enabled
    if (expectedRateFeedConfig.medianDeltaBreaker0.enabled) {
      bool medianDeltaEnabled = BreakerBox(breakerBox).isBreakerEnabled(
        medianDeltaBreaker,
        expectedRateFeedConfig.rateFeedID
      );
      if (!medianDeltaEnabled) {
        console2.log("MedianDeltaBreaker not enabled for rate feed %s", expectedRateFeedConfig.rateFeedID);
        revert("MedianDeltaBreaker not enabled for all rate feeds");
      }
    }
    console2.log(
      "🟢 Breakers enabled for the rate feed %s 🗳️",
      cfgHelper.getFeedName(expectedRateFeedConfig.rateFeedID)
    );
  }

  function verifyMedianDeltaBreaker(Config.RateFeed memory expectedRateFeedConfig) internal view {
    // verify that cooldown period, rate change threshold and smoothing factor were set correctly
    if (expectedRateFeedConfig.medianDeltaBreaker0.enabled) {
      // Get the actual values from the deployed median delta breaker contract
      uint256 cooldown = MedianDeltaBreaker(medianDeltaBreaker).getCooldown(expectedRateFeedConfig.rateFeedID);
      uint256 rateChangeThreshold = MedianDeltaBreaker(medianDeltaBreaker).rateChangeThreshold(
        expectedRateFeedConfig.rateFeedID
      );
      uint256 smoothingFactor = MedianDeltaBreaker(medianDeltaBreaker).getSmoothingFactor(
        expectedRateFeedConfig.rateFeedID
      );

      // verify cooldown period
      verifyCooldownTime(
        cooldown,
        expectedRateFeedConfig.medianDeltaBreaker0.cooldown,
        expectedRateFeedConfig.rateFeedID,
        false
      );

      // verify rate change threshold
      verifyRateChangeTheshold(
        rateChangeThreshold,
        expectedRateFeedConfig.medianDeltaBreaker0.threshold.unwrap(),
        expectedRateFeedConfig.rateFeedID,
        false
      );

      // verify smoothing factor
      if (smoothingFactor != expectedRateFeedConfig.medianDeltaBreaker0.smoothingFactor) {
        console2.log("expected: %s", expectedRateFeedConfig.medianDeltaBreaker0.smoothingFactor);
        console2.log("got:      %s", smoothingFactor);
        console2.log(
          "MedianDeltaBreaker smoothing factor not set correctly for the rate feed: %s",
          expectedRateFeedConfig.rateFeedID
        );
        revert("MedianDeltaBreaker smoothing factor not set correctly for all rate feeds");
      }
    }
    console2.log("🟢 MedianDeltaBreaker cooldown, rate change threshold and smoothing factor set correctly 🔒\r\n");
  }

  function verifyRateChangeTheshold(
    uint256 currentThreshold,
    uint256 expectedThreshold,
    address rateFeedID,
    bool isValueDeltaBreaker
  ) internal view {
    if (currentThreshold != expectedThreshold) {
      if (isValueDeltaBreaker) {
        console2.log("ValueDeltaBreaker rate change threshold not set correctly for rate feed with id %s", rateFeedID);
        revert("ValueDeltaBreaker rate change threshold not set correctly for rate feed");
      }
      console2.log("MedianDeltaBreaker rate change threshold not set correctly for rate feed %s", rateFeedID);
      revert("MedianDeltaBreaker rate change threshold not set correctly for all rate feeds");
    }
  }

  function verifyCooldownTime(
    uint256 currentCoolDown,
    uint256 expectedCoolDown,
    address rateFeedID,
    bool isValueDeltaBreaker
  ) internal view {
    if (currentCoolDown != expectedCoolDown) {
      console2.log("currentCoolDown: %s", currentCoolDown);
      console2.log("expectedCoolDown: %s", expectedCoolDown);
      if (isValueDeltaBreaker) {
        console2.log("ValueDeltaBreaker cooldown not set correctly for rate feed with id %s", rateFeedID);
        revert("ValueDeltaBreaker cooldown not set correctly for rate feed");
      }
      console2.log("MedianDeltaBreaker cooldown not set correctly for rate feed %s", rateFeedID);
      revert("MedianDeltaBreaker cooldown not set correctly for all rate feeds");
    }
  }

  function checkTradingLimits() internal {
    console2.log("====🔍 Checking updated trading limits... ====");

    IBrokerWithCasts _broker = IBrokerWithCasts(brokerProxy);
    TradingLimitsCfg.Override[] memory overrides = tradingLimitsCfg.tradingLimitsOverrides();

    for (uint256 i = 0; i < overrides.length; i++) {
      bytes32 exchangeId = referenceRateFeedIDToExchangeId[overrides[i].referenceRateFeedID];

      bytes32 asset0LimitId = exchangeId ^ bytes32(uint256(uint160(overrides[i].asset0)));
      TradingLimits.Config memory asset0ActualLimit = _broker.tradingLimitsConfig(asset0LimitId);

      bytes32 asset1LimitId = exchangeId ^ bytes32(uint256(uint160(overrides[i].asset1)));
      TradingLimits.Config memory asset1ActualLimit = _broker.tradingLimitsConfig(asset1LimitId);

      checkTradingLimt(overrides[i].asset0Config, asset0ActualLimit);
      checkTradingLimt(overrides[i].asset1Config, asset1ActualLimit);

      console2.log("✅ Trading limits updated for %s feed", cfgHelper.getFeedName(overrides[i].referenceRateFeedID));
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
