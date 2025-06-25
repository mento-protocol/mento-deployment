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

    setExchangeIds();
  }

  function run() public {
    prepare();
    console2.log("\n");

    verifyPoolsWeredDeletedAndRecreated();
    verifyValueDeltaBreakersThresholds();
    verifyUpdatedTradingLimits();

    NewPoolsCfg.NewPools memory newPoolsCfg = NewPoolsCfg.get(contracts);
    verifyNewPools();
    verifyCircuitBreaker(newPoolsCfg.rateFeedsConfig);
  }

  function setExchangeIds() public {
    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);
    bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();

    for (uint256 i = 0; i < exchangeIds.length; i++) {
      bytes32 exchangeId = exchangeIds[i];
      IBiPoolManager.PoolExchange memory currentExchange = biPoolManager.getPoolExchange(exchangeId);

      referenceRateFeedIDToExchangeId[currentExchange.config.referenceRateFeedID] = exchangeId;
    }
  }

  function verifyPoolsWeredDeletedAndRecreated() internal {
    console2.log("====🔍 Verifying pools were deleted and recreated... ====");

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
          "✅ Re-created %s pool with new spread",
          cfgHelper.getFeedName(exchange.config.referenceRateFeedID)
        );
      }
    }

    uint256 poolsDeletedButNotRecreated = poolsCleanupCfg.poolsToDelete().length -
      poolsCleanupCfg.spreadOverrides().length;
    console2.log("✅ Other non-USD pools (%d) were permanently deleted\n", poolsDeletedButNotRecreated);
  }

  function verifyValueDeltaBreakersThresholds() internal {
    console2.log("====🔍 Verifying ValueDeltaBreaker thresholds... ====");

    ValueDeltaBreakerCfg.Override[] memory overrides = valueDeltaBreakerCfg.valueDeltaBreakerOverrides();
    for (uint256 i = 0; i < overrides.length; i++) {
      uint256 currentThreshold = ValueDeltaBreaker(valueDeltaBreaker).rateChangeThreshold(overrides[i].rateFeedId);
      require(currentThreshold == overrides[i].targetThreshold, "❌ ValueDeltaBreaker threshold not updated");

      console2.log("✅ Threshold updated for %s feed", cfgHelper.getFeedName(overrides[i].rateFeedId));
    }
    console2.log("\n");
  }

  function verifyNewPools() internal {
    console2.log("===🔍 Verifying additional created pools ===");

    NewPoolsCfg.NewPools memory newPoolsCfg = NewPoolsCfg.get(contracts);

    bytes32[] memory exchanges = IBiPoolManager(biPoolManagerProxy).getExchangeIds();
    require(
      exchanges.length ==
        PRE_EXISTING_POOLS -
          poolsCleanupCfg.poolsToDelete().length + // pools that were deleted
          poolsCleanupCfg.spreadOverrides().length + // pools that were re-created with a new spread
          newPoolsCfg.pools.length, // 3 additional cUSD pools
      "❌ number of pools mismatch"
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

      console2.log(
        "🟢 %s pool has the expected params and trading limits",
        cfgHelper.getFeedName(newPoolsCfg.pools[i].referenceRateFeedID)
      );
    }
    console2.log("\n");
  }

  function verifyCircuitBreaker(Config.RateFeed[] memory rateFeedConfigs) internal view {
    console2.log("===🔍 Verifying circuit breaker on new pools ===");

    for (uint256 i = 0; i < rateFeedConfigs.length; i++) {
      verifyBreakersAreEnabled(rateFeedConfigs[i]);
      verifyMedianDeltaBreaker(rateFeedConfigs[i]);
    }
  }

  function verifyPoolExchange(bytes32 exchangeId, Config.Pool memory expectedPoolConfig) internal view {
    IBiPoolManager.PoolExchange memory deployedPool = IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);

    require(deployedPool.asset0 == expectedPoolConfig.asset0, "❌ asset0 mismatch");
    require(deployedPool.asset1 == expectedPoolConfig.asset1, "❌ asset1 mismatch");
    require(address(deployedPool.pricingModule) == constantSum, "❌ pricing module mismatch");
  }

  function verifyPoolConfig(bytes32 exchangeId, Config.Pool memory expectedPoolConfig) internal view {
    IBiPoolManager.PoolExchange memory deployedPool = IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);

    require(
      deployedPool.config.referenceRateFeedID == expectedPoolConfig.referenceRateFeedID,
      "❌ rateFeedId mismatch"
    );
    require(deployedPool.config.minimumReports == expectedPoolConfig.minimumReports, "❌ minimumReports mismatch");
    require(
      deployedPool.config.referenceRateResetFrequency == expectedPoolConfig.referenceRateResetFrequency,
      "❌ referenceRateResetFrequency mismatch"
    );
    require(
      deployedPool.config.stablePoolResetSize == expectedPoolConfig.stablePoolResetSize,
      "❌ stablePoolResetSize mismatch"
    );
  }

  function verifyTradingLimits(bytes32 exchangeId, Config.Pool memory expectedPoolConfig) internal view {
    IBrokerWithCasts _broker = IBrokerWithCasts(address(brokerProxy));

    IBiPoolManager.PoolExchange memory pool = IBiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);

    bytes32 asset0LimitId = exchangeId ^ bytes32(uint256(uint160(pool.asset0)));
    TradingLimits.Config memory asset0ActualLimit = _broker.tradingLimitsConfig(asset0LimitId);

    bytes32 asset1LimitId = exchangeId ^ bytes32(uint256(uint160(pool.asset1)));
    TradingLimits.Config memory asset1ActualLimit = _broker.tradingLimitsConfig(asset1LimitId);

    compareTradingLimits(expectedPoolConfig.asset0limits, asset0ActualLimit);
    compareTradingLimits(expectedPoolConfig.asset1limits, asset1ActualLimit);
  }

  function verifyBreakersAreEnabled(Config.RateFeed memory expectedRateFeedConfig) internal view {
    if (expectedRateFeedConfig.medianDeltaBreaker0.enabled) {
      bool medianDeltaEnabled = BreakerBox(breakerBox).isBreakerEnabled(
        medianDeltaBreaker,
        expectedRateFeedConfig.rateFeedID
      );
      require(medianDeltaEnabled, "❌ MedianDeltaBreaker not enabled");
    }
    console2.log("🟢 MedianDeltaBreaker enabled on %s pool", cfgHelper.getFeedName(expectedRateFeedConfig.rateFeedID));
  }

  function verifyMedianDeltaBreaker(Config.RateFeed memory expectedRateFeedConfig) internal view {
    uint256 actualCooldown = MedianDeltaBreaker(medianDeltaBreaker).getCooldown(expectedRateFeedConfig.rateFeedID);
    uint256 actualRateChangeThreshold = MedianDeltaBreaker(medianDeltaBreaker).rateChangeThreshold(
      expectedRateFeedConfig.rateFeedID
    );
    uint256 actualSmoothingFactor = MedianDeltaBreaker(medianDeltaBreaker).getSmoothingFactor(
      expectedRateFeedConfig.rateFeedID
    );

    require(actualCooldown == expectedRateFeedConfig.medianDeltaBreaker0.cooldown, "❌ cooldown mismatch");
    require(
      actualRateChangeThreshold == expectedRateFeedConfig.medianDeltaBreaker0.threshold.unwrap(),
      "❌ rate change threshold mismatch"
    );
    require(
      actualSmoothingFactor == expectedRateFeedConfig.medianDeltaBreaker0.smoothingFactor,
      "❌ smoothing factor mismatch"
    );

    console2.log(
      "🟢 MedianDeltaBreaker cfg on %s was set correctly",
      cfgHelper.getFeedName(expectedRateFeedConfig.rateFeedID)
    );

    if (expectedRateFeedConfig.dependentRateFeeds.length > 0) {
      require(
        expectedRateFeedConfig.rateFeedID == Config.rateFeedID("relayed:XOFUSD"),
        "❌ unexpected feed with dependency"
      );
      require(expectedRateFeedConfig.dependentRateFeeds.length == 1, "❌ expected XOF/USD to have a single dependency");

      address dependency = BreakerBox(breakerBox).rateFeedDependencies(expectedRateFeedConfig.rateFeedID, 0);
      require(dependency == expectedRateFeedConfig.dependentRateFeeds[0], "❌ dependent rate feed mismatch");

      console2.log(
        "🟢 %s has the expected dependent rate feed",
        cfgHelper.getFeedName(expectedRateFeedConfig.rateFeedID)
      );
    }
  }

  function verifyUpdatedTradingLimits() internal {
    console2.log("====🔍 Verifying updated trading limits... ====");

    IBrokerWithCasts _broker = IBrokerWithCasts(brokerProxy);

    TradingLimitsCfg.Override[] memory overrides = tradingLimitsCfg.tradingLimitsOverrides();
    for (uint256 i = 0; i < overrides.length; i++) {
      bytes32 exchangeId = referenceRateFeedIDToExchangeId[overrides[i].referenceRateFeedID];

      bytes32 asset0LimitId = exchangeId ^ bytes32(uint256(uint160(overrides[i].asset0)));
      TradingLimits.Config memory asset0ActualLimit = _broker.tradingLimitsConfig(asset0LimitId);

      bytes32 asset1LimitId = exchangeId ^ bytes32(uint256(uint160(overrides[i].asset1)));
      TradingLimits.Config memory asset1ActualLimit = _broker.tradingLimitsConfig(asset1LimitId);

      compareTradingLimits(overrides[i].asset0Config, asset0ActualLimit);
      compareTradingLimits(overrides[i].asset1Config, asset1ActualLimit);

      console2.log("✅ Trading limits updated for %s feed", cfgHelper.getFeedName(overrides[i].referenceRateFeedID));
    }
    console2.log("\n");
  }

  function compareTradingLimits(
    Config.TradingLimit memory expectedTradingLimit,
    TradingLimits.Config memory actualTradingLimit
  ) internal view {
    require(expectedTradingLimit.limit0 == actualTradingLimit.limit0, "❌ limit0 mismatch");
    require(expectedTradingLimit.limit1 == actualTradingLimit.limit1, "❌ limit1 mismatch");
    require(expectedTradingLimit.limitGlobal == actualTradingLimit.limitGlobal, "❌ limitGlobal mismatch");
    require(expectedTradingLimit.timeStep0 == actualTradingLimit.timestep0, "❌ timestep0 mismatch");
    require(expectedTradingLimit.timeStep1 == actualTradingLimit.timestep1, "❌ timestep1 mismatch");
    require(Config.tradingLimitConfigToFlag(expectedTradingLimit) == actualTradingLimit.flags, "❌ flags mismatch");
  }
}
