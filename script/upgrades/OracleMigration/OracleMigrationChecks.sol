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

import { IChainlinkRelayerFactory } from "mento-core-2.5.0/interfaces/IChainlinkRelayerFactory.sol";
import { IChainlinkRelayer } from "mento-core-2.5.0/interfaces/IChainlinkRelayer.sol";
import { IBiPoolManager, FixidityLib } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";

import { ISortedOracles } from "./OracleMigration.sol";
import { OracleMigrationConfig } from "./Config.sol";

interface IMockRedstoneAdapter {
  function relay() external;
}

interface IChainlinkAggregator {
  function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);

  function latestTimestamp() external view returns (uint256);

  function description() external view returns (string memory);
}

contract OracleMigrationChecks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  OracleMigrationConfig private config;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;

  address private redstoneAdapter;
  address private biPoolManagerProxy;

  function prepare() public {
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");

    config = new OracleMigrationConfig();
    config.load();
    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    redstoneAdapter = contracts.dependency("RedstoneAdapter");
  }

  function run() public {
    prepare();
    console2.log("\n");

    checkSortedOraclesConfig();
    checkNewRelayersCanReport();
    checkExchangesAreProperlyConfigured();
    console2.log("✅ All checks passed\n");
  }

  function checkNewRelayersCanReport() internal {
    console2.log("====🔍 Checking if all relayers can report...====");

    address[] memory newRelayers = Arrays.merge(config.chainlinkPoweredFeeds(), config.additionalRelayersToWhitelist());
    for (uint i = 0; i < newRelayers.length; i++) {
      address rateFeedIdentifier = newRelayers[i];
      address relayerAddress = relayerFactory.getRelayer(rateFeedIdentifier);
      IChainlinkRelayer relayer = IChainlinkRelayer(relayerAddress);
      console2.log("🔍 Checking relayer %s", relayer.rateFeedDescription());

      require(
        relayer.rateFeedId() == rateFeedIdentifier,
        "❌ mismatch between the actual relayer feed and expected feed"
      );

      if (shouldSkipRelayAttempt(relayer)) {
        continue;
      }

      relayer.relay();
      (uint256 rate, ) = sortedOracles.medianRate(relayer.rateFeedId());
      emit log_named_decimal_uint(relayer.rateFeedDescription(), rate, 24);

      console2.log(
        "🚀 Relayer %s relayed to feed %s successfully\n",
        relayerAddress,
        config.getFeedName(relayer.rateFeedId())
      );
    }
  }

  function shouldSkipRelayAttempt(IChainlinkRelayer relayer) internal returns (bool) {
    IChainlinkRelayer.ChainlinkAggregator[] memory aggregators = relayer.getAggregators();
    uint256 newestAggregatorTs = 0;
    for (uint i = 0; i < aggregators.length; i++) {
      IChainlinkAggregator aggregator = IChainlinkAggregator(aggregators[i].aggregator);
      (, , , uint256 updatedAt, ) = aggregator.latestRoundData();

      if (updatedAt > newestAggregatorTs) {
        newestAggregatorTs = updatedAt;
      }

      // Sometimes relayers are not able to relay for two reasons:
      // 1) The aggregator staled and has not updated for a while
      // this happened on eXOF over the weekend
      if (block.timestamp - updatedAt > 5 minutes) {
        console2.log(
          "⚠️ Aggregator %s has a stale timestamp (%d seconds), skipping\n",
          aggregator.description(),
          block.timestamp - updatedAt
        );
        return true;
      }
    }

    // or 2) The on-chain median is newer than the aggregator, which throws a TimestampNotNew() error
    // this happened on USDT/USD since we already have oracles reporting on it
    uint256 lastReportTs = sortedOracles.medianTimestamp(relayer.rateFeedId());
    if (lastReportTs > newestAggregatorTs) {
      console2.log(
        "⚠️ Feed already has a more recent report on-chain (on-chain=%d, relayer=%d), skipping\n",
        lastReportTs,
        newestAggregatorTs
      );
      return true;
    }

    return false;
  }

  function checkSortedOraclesConfig() internal {
    console2.log("====🔍 Checking if sortedOracles is correctly configured...====");

    uint256 expectedTokenExpiry = 6 minutes;

    address[] memory allFeeds = Arrays.merge(config.feedsToMigrate(), config.additionalRelayersToWhitelist());
    for (uint i = 0; i < allFeeds.length; i++) {
      address identifier = allFeeds[i];
      address[] memory whitelisted = sortedOracles.getOracles(identifier);
      uint256 actualExpiry = sortedOracles.tokenReportExpirySeconds(identifier);

      require(whitelisted.length == 1, "❌ Expected exactly 1 oracle to be whitelisted");
      require(actualExpiry == expectedTokenExpiry, "❌ Expected token report expiry to be 6 minutes");

      if (config.isRedstonePowered(identifier)) {
        require(whitelisted[0] == redstoneAdapter, "❌ Expected redstone adapter to be whitelisted");
        console2.log("✅ Redstone adapter is whitelisted on feed %s", config.getFeedName(identifier));
      } else {
        address relayer = relayerFactory.getRelayer(identifier);
        require(whitelisted[0] == relayer, "❌ Expected chainlink relayer to be whitelisted");
        console2.log("✅ Chainlink relayer (%s) is whitelisted on feed %s", relayer, config.getFeedName(identifier));
      }
    }

    console2.log("🤑 All %d feeds were configured correctly\n", allFeeds.length);
  }

  function checkExchangesAreProperlyConfigured() internal {
    console2.log("====🔍 Checking if all exchanges are properly configured...====");

    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);

    bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();
    for (uint256 i = 0; i < exchangeIds.length; i++) {
      bytes32 exchangeId = exchangeIds[i];
      IBiPoolManager.PoolExchange memory exchange = biPoolManager.getPoolExchange(exchangeId);

      require(exchange.config.minimumReports == 1, "❌ Expected minimum reports to be 1");
      require(exchange.config.referenceRateResetFrequency == 6 minutes, "❌ Expected reset frequency to be 6 minutes");
      require(exchange.bucket0 > 0, "❌ Expected bucket0 to be > 0");
      require(exchange.bucket1 > 0, "❌ Expected bucket1 to be > 0");

      if (config.hasNewSpread(exchange)) {
        (FixidityLib.Fraction memory currentSpread, FixidityLib.Fraction memory targetSpread) = config
          .getCurrentAndTargetSpread(exchange);

        require(FixidityLib.equals(exchange.config.spread, targetSpread), "❌ Expected spread to be overridden");
        console2.log(
          "✅ Spread was overwritten on %s exchange",
          config.getFeedName(exchange.config.referenceRateFeedID)
        );
      }

      if (config.hasNewResetSize(exchange)) {
        (, uint256 targetResetSize) = config.getCurrentAndTargetResetSizes(exchange);
        require(
          exchange.config.stablePoolResetSize == targetResetSize,
          "❌ Expected stable pool reset size to be overwritten"
        );
        console2.log(
          "✅ StablePoolResetSize was correctly overwritten on %s exchange",
          config.getFeedName(exchange.config.referenceRateFeedID)
        );
      }
    }

    console2.log("✨ All %d exchanges are properly configured\n", exchangeIds.length);
  }
}
