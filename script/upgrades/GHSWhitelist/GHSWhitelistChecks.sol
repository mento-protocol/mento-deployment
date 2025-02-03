// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable var-name-mixedcase, func-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { GovernanceScript } from "script/utils/Script.sol";

import { IChainlinkRelayerFactory } from "mento-core-2.5.0/interfaces/IChainlinkRelayerFactory.sol";
import { IChainlinkRelayer } from "mento-core-2.5.0/interfaces/IChainlinkRelayer.sol";

import { ISortedOracles } from "./GHSWhitelist.sol";

contract GHSWhitelistChecks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;
  address private cGHS;
  address CELOGHSRateFeed;
  address GHSUSDRateFeed;

  function prepare() public {
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.loadSilent("cGHS-00-Deploy-Proxy", "latest");

    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
    cGHS = contracts.deployed("StableTokenGHSProxy");
    CELOGHSRateFeed = toRateFeedId("relayed:CELOGHS");
    GHSUSDRateFeed = toRateFeedId("relayed:GHSUSD");
  }

  function run() public {
    prepare();
    assert_relayersAreWhitelisted();
    assert_relayersReport();
    assert_tokenReportExpiryEq(CELOGHSRateFeed, 6 minutes);
    assert_tokenReportExpiryEq(GHSUSDRateFeed, 6 minutes);
  }

  function assert_relayersReport() internal {
    address[] memory ghsRelayers = Arrays.addresses(
      relayerFactory.getRelayer(CELOGHSRateFeed),
      relayerFactory.getRelayer(GHSUSDRateFeed)
    );

    for (uint i = 0; i < ghsRelayers.length; i++) {
      IChainlinkRelayer relayer = IChainlinkRelayer(ghsRelayers[i]);

      relayer.relay();
      (uint256 rate, ) = sortedOracles.medianRate(relayer.rateFeedId());
      emit log_named_decimal_uint(relayer.rateFeedDescription(), rate, 24);
    }

    console.log("✅ CELO/GHS and GHS/USD relayers relayed successfully");
  }

  function assert_relayersAreWhitelisted() internal {
    require(sortedOracles.getOracles(CELOGHSRateFeed).length == 1);
    require(sortedOracles.getOracles(GHSUSDRateFeed).length == 1);

    address CELOGHSWhitelisted = sortedOracles.getOracles(CELOGHSRateFeed)[0];
    address GHSUSDWhitelisted = sortedOracles.getOracles(GHSUSDRateFeed)[0];

    require(CELOGHSWhitelisted == relayerFactory.getRelayer(CELOGHSRateFeed), "Wrong CELO/GHS relayer whitelisted");
    require(GHSUSDWhitelisted == relayerFactory.getRelayer(GHSUSDRateFeed), "Wrong GHS/USD relayer whitelisted");

    console.log("✅ CELO/GHS and GHS/USD relayers whitelisted correctly");
  }

  function assert_equivalentTokenEq(address token, address expected) internal {
    address actual = sortedOracles.getEquivalentToken(token);
    if (actual != expected) {
      console.log("❌ Equivalent token mismatch for $cGHS (%s).");
    }
    assertEq(actual, expected);
    console.log("✅ $cGHS [%s] equivalent token is correct", cGHS);
  }

  function assert_tokenReportExpiryEq(address rateFeedId, uint256 expected) internal {
    uint256 actual = sortedOracles.getTokenReportExpirySeconds(rateFeedId);
    if (actual != expected) {
      console.log("❌ Token report expiry mismatch for rateFeedId [%s].", rateFeedId);
    }
    assertEq(actual, expected);
    console.log("✅ Token report expiry for rateFeedId [%s] is correct", rateFeedId);
  }
}
