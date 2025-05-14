// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
import { Arrays } from "script/utils/Arrays.sol";

import { Contracts } from "script/utils/Contracts.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";

contract OracleMigrationConfig {
  struct SpreadOverride {
    address asset0;
    address asset1;
    FixidityLib.Fraction currentSpread;
    FixidityLib.Fraction targetSpread;
  }

  struct StablePoolResetSizeOverride {
    address asset0;
    address asset1;
    FixidityLib.Fraction currentResetSize;
    FixidityLib.Fraction targetResetSize;
  }

  using Contracts for Contracts.Cache;

  address private cUSDProxy;
  address private cEURProxy;
  address private cBRLProxy;
  address payable private eXOFProxy;
  address payable private cKESProxy;

  constructor() {
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.load("cKES-00-Create-Proxies", "latest");
    contracts.load("eXOF-00-Create-Proxies", "latest");

    contracts.loadSilent("MU01-00-Create-Proxies", "latest"); // BrokerProxy & BiPoolProxy
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest"); // Pricing Modules
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU04-00-Create-Implementations", "latest"); // First StableTokenV2 deployment

    cUSDProxy = contracts.celoRegistry("StableToken");
    cEURProxy = contracts.celoRegistry("StableTokenEUR");
    cBRLProxy = contracts.celoRegistry("StableTokenBRL");
    eXOFProxy = contracts.deployed("StableTokenXOFProxy");
    cKESProxy = contracts.deployed("StableTokenKESProxy");
  }

  function redstonePoweredFeeds() public pure returns (address[] memory) {
    address[] memory feeds = new address[](7);
    feeds[0] = cUSDProxy; // CELO/USD
    feeds[1] = cEURProxy; // CELO/EUR
    feeds[2] = cBRLProxy; // CELO/BRL
    feeds[3] = _toRateFeedId("USDCUSD");
    feeds[4] = _toRateFeedId("USDCEUR");
    feeds[5] = _toRateFeedId("USDCBRL");
    feeds[6] = _toRateFeedId("EUROCEUR");

    return feeds;
  }

  function chainlinkPoweredFeeds() public pure returns (address[] memory) {
    address[] memory feeds = new address[](7);
    feeds[0] = eXOFProxy; // CELO/XOF
    feeds[1] = _toRateFeedId("EUROCXOF");
    feeds[2] = _toRateFeedId("EURXOF");
    feeds[3] = cKESProxy; // CELO/KES
    feeds[4] = _toRateFeedId("KESUSD");
    feeds[5] = _toRateFeedId("USDTUSD");
    feeds[6] = _toRateFeedId("relayed:PHPUSD"); // Won't be migrated, but we'll set the bucket reset freq to 6 minutes

    return feeds;
  }

  function getFeedsToMigrate() public pure returns (address[] memory) {
    address[] memory redstone = redstonePoweredFeeds();
    address[] memory chainlink = chainlinkPoweredFeeds();

    address[] memory combined = new address[](redstone.length + chainlink.length);
    for (uint256 i = 0; i < redstone.length; i++) {
      combined[i] = redstone[i];
    }
    for (uint256 i = 0; i < chainlink.length; i++) {
      combined[redstone.length + i] = chainlink[i];
    }

    return combined;
  }

  function isRedstonePowered(address rateFeedIdentifier) public pure returns (bool) {
    return Arrays.contains(redstonePoweredFeeds(), rateFeedIdentifier);
  }

  function isChainlinkPowered(address rateFeedIdentifier) public pure returns (bool) {
    return Arrays.contains(chainlinkPoweredFeeds(), rateFeedIdentifier);
  }

  function _toRateFeedId(string memory rateFeedString) internal pure returns (address) {
    return address(uint160(uint256(keccak256(abi.encodePacked(rateFeedString)))));
  }
}
