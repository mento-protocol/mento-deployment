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

import { ISortedOracles } from "./SunsetOracles.sol";

interface IMockRedstoneAdapter {
  function relay() external;
}

contract SunsetOraclesChecks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;

  address private biPoolManagerProxy;
  address private cUSDProxy;
  address private cEURProxy;
  address private cBRLProxy;
  address payable private eXOFProxy;
  address payable private cKESProxy;

  address[] private feedsToMigrate;

  function prepare() public {
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.load("cKES-00-Create-Proxies", "latest");
    contracts.load("eXOF-00-Create-Proxies", "latest");
    contracts.loadSilent("MU01-00-Create-Proxies", "latest"); // BrokerProxy & BiPoolProxy
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest"); // Pricing Modules
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts", "latest");

    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));

    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    cUSDProxy = contracts.celoRegistry("StableToken");
    cEURProxy = contracts.celoRegistry("StableTokenEUR");
    cBRLProxy = contracts.celoRegistry("StableTokenBRL");
    eXOFProxy = contracts.deployed("StableTokenXOFProxy");
    cKESProxy = contracts.deployed("StableTokenKESProxy");
  }

  function addFeedsToMigrate() public {
    feedsToMigrate.push(cUSDProxy); // CELO/USD
    feedsToMigrate.push(cEURProxy); // CELO/EUR
    feedsToMigrate.push(cBRLProxy); // CELO/BRL
    feedsToMigrate.push(toRateFeedId("USDCUSD"));
    feedsToMigrate.push(toRateFeedId("USDCEUR"));
    feedsToMigrate.push(toRateFeedId("USDCBRL"));
    feedsToMigrate.push(toRateFeedId("EUROCEUR"));

    // feedsToMigrate.push(cUSDProxy); // CELO/USD
    // feedsToMigrate.push(cEURProxy); // CELO/EUR
    // feedsToMigrate.push(cBRLProxy); // CELO/BRL
    // feedsToMigrate.push(cKESProxy); // CELO/KES
    // feedsToMigrate.push(eXOFProxy); // CELO/XOF

    // feedsToMigrate.push(toRateFeedId("USDCUSD"));
    // feedsToMigrate.push(toRateFeedId("USDCEUR"));
    // feedsToMigrate.push(toRateFeedId("USDCBRL"));

    // feedsToMigrate.push(toRateFeedId("USDTUSD"));

    // feedsToMigrate.push(toRateFeedId("EUROCEUR"));
    // feedsToMigrate.push(toRateFeedId("EUROCXOF"));
    // feedsToMigrate.push(toRateFeedId("EURXOF"));

    // feedsToMigrate.push(toRateFeedId("KESUSD"));
    // feedsToMigrate.push(toRateFeedId("relayed:PHPUSD"));

    // ====== ALFAJORES
    // CELO/XXX
    // feedsToMigrate.push(toRateFeedId("relayed:CELOPHP"));
    // feedsToMigrate.push(toRateFeedId("relayed:CELOCOP"));
    // feedsToMigrate.push(toRateFeedId("relayed:CELOGHS"));
    // feedsToMigrate.push(toRateFeedId("relayed:CELOETH"));
    // feedsToMigrate.push(toRateFeedId("relayed:CELOGBP"));
    // feedsToMigrate.push(toRateFeedId("relayed:CELOZAR"));
    // feedsToMigrate.push(toRateFeedId("relayed:CELOCHF"));
    // feedsToMigrate.push(toRateFeedId("relayed:CELOCAD"));
    // feedsToMigrate.push(toRateFeedId("relayed:CELOAUD"));
    // feedsToMigrate.push(toRateFeedId("relayed:CELONGN"));
    // feedsToMigrate.push(toRateFeedId("relayed:CELOJPY"));
    // feedsToMigrate.push(cUSDProxy); // CELO/USD
    // feedsToMigrate.push(cEURProxy); // CELO/EUR
    // feedsToMigrate.push(cBRLProxy); // CELO/BRL
    // feedsToMigrate.push(eXOFProxy); // CELO/XOF
    // feedsToMigrate.push(cKESProxy); // CELO/KES

    // // // XXX/USD
    // feedsToMigrate.push(toRateFeedId("KESUSD"));
    // feedsToMigrate.push(toRateFeedId("relayed:PHPUSD"));
    // feedsToMigrate.push(toRateFeedId("relayed:COPUSD"));
    // feedsToMigrate.push(toRateFeedId("relayed:GHSUSD"));
    // feedsToMigrate.push(toRateFeedId("relayed:GBPUSD"));
    // feedsToMigrate.push(toRateFeedId("relayed:ZARUSD"));
    // feedsToMigrate.push(toRateFeedId("relayed:CHFUSD"));
    // feedsToMigrate.push(toRateFeedId("relayed:CADUSD"));
    // feedsToMigrate.push(toRateFeedId("relayed:AUDUSD"));
    // feedsToMigrate.push(toRateFeedId("relayed:JPYUSD"));
    // feedsToMigrate.push(toRateFeedId("relayed:NGNUSD"));
    // feedsToMigrate.push(toRateFeedId("USDCUSD"));
    // feedsToMigrate.push(toRateFeedId("USDTUSD"));

    // // // // Others
    // feedsToMigrate.push(toRateFeedId("USDCEUR"));
    // feedsToMigrate.push(toRateFeedId("USDCBRL"));
    // feedsToMigrate.push(toRateFeedId("EUROCEUR"));
    // feedsToMigrate.push(toRateFeedId("EUROCXOF"));
    // feedsToMigrate.push(toRateFeedId("EURXOF"));
  }

  function run() public {
    prepare();
    addFeedsToMigrate();
    console2.log("\n");

    assert_relayersAreWhitelisted();
    assert_redstoneCanReport();
    // assert_relayersReport();
    // checkExchangesAreProperlyConfigured();
  }

  function assert_redstoneCanReport() internal {
    vm.startPrank(0xdcbaC3971fd86f7bc70FA25E4C434041efdBb27e);

    address redstoneAdapter = 0x854A01c7b8431bF23b707b134EF3f99fe5C48CED;
    IMockRedstoneAdapter adapter = IMockRedstoneAdapter(redstoneAdapter);

    adapter.relay();
    vm.stopPrank();

    console2.log("✅ Redstone can report\n");
  }

  function assert_relayersReport() internal {
    console2.log("====🔍 Checking if all relayers can report...====");
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

  function assert_relayersAreWhitelisted() internal {
    console2.log("====🔍 Checking if all relayers are whitelisted...====");
    uint256 expectedTokenExpiry = 6 minutes;

    for (uint i = 0; i < feedsToMigrate.length; i++) {
      address rateFeedIdentifier = feedsToMigrate[i];
      address relayer = relayerFactory.getRelayer(rateFeedIdentifier);

      address[] memory whitelisted = sortedOracles.getOracles(rateFeedIdentifier);
      require(whitelisted.length == 1, "❌ Expected 1 oracle on feed");
      // if (whitelisted[0] != relayer) {
      address redstoneAdapter = 0x854A01c7b8431bF23b707b134EF3f99fe5C48CED;
      if (whitelisted[0] != redstoneAdapter) {
        console2.log(
          "Relayer %s is not whitelisted for feed %s, instead %s is whitelisted",
          relayer,
          rateFeedIdentifier,
          whitelisted[0]
        );
        require(whitelisted[0] == relayer, "❌ Expected relayer to be whitelisted");
      }

      uint256 actualExpiry = sortedOracles.tokenReportExpirySeconds(feedsToMigrate[i]);
      if (actualExpiry != expectedTokenExpiry) {
        console2.log("Relayer %s doesnt have the correct expiry time (%d)", relayer, actualExpiry);
        require(actualExpiry == expectedTokenExpiry, "Not all relayers were set to 6 minutes tokenReportExpiry");
      }
    }

    console2.log("✅ All %d Chainlink Relayers were whitelisted and configured correctly\n", feedsToMigrate.length);
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
