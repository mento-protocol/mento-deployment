// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable var-name-mixedcase, func-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { GovernanceScript } from "script/utils/Script.sol";

import { IChainlinkRelayerFactory } from "mento-core-2.5.0/interfaces/IChainlinkRelayerFactory.sol";
import { IChainlinkRelayer } from "mento-core-2.5.0/interfaces/IChainlinkRelayer.sol";

import { ISortedOracles } from "./MU07.sol";

contract MU07Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;
  address private PUSO;

  function prepare() public {
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.loadSilent("PUSO-00-Create-Proxies", "latest");

    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
    PUSO = contracts.deployed("StableTokenPHPProxy");
  }

  function run() public {
    prepare();
    assert_relayersAreWhitelisted();
    assert_tokenReportExpiryEq(toRateFeedId("relayed:CELOPHP"), 5 minutes);
    assert_tokenReportExpiryEq(toRateFeedId("relayed:PHPUSD"), 5 minutes);
    assert_equivalentTokenEq(PUSO, toRateFeedId("relayed:CELOPHP"));
  }

  function assert_relayersAreWhitelisted() internal {
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

      assertEq(oracles.length, 1);

      if (oracles[0] != relayers[i]) {
        console.log("Whitelisted oracle wrong for rateFeed: %s [%s]", relayer.rateFeedDescription(), rateFeedId);
      }
      assertEq(oracles[0], relayers[i]);
      console.log("Rate feed %s setup correctly", relayer.rateFeedDescription());
    }
  }

  function assert_equivalentTokenEq(address token, address expected) internal {
    if (Chain.isBaklava()) {
      /// @dev This SortedOracles feature was not deployed to Baklava. Skipping check.
      console.log("Skipping equivalent token check on Baklava.");
    }
    address actual = sortedOracles.getEquivalentToken(token);
    if (actual != expected) {
      console.log("Equivalent token mismatch for PUSO (%s).");
    }
    assertEq(actual, expected);
    console.log("PUSO [%s] equivalent token is correct", PUSO);
  }

  function assert_tokenReportExpiryEq(address rateFeedId, uint256 expected) internal {
    uint256 actual = sortedOracles.getTokenReportExpirySeconds(rateFeedId);
    if (actual != expected) {
      console.log("Token report expiry mismatch for rateFeedId [%s].", rateFeedId);
    }
    assertEq(actual, expected);
    console.log("Token report expiry for rateFeedId [%s] is correct", rateFeedId);
  }
}
