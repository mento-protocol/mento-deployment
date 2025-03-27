// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable var-name-mixedcase, func-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Test } from "forge-std/Test.sol";
import { console2 as console } from "forge-std/Script.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { GovernanceScript } from "script/utils/Script.sol";

import { IChainlinkRelayerFactory } from "mento-core-2.5.0/interfaces/IChainlinkRelayerFactory.sol";
import { IChainlinkRelayer } from "mento-core-2.5.0/interfaces/IChainlinkRelayer.sol";

import { ISortedOracles } from "./ETHRelayer.sol";

contract ETHRelayerChecks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;
  address CELOETHRateFeed;

  function prepare() public {
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");

    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
    CELOETHRateFeed = toRateFeedId("relayed:CELOETH");
  }

  function run() public {
    prepare();
    assert_relayersAreWhitelisted();
    assert_relayersReport();
    assert_tokenReportExpiryEq(CELOETHRateFeed, 6 minutes);
  }

  function assert_relayersReport() internal {
    address celoEthRelayer = relayerFactory.getRelayer(CELOETHRateFeed);
    IChainlinkRelayer relayer = IChainlinkRelayer(celoEthRelayer);

    relayer.relay();
    (uint256 rate, ) = sortedOracles.medianRate(relayer.rateFeedId());
    emit log_named_decimal_uint(relayer.rateFeedDescription(), rate, 24);

    console.log("✅ CELO/ETH relayer relayed successfully (rate: %d)", rate);
  }

  function assert_relayersAreWhitelisted() internal {
    require(sortedOracles.getOracles(CELOETHRateFeed).length == 1);

    address CELOETHRelayerWhitelisted = sortedOracles.getOracles(CELOETHRateFeed)[0];

    require(
      CELOETHRelayerWhitelisted == relayerFactory.getRelayer(CELOETHRateFeed),
      "Wrong CELO/ETH relayer whitelisted"
    );

    console.log("✅ CELO/ETH relayer whitelisted correctly");
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
