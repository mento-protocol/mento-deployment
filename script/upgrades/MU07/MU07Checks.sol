// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { GovernanceScript } from "script/utils/Script.sol";

import { IChainlinkRelayerFactory } from "lib/mento-core-develop/contracts/interfaces/IChainlinkRelayerFactory.sol";
import { IChainlinkRelayer } from "lib/mento-core-develop/contracts/interfaces/IChainlinkRelayer.sol";

// import { toRateFeedId } from "script/utils/mento/Oracles.sol";

interface ISortedOracles {
  function addOracle(address, address) external;

  function removeOracle(address, address, uint256) external;

  function setEquivalentToken(address, address) external;

  function getEquivalentToken(address) external returns (address);

  function getOracles(address) external returns (address[] memory);
}

contract MU07Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;
  address private cPHP;

  function setUp() public {
    contracts.loadSilent("DeployChainlinkRelayerFactory", "latest");

    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
    // TODO: After cPHP token contract deployment is merged, get the address here.
    cPHP = address(1);
  }

  function run() public {
    setUp();
    verifyRelayersAreOnlyWhitelisted();
    verifyCPHPHasEquivalentToken();
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

  function verifyCPHPHasEquivalentToken() internal {
    address equivalentToken = sortedOracles.getEquivalentToken(cPHP);
    address CELOPHPRateFeedId = toRateFeedId("relayed:CELO/PHP");
    if (equivalentToken == address(0)) {
      console.log("Equivalent Token not set for cPHP (%s)", cPHP);
    }
    if (equivalentToken != CELOPHPRateFeedId) {
      console.log("Invalid equivalent token for cPHP (%s)", cPHP);
    }
    assertEq(equivalentToken, CELOPHPRateFeedId);
    console.log("cPHP [%s] equivalent token is correct", cPHP);
  }
}
