// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { GovernanceScript } from "script/utils/Script.sol";

import { IChainlinkRelayerFactory } from "lib/mento-core-develop/contracts/interfaces/IChainlinkRelayerFactory.sol";
import { IChainlinkRelayer } from "lib/mento-core-develop/contracts/interfaces/IChainlinkRelayer.sol";

import { ISortedOracles } from "./MU07.sol";

contract MU07Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;
  address private PSO;

  function prepare() public {
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.loadSilent("PSO-00-Create-Proxies", "latest");

    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
    PSO = contracts.deployed("StableTokenPSOProxy");
  }

  function run() public {
    prepare();
    verifyRelayersAreOnlyWhitelisted();
    verifyPSOHasEquivalentToken();
  }

  function verifyRelayersAreOnlyWhitelisted() internal {
    address[] memory relayers = relayerFactory.getRelayers();
    for (uint i = 0; i < relayers.length; i++) {
      IChainlinkRelayer relayer = IChainlinkRelayer(relayers[i]);
      address rateFeedId = relayer.rateFeedId();
      address[] memory oracles = sortedOracles.getOracles(rateFeedId);
      if (oracles.length == 0) {
        console.log("No oracles whitelisted for rateFeed: %s [%s]", relayer.rateFeedDescription(), rateFeedId);
      } else if (oracles.length > 1) {
        console.log("Too many oracles whitelisted for rateFeed: %s [%s]", relayer.rateFeedDescription(), rateFeedId);
      }

      assert(oracles.length == 1);

      if (oracles[0] != relayers[i]) {
        console.log("Whitelisted oracle wrong for rateFeed: %s [%s]", relayer.rateFeedDescription(), rateFeedId);
      }
      assertEq(oracles[0], relayers[i]);
      console.log("Rate feed %s setup correctly", relayer.rateFeedDescription());
    }
  }

  function verifyPSOHasEquivalentToken() internal {
    address equivalentToken = sortedOracles.getEquivalentToken(PSO);
    address CELOPHPRateFeedId = toRateFeedId("relayed:CELOPHP");
    if (equivalentToken == address(0)) {
      console.log("Equivalent Token not set for PSO (%s)", PSO);
    }
    if (equivalentToken != CELOPHPRateFeedId) {
      console.log("Invalid equivalent token for PSO (%s)", PSO);
    }
    assertEq(equivalentToken, CELOPHPRateFeedId);
    console.log("PSO [%s] equivalent token is correct", PSO);
  }
}
