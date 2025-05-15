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
import { IBiPoolManager } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";

import { ISortedOracles } from "./OracleMigration.sol";
import { OracleMigrationConfig } from "./Config.sol";

interface IMockRedstoneAdapter {
  function relay() external;
}

contract OracleMigrationChecks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  OracleMigrationConfig private config;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;

  address private redstoneAdapter;
  address private biPoolManagerProxy;

  function prepare() public {
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.load("cKES-00-Create-Proxies", "latest");
    contracts.load("eXOF-00-Create-Proxies", "latest");
    contracts.loadSilent("MU01-00-Create-Proxies", "latest"); // BrokerProxy & BiPoolProxy
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest"); // Pricing Modules
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts", "latest");

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
    // assert_redstoneCanReport();
    // assert_relayersReport();
    checkExchangesAreProperlyConfigured();
    // printWhitelisted();
    console2.log("✅ All checks passed\n");
  }

  // function assert_redstoneCanReport() internal {
  //   vm.startPrank(0xdcbaC3971fd86f7bc70FA25E4C434041efdBb27e);

  //   address redstoneAdapter = 0x854A01c7b8431bF23b707b134EF3f99fe5C48CED;
  //   IMockRedstoneAdapter adapter = IMockRedstoneAdapter(redstoneAdapter);

  //   adapter.relay();
  //   vm.stopPrank();

  //   console2.log("✅ Redstone can report\n");
  // }

  // function printWhitelisted() internal {
  //   address[] memory feedsToMigrate = config.redstonePoweredFeeds();
  //   for (uint i = 0; i < feedsToMigrate.length; i++) {
  //     address rateFeedIdentifier = feedsToMigrate[i];
  //     address[] memory whitelisted = sortedOracles.getOracles(rateFeedIdentifier);
  //     console2.log("feed %s", rateFeedIdentifier);
  //     for (uint j = 0; j < whitelisted.length; j++) {
  //       console2.log("\twhitelisted %s", whitelisted[j]);
  //     }
  //     console2.log("\n\n");
  //   }
  // }

  function assert_relayersReport() internal {
    console2.log("====🔍 Checking if all relayers can report...====");
    address[] memory feedsToMigrate = config.redstonePoweredFeeds();
    for (uint i = 0; i < feedsToMigrate.length; i++) {
      address rateFeedIdentifier = feedsToMigrate[i];
      address relayerAddress = relayerFactory.getRelayer(rateFeedIdentifier);
      IChainlinkRelayer relayer = IChainlinkRelayer(relayerAddress);
      require(
        relayer.rateFeedId() == rateFeedIdentifier,
        "❌ mismatch between the actual relayer feed and expected feed"
      );

      relayer.relay();
      (uint256 rate, ) = sortedOracles.medianRate(relayer.rateFeedId());
      emit log_named_decimal_uint(relayer.rateFeedDescription(), rate, 24);

      console2.log("🚀 Relayer %s relayed to feed %s successfully", relayerAddress, relayer.rateFeedId());
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
          console2.log("❌ Expected redstone adapter to be whitelisted on feed %s", identifier);
          require(
            whitelisted[0] == redstoneAdapter,
            "❌ Expected redstone adapter to be whitelisted on redstone powered feed"
          );
        } else {
          console2.log("✅ Redstone adapter is whitelisted on feed %s", identifier);
        }
      } else {
        address relayer = relayerFactory.getRelayer(identifier);
        if (whitelisted[0] != relayer) {
          console2.log("❌ Expected chainlink relayer to be whitelisted on feed %s", identifier);
          require(
            whitelisted[0] == relayer,
            "❌ Expected chainlink relayer to be whitelisted on chainlink powered feed"
          );
        } else {
          console2.log("✅ Chainlink relayer is whitelisted on feed %s", identifier);
        }
      }

      uint256 actualExpiry = sortedOracles.tokenReportExpirySeconds(identifier);
      if (actualExpiry != expectedTokenExpiry) {
        console2.log("❌ Expected token report expiry to be %d seconds on feed %s", expectedTokenExpiry, identifier);
        require(actualExpiry == expectedTokenExpiry, "❌ Expected token report expiry to be 6 minutes");
      }
    }

    console2.log("✅ All %d feeds were configured correctly\n", feedsToMigrate.length);
  }

  function checkExchangesAreProperlyConfigured() internal {
    console2.log("====🔍 Checking if all exchanges are properly configured...====");
    IBiPoolManager biPoolManager = IBiPoolManager(biPoolManagerProxy);
    bytes32[] memory exchangeIds = biPoolManager.getExchangeIds();

    for (uint256 i = exchangeIds.length - 1; i >= 0; i--) {
      bytes32 exchangeId = exchangeIds[i];
      IBiPoolManager.PoolExchange memory exchange = biPoolManager.getPoolExchange(exchangeId);

      require(exchange.config.minimumReports == 1, "❌ Expected minimum reports to be 1");
      require(exchange.config.referenceRateResetFrequency == 6 minutes, "❌ Expected reset frequency to be 6 minutes");
      require(exchange.bucket0 > 0, "❌ Expected bucket0 to be > 0");
      require(exchange.bucket1 > 0, "❌ Expected bucket1 to be > 0");

      if (i == 0) break;
    }

    console2.log("✅ All exchanges are properly configured\n");
  }
}
