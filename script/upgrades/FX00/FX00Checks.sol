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

import { ISortedOracles } from "./FX00.sol";

contract FX00Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  IChainlinkRelayerFactory private relayerFactory;
  ISortedOracles private sortedOracles;

  // AUD
  address private cAUD;
  address private CELOAUDRateFeed;
  address private AUDUSDRateFeed;

  // CAD
  address private cCAD;
  address private CELOCADRateFeed;
  address private CADUSDRateFeed;

  // CHF
  address private cCHF;
  address private CELOCHFRateFeed;
  address private CHFUSDRateFeed;

  // GBP
  address private cGBP;
  address private CELOGBPRateFeed;
  address private GBPUSDRateFeed;

  // ZAR
  address private cZAR;
  address private CELOZARRateFeed;
  address private ZARUSDRateFeed;

  function prepare() public {
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.loadSilent("FX00-00-Deploy-Proxys", "latest");

    relayerFactory = IChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));

    cAUD = contracts.deployed("StableTokenAUDProxy");
    CELOAUDRateFeed = toRateFeedId("relayed:CELOAUD");
    AUDUSDRateFeed = toRateFeedId("relayed:AUDUSD");

    cCAD = contracts.deployed("StableTokenCADProxy");
    CELOCADRateFeed = toRateFeedId("relayed:CELOCAD");
    CADUSDRateFeed = toRateFeedId("relayed:CADUSD");

    cCHF = contracts.deployed("StableTokenCHFProxy");
    CELOCHFRateFeed = toRateFeedId("relayed:CELOCHF");
    CHFUSDRateFeed = toRateFeedId("relayed:CHFUSD");

    cGBP = contracts.deployed("StableTokenGBPProxy");
    CELOGBPRateFeed = toRateFeedId("relayed:CELOGBP");
    GBPUSDRateFeed = toRateFeedId("relayed:GBPUSD");

    cZAR = contracts.deployed("StableTokenZARProxy");
    CELOZARRateFeed = toRateFeedId("relayed:CELOZAR");
    ZARUSDRateFeed = toRateFeedId("relayed:ZARUSD");
  }

  function run() public {
    console.log("\n=== Running FX00Checks ===\n");

    prepare();
    assert_relayersAreWhitelisted();
    assert_relayersReport();
    assert_tokenReportExpiry();
    assert_equivalentTokens();
  }

  function assert_relayersReport() internal {
    console.log("=== Relayer report check ===");

    address[] memory allRelayerAddresses = new address[](10);
    allRelayerAddresses[0] = relayerFactory.getRelayer(CELOAUDRateFeed);
    allRelayerAddresses[1] = relayerFactory.getRelayer(AUDUSDRateFeed);

    allRelayerAddresses[2] = relayerFactory.getRelayer(CELOCADRateFeed);
    allRelayerAddresses[3] = relayerFactory.getRelayer(CADUSDRateFeed);

    allRelayerAddresses[4] = relayerFactory.getRelayer(CELOCHFRateFeed);
    allRelayerAddresses[5] = relayerFactory.getRelayer(CHFUSDRateFeed);

    allRelayerAddresses[6] = relayerFactory.getRelayer(CELOGBPRateFeed);
    allRelayerAddresses[7] = relayerFactory.getRelayer(GBPUSDRateFeed);

    allRelayerAddresses[8] = relayerFactory.getRelayer(CELOZARRateFeed);
    allRelayerAddresses[9] = relayerFactory.getRelayer(ZARUSDRateFeed);

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

    assert_relayerIsWhitelisted(CELOAUDRateFeed, "CELO/AUD");
    assert_relayerIsWhitelisted(AUDUSDRateFeed, "AUD/USD");

    assert_relayerIsWhitelisted(CELOCADRateFeed, "CELO/CAD");
    assert_relayerIsWhitelisted(CADUSDRateFeed, "CAD/USD");

    assert_relayerIsWhitelisted(CELOCHFRateFeed, "CELO/CHF");
    assert_relayerIsWhitelisted(CHFUSDRateFeed, "CHF/USD");

    assert_relayerIsWhitelisted(CELOGBPRateFeed, "CELO/GBP");
    assert_relayerIsWhitelisted(GBPUSDRateFeed, "GBP/USD");

    assert_relayerIsWhitelisted(CELOZARRateFeed, "CELO/ZAR");
    assert_relayerIsWhitelisted(ZARUSDRateFeed, "ZAR/USD");

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

    assert_equivalentTokenEq(cAUD, CELOAUDRateFeed, "cAUD");
    assert_equivalentTokenEq(cCAD, CELOCADRateFeed, "cCAD");
    assert_equivalentTokenEq(cCHF, CELOCHFRateFeed, "cCHF");
    assert_equivalentTokenEq(cGBP, CELOGBPRateFeed, "cGBP");
    assert_equivalentTokenEq(cZAR, CELOZARRateFeed, "cZAR");

    console.log("👏 All equivalent tokens are correctly set\n");
  }

  function assert_tokenReportExpiry() internal {
    console.log("=== Token report expiry check ===");

    uint256 expected = 6 minutes;

    assert_tokenReportExpiryEq(CELOAUDRateFeed, expected);
    assert_tokenReportExpiryEq(AUDUSDRateFeed, expected);

    assert_tokenReportExpiryEq(CELOCADRateFeed, expected);
    assert_tokenReportExpiryEq(CADUSDRateFeed, expected);

    assert_tokenReportExpiryEq(CELOCHFRateFeed, expected);
    assert_tokenReportExpiryEq(CHFUSDRateFeed, expected);

    assert_tokenReportExpiryEq(CELOGBPRateFeed, expected);
    assert_tokenReportExpiryEq(GBPUSDRateFeed, expected);

    assert_tokenReportExpiryEq(CELOZARRateFeed, expected);
    assert_tokenReportExpiryEq(ZARUSDRateFeed, expected);

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
