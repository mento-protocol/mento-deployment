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

import { ISortedOracles } from "./SunsetOraclesCGP01.sol";

contract SunsetOraclesCGP01Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;

  address payable private cKESProxy;
  address payable private eXOFProxy;

  function prepare() public {
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.load("cKES-00-Create-Proxies", "latest");
    contracts.load("eXOF-00-Create-Proxies", "latest");

    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));

    cKESProxy = contracts.deployed("StableTokenKESProxy");
    eXOFProxy = contracts.deployed("StableTokenXOFProxy");
  }

  function run() public {
    prepare();

    assert_relayersAreWhitelisted();
    assert_relayersReport();
  }

  function assert_relayersReport() internal {
    address[] memory feeds = getFeeds();

    for (uint i = 0; i < feeds.length; i++) {
      address relayerAddress = relayerFactory.getRelayer(feeds[i]);
      IChainlinkRelayer relayer = IChainlinkRelayer(relayerAddress);

      relayer.relay();
      (uint256 rate, ) = sortedOracles.medianRate(relayer.rateFeedId());
      emit log_named_decimal_uint(relayer.rateFeedDescription(), rate, 24);

      console2.log("🚀 Relayer %s relayed successfully", relayerAddress);
    }
  }

  function assert_relayersAreWhitelisted() internal {
    address[] memory feeds = getFeeds();
    uint256 expectedTokenExpiry = 6 minutes;

    for (uint i = 0; i < feeds.length; i++) {
      address relayer = relayerFactory.getRelayer(feeds[i]);

      address[] memory whitelisted = sortedOracles.getOracles(feeds[i]);
      bool found = false;
      for (uint j = 0; j < whitelisted.length; j++) {
        if (whitelisted[j] == relayer) {
          found = true;
        }
      }
      if (!found) {
        console2.log("Relayer %s was not whitelisted on feed %s", relayer, feeds[i]);
        require(found, "❌ Not all relayers were whilisted");
      }

      uint256 actualExpiry = sortedOracles.tokenReportExpirySeconds(feeds[i]);
      if (actualExpiry != expectedTokenExpiry) {
        console2.log("Relayer %s doesnt have the correct expiry time (%d)", relayer, actualExpiry);
        require(actualExpiry == expectedTokenExpiry, "Not all relayers were set to 6 minutes tokenReportExpiry");
      }
    }

    console2.log("✅ All %d Chainlink Relayers were whitelisted and configured correctly", feeds.length);
  }

  function getFeeds() internal returns (address[] memory feeds) {
    return
      Arrays.addresses(
        cKESProxy, // CELO/KES relayer
        toRateFeedId("KESUSD"),
        eXOFProxy, // CELO/XOF relayer
        toRateFeedId("EURCXOF"),
        toRateFeedId("EURXOF"),
        toRateFeedId("USDTUSD")
      );
  }
}
