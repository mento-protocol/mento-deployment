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

import { ISortedOracles } from "./FX02.sol";

contract FX02Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;

  // CHF
  address private cCHF;
  address private CELOCHFRateFeed;
  address private CHFUSDRateFeed;

  // JPY
  address private cJPY;
  address private CELOJPYRateFeed;
  address private JPYUSDRateFeed;

  // NGN
  address private cNGN;
  address private CELONGNRateFeed;
  address private NGNUSDRateFeed;

  function prepare() public {
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.loadSilent("FX00-00-Deploy-Proxys", "latest");
    contracts.loadSilent("FX02-00-Deploy-Proxys", "latest");

    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));

    // CHF were whitelisted as part of FX00, but as they are a pre-requisite for FX03, we double check
    // that they were configured correctly.
    cCHF = contracts.deployed("StableTokenCHFProxy");
    CELOCHFRateFeed = toRateFeedId("relayed:CELOCHF");
    CHFUSDRateFeed = toRateFeedId("relayed:CHFUSD");

    cJPY = contracts.deployed("StableTokenJPYProxy");
    CELOJPYRateFeed = toRateFeedId("relayed:CELOJPY");
    JPYUSDRateFeed = toRateFeedId("relayed:JPYUSD");

    cNGN = contracts.deployed("StableTokenNGNProxy");
    CELONGNRateFeed = toRateFeedId("relayed:CELONGN");
    NGNUSDRateFeed = toRateFeedId("relayed:NGNUSD");
  }

  function run() public {
    console.log("\n=== Running FX02Checks ===\n");

    prepare();
    assert_relayersAreWhitelisted();
    assert_relayersReport();
    assert_tokenReportExpiry();
    assert_equivalentTokens();
  }

  function assert_relayersReport() internal {
    console.log("=== Relayer report check ===");

    address[] memory allRelayerAddresses = new address[](6);
    allRelayerAddresses[0] = relayerFactory.getRelayer(CELOCHFRateFeed);
    allRelayerAddresses[1] = relayerFactory.getRelayer(CHFUSDRateFeed);

    allRelayerAddresses[2] = relayerFactory.getRelayer(CELOJPYRateFeed);
    allRelayerAddresses[3] = relayerFactory.getRelayer(JPYUSDRateFeed);

    allRelayerAddresses[4] = relayerFactory.getRelayer(CELONGNRateFeed);
    allRelayerAddresses[5] = relayerFactory.getRelayer(NGNUSDRateFeed);

    for (uint i = 0; i < allRelayerAddresses.length; i++) {
      IChainlinkRelayer relayer = IChainlinkRelayer(allRelayerAddresses[i]);
      relayer.relay();
      (uint256 rate, ) = sortedOracles.medianRate(relayer.rateFeedId());
      emit log_named_decimal_uint(relayer.rateFeedDescription(), rate, 24);
    }

    console.log("👏 All FX token relayers relayed successfully\n");
  }

  function assert_relayersAreWhitelisted() internal {
    console.log("=== Whitelist check ===");

    assert_relayerIsWhitelisted(CELOCHFRateFeed, "CELO/CHF");
    assert_relayerIsWhitelisted(CHFUSDRateFeed, "CHF/USD");

    assert_relayerIsWhitelisted(CELOJPYRateFeed, "CELO/JPY");
    assert_relayerIsWhitelisted(JPYUSDRateFeed, "JPY/USD");

    assert_relayerIsWhitelisted(CELONGNRateFeed, "CELO/NGN");
    assert_relayerIsWhitelisted(NGNUSDRateFeed, "NGN/USD");

    console.log("👏 All FX token relayers whitelisted correctly\n");
  }

  function assert_relayerIsWhitelisted(address rateFeedId, string memory pairName) internal {
    require(
      sortedOracles.getOracles(rateFeedId).length == 1,
      string(abi.encodePacked(pairName, " should have exactly 1 oracle"))
    );
    address whitelisted = sortedOracles.getOracles(rateFeedId)[0];
    require(
      whitelisted == relayerFactory.getRelayer(rateFeedId),
      string(abi.encodePacked("Wrong ", pairName, " relayer whitelisted"))
    );
    console.log("✅ %s relayer whitelisted correctly", pairName);
  }

  function assert_equivalentTokens() internal {
    console.log("=== Equivalent tokens check ===");

    assert_equivalentTokenEq(cCHF, CELOCHFRateFeed, "cCHF");
    assert_equivalentTokenEq(cJPY, CELOJPYRateFeed, "cJPY");
    assert_equivalentTokenEq(cNGN, CELONGNRateFeed, "cNGN");

    console.log("👏 All equivalent tokens are correctly set\n");
  }

  function assert_tokenReportExpiry() internal {
    console.log("=== Token report expiry check ===");

    uint256 expected = 6 minutes;

    assert_tokenReportExpiryEq(CELOCHFRateFeed, expected);
    assert_tokenReportExpiryEq(CHFUSDRateFeed, expected);

    assert_tokenReportExpiryEq(CELOJPYRateFeed, expected);
    assert_tokenReportExpiryEq(JPYUSDRateFeed, expected);

    assert_tokenReportExpiryEq(CELONGNRateFeed, expected);
    assert_tokenReportExpiryEq(NGNUSDRateFeed, expected);

    console.log("👏 All token report expiry settings are correct\n");
  }

  function assert_equivalentTokenEq(address token, address expected, string memory tokenName) internal {
    address actual = sortedOracles.getEquivalentToken(token);
    if (actual != expected) {
      console.log("❌ Equivalent token mismatch for %s", tokenName);
    }
    assertEq(actual, expected);
    console.log("✅ %s equivalent token is correctly set", tokenName);
  }

  function assert_tokenReportExpiryEq(address rateFeedId, uint256 expected) internal {
    uint256 actual = sortedOracles.getTokenReportExpirySeconds(rateFeedId);
    if (actual != expected) {
      console.log("❌ Token report expiry mismatch for rateFeedId [%s]", rateFeedId);
    }
    assertEq(actual, expected);
    console.log("✅ Token report expiry for rateFeedId [%s] is correct", rateFeedId);
  }
}
