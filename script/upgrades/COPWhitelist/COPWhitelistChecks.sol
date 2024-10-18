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

import { ISortedOracles } from "./COPWhitelist.sol";

contract COPWhitelistChecks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;
  address private cCOP;
  address CELOCOPRateFeed;
  address COPUSDRateFeed;

  function prepare() public {
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.loadSilent("cCOP-00-Create-Proxies", "latest");

    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
    cCOP = contracts.deployed("StableTokenCOPProxy");
    CELOCOPRateFeed = toRateFeedId("relayed:CELOCOP");
    COPUSDRateFeed = toRateFeedId("relayed:COPUSD");
  }

  function run() public {
    prepare();
    assert_relayersAreWhitelisted();
    assert_relayersReport();
    assert_tokenReportExpiryEq(CELOCOPRateFeed, 6 minutes);
    assert_tokenReportExpiryEq(COPUSDRateFeed, 6 minutes);
  }

  function assert_relayersReport() internal {
    address[] memory copRelayers = Arrays.addresses(
      relayerFactory.getRelayer(CELOCOPRateFeed),
      relayerFactory.getRelayer(COPUSDRateFeed)
    );

    for (uint i = 0; i < copRelayers.length; i++) {
      IChainlinkRelayer relayer = IChainlinkRelayer(copRelayers[i]);

      relayer.relay();
      (uint256 rate, ) = sortedOracles.medianRate(relayer.rateFeedId());
      emit log_named_decimal_uint(relayer.rateFeedDescription(), rate, 24);
    }

    console.log("✅ CELO/COP and COP/USD relayers relayed successfully");
  }

  function assert_relayersAreWhitelisted() internal {
    require(sortedOracles.getOracles(CELOCOPRateFeed).length == 1);
    require(sortedOracles.getOracles(COPUSDRateFeed).length == 1);

    address CELOCOPWhitelisted = sortedOracles.getOracles(CELOCOPRateFeed)[0];
    address COPUSDWhitelisted = sortedOracles.getOracles(COPUSDRateFeed)[0];

    require(CELOCOPWhitelisted == relayerFactory.getRelayer(CELOCOPRateFeed), "Wrong CELO/COP relayer whitelisted");
    require(COPUSDWhitelisted == relayerFactory.getRelayer(COPUSDRateFeed), "Wrong COP/USD relayer whitelisted");

    console.log("✅ CELO/COP and COP/USD relayers whitelisted correctly");
  }

  function assert_equivalentTokenEq(address token, address expected) internal {
    require(!Chain.isBaklava(), "Baklava is not suported for this deployment.");

    address actual = sortedOracles.getEquivalentToken(token);
    if (actual != expected) {
      console.log("❌ Equivalent token mismatch for $cCOP (%s).");
    }
    assertEq(actual, expected);
    console.log("✅ $cCOP [%s] equivalent token is correct", cCOP);
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
