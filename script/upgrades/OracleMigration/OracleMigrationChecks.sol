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
    // contracts.load("cKES-00-Create-Proxies", "latest");
    // contracts.load("eXOF-00-Create-Proxies", "latest");
    contracts.loadSilent("MU01-00-Create-Proxies", "latest");
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    // contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest"); // Pricing Modules
    // contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts", "latest");

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

    assert_sortedOraclesIsCorrectlyConfigured();
    assert_additionalFeedsAreWhitelisted();
    assert_relayersReport();
    checkExchangesAreProperlyConfigured();
    console2.log("✅ All checks passed\n");
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

      if (block.timestamp - updatedAt > 5 minutes) {
        console2.log(
          "\t⚠️ Aggregator %s has a stale timestamp (%d seconds), skipping",
          aggregator.description(),
          block.timestamp - updatedAt
        );
        return true;
      }
    }

    uint256 lastReportTs = sortedOracles.medianTimestamp(relayer.rateFeedId());
    if (lastReportTs > newestAggregatorTs) {
      console2.log(
        "TimestampNotNew() condition met (on-chain=%d, relayer=%d), skipping",
        lastReportTs,
        newestAggregatorTs
      );
      return true;
    }

    return false;
  }

  function assert_relayersReport() internal {
    console2.log("====🔍 Checking if all relayers can report...====");
    address[] memory feedsToMigrate = config.chainlinkPoweredFeeds();
    for (uint i = 0; i < feedsToMigrate.length; i++) {
      // for (uint i = 0; i < 1; i++) {
      address rateFeedIdentifier = feedsToMigrate[i];
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
        "🚀 Relayer %s relayed to feed %s successfully",
        relayerAddress,
        config.getFeedName(relayer.rateFeedId())
      );
    }
    console2.log("✅ All relayers can report\n");
  }

  function assert_sortedOraclesIsCorrectlyConfigured() internal {
    console2.log("====🔍 Checking if sortedOracles is correctly configured...====");
    uint256 expectedTokenExpiry = 6 minutes;

    // address[] memory feedsToMigrate = config.redstonePoweredFeeds();
    address[] memory feedsToMigrate = config.feedsToMigrate();

    for (uint i = 0; i < feedsToMigrate.length; i++) {
      address identifier = feedsToMigrate[i];
      address[] memory whitelisted = sortedOracles.getOracles(identifier);

      require(whitelisted.length == 1, "❌ Expected exactly 1 oracle to be whitelisted");

      if (config.isRedstonePowered(identifier)) {
        if (whitelisted[0] != redstoneAdapter) {
          console2.log("❌ Expected redstone adapter to be whitelisted on feed %s", config.getFeedName(identifier));
          require(
            whitelisted[0] == redstoneAdapter,
            "❌ Expected redstone adapter to be whitelisted on redstone powered feed"
          );
        } else {
          console2.log("✅ Redstone adapter is whitelisted on feed %s", config.getFeedName(identifier));
        }
      } else {
        address relayer = relayerFactory.getRelayer(identifier);
        if (whitelisted[0] != relayer) {
          console2.log("❌ Expected chainlink relayer to be whitelisted on feed %s", config.getFeedName(identifier));
          require(
            whitelisted[0] == relayer,
            "❌ Expected chainlink relayer to be whitelisted on chainlink powered feed"
          );
        } else {
          console2.log("✅ Chainlink relayer is whitelisted on feed %s", config.getFeedName(identifier));
        }
      }

      uint256 actualExpiry = sortedOracles.tokenReportExpirySeconds(identifier);
      if (actualExpiry != expectedTokenExpiry) {
        console2.log(
          "❌ Expected token report expiry to be %d seconds on feed %s",
          expectedTokenExpiry,
          config.getFeedName(identifier)
        );
        require(actualExpiry == expectedTokenExpiry, "❌ Expected token report expiry to be 6 minutes");
      }
    }

    console2.log("🤑 All %d feeds were configured correctly\n", feedsToMigrate.length);
  }

  function assert_additionalFeedsAreWhitelisted() internal {
    console2.log("====🔍 Checking if additional feeds are whitelisted...====");
    address[] memory additionalFeeds = config.additionalRelayersToWhitelist();
    for (uint i = 0; i < additionalFeeds.length; i++) {
      address identifier = additionalFeeds[i];
      address[] memory whitelisted = sortedOracles.getOracles(identifier);
      require(whitelisted.length == 1, "❌ Expected exactly 1 oracle to be whitelisted");

      address relayerAddr = relayerFactory.getRelayer(identifier);
      require(whitelisted[0] == relayerAddr, "❌ Expected chainlink relayer to be whitelisted on additional feed");

      IChainlinkRelayer relayer = IChainlinkRelayer(relayerAddr);
      console2.log(
        "✅ Relayer %s(%s) is whitelisted on feed %s",
        relayerAddr,
        relayer.rateFeedDescription(),
        identifier
      );
    }
    console2.log("💪 All additional feeds are whitelisted\n");
  }

  function checkExchangesAreProperlyConfigured() internal {
    console2.log("====🔍 Checking if all exchanges are properly configured...====");
    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);
    bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();

    for (uint256 i = 0; i < exchangeIds.length; i++) {
      bytes32 exchangeId = exchangeIds[i];
      IBiPoolManager.PoolExchange memory exchange = biPoolManager.getPoolExchange(exchangeId);

      require(exchange.config.minimumReports == 1, "❌ Expected minimum reports to be 1");
      if (exchange.config.referenceRateResetFrequency != 6 minutes) {
        console2.log(
          "❌ Expected reset frequency to be 6 minutes on %s exchange %s",
          config.getFeedName(exchange.config.referenceRateFeedID),
          exchange.config.referenceRateFeedID
        );
        console2.log("Instead got %s", exchange.config.referenceRateResetFrequency);
      }
      require(exchange.config.referenceRateResetFrequency == 6 minutes, "❌ Expected reset frequency to be 6 minutes");
      require(exchange.bucket0 > 0, "❌ Expected bucket0 to be > 0");
      require(exchange.bucket1 > 0, "❌ Expected bucket1 to be > 0");

      if (config.hasNewSpread(exchange)) {
        (FixidityLib.Fraction memory currentSpread, FixidityLib.Fraction memory targetSpread) = config
          .getCurrentAndTargetSpread(exchange);

        if (FixidityLib.equals(exchange.config.spread, targetSpread)) {
          console2.log(
            "✅ Spread was correctly overwritten on %s exchange",
            config.getFeedName(exchange.config.referenceRateFeedID)
          );
        } else {
          require(FixidityLib.equals(exchange.config.spread, targetSpread), "❌ Expected spread to be overridden");
        }
      }

      if (config.hasNewResetSize(exchange)) {
        (, uint256 targetResetSize) = config.getCurrentAndTargetResetSizes(exchange);
        if (exchange.config.stablePoolResetSize == targetResetSize) {
          console2.log(
            "✅ StablePoolResetSize was correctly overwritten on %s exchange",
            config.getFeedName(exchange.config.referenceRateFeedID)
          );
        } else {
          require(
            exchange.config.stablePoolResetSize == targetResetSize,
            "❌ Expected stable pool reset size to be overwritten"
          );
        }
      }
    }

    console2.log("✨ All %d exchanges are properly configured\n", exchangeIds.length);
  }
}
