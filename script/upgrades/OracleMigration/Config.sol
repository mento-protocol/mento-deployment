// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;
import { Arrays } from "script/utils/Arrays.sol";

import { GovernanceScript } from "script/utils/Script.sol";
// import { Contracts } from "script/utils/Contracts.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";
import { IBiPoolManager } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";

contract OracleMigrationConfig is GovernanceScript {
  struct SpreadOverride {
    address asset0;
    address asset1;
    address rateFeedId;
    FixidityLib.Fraction currentSpread;
    FixidityLib.Fraction targetSpread;
  }

  struct StablePoolResetSizeOverride {
    address asset0;
    address asset1;
    address rateFeedId;
    uint256 currentResetSize;
    uint256 targetResetSize;
  }

  // using Contracts for Contracts.Cache;

  address private CELOProxy;
  address private cUSDProxy;
  address private cEURProxy;
  address private cBRLProxy;
  address private eXOFProxy;
  // address payable private eXOFProxy;
  address private cKESProxy;
  // address payable private cKESProxy;
  address private bridgedEUROCProxy;

  function load() public {
    contracts.loadSilent("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.load("cKES-00-Create-Proxies", "latest");
    contracts.load("eXOF-00-Create-Proxies", "latest");

    contracts.loadSilent("MU01-00-Create-Proxies", "latest"); // BrokerProxy & BiPoolProxy
    contracts.loadSilent("MU01-01-Create-Nonupgradeable-Contracts", "latest"); // Pricing Modules
    contracts.loadSilent("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.loadSilent("MU04-00-Create-Implementations", "latest"); // First StableTokenV2 deployment

    CELOProxy = contracts.celoRegistry("GoldToken");
    cUSDProxy = contracts.celoRegistry("StableToken");
    cEURProxy = contracts.celoRegistry("StableTokenEUR");
    cBRLProxy = contracts.celoRegistry("StableTokenBRL");
    eXOFProxy = contracts.deployed("StableTokenXOFProxy");
    cKESProxy = contracts.deployed("StableTokenKESProxy");
  }

  function redstonePoweredFeeds() public view returns (address[] memory) {
    address[] memory feeds = new address[](7);
    feeds[0] = cUSDProxy; // CELO/USD
    feeds[1] = cEURProxy; // CELO/EUR
    feeds[2] = cBRLProxy; // CELO/BRL
    feeds[3] = toRateFeedId("USDCUSD");
    feeds[4] = toRateFeedId("USDCEUR");
    feeds[5] = toRateFeedId("USDCBRL");
    feeds[6] = toRateFeedId("EUROCEUR");

    return feeds;
  }

  function chainlinkPoweredFeeds() public view returns (address[] memory) {
    address[] memory feeds = new address[](6);
    feeds[0] = eXOFProxy; // CELO/XOF
    feeds[1] = toRateFeedId("EUROCXOF");
    feeds[2] = toRateFeedId("EURXOF");
    feeds[3] = cKESProxy; // CELO/KES
    feeds[4] = toRateFeedId("KESUSD");
    feeds[5] = toRateFeedId("USDTUSD");
    // feeds[6] = toRateFeedId("relayed:PHPUSD"); // Won't be migrated, but we'll set the bucket reset freq to 6 minutes

    return feeds;
  }

  function feedsToMigrate() public view returns (address[] memory) {
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

  function spreadOverrides() public view returns (SpreadOverride[] memory) {
    SpreadOverride[] memory overrides = new SpreadOverride[](2);
    // eXOF/CELO
    overrides[0] = SpreadOverride({
      asset0: eXOFProxy,
      asset1: CELOProxy,
      rateFeedId: eXOFProxy,
      currentSpread: FixidityLib.newFixedFraction(50, 10_000), // 0.5%
      targetSpread: FixidityLib.newFixedFraction(2, 100) // 2%
    });
    // eXOF/EUROC
    overrides[1] = SpreadOverride({
      asset0: eXOFProxy,
      asset1: bridgedEUROCProxy,
      rateFeedId: toRateFeedId("EUROCXOF"),
      currentSpread: FixidityLib.newFixedFraction(25, 10000), // 0.25%
      targetSpread: FixidityLib.newFixedFraction(2, 100) // 2%
    });

    return overrides;
  }

  function resetSizeOverrides() public view returns (StablePoolResetSizeOverride[] memory) {
    StablePoolResetSizeOverride[] memory overrides = new StablePoolResetSizeOverride[](1);
    // cUSD/CELO
    overrides[0] = StablePoolResetSizeOverride({
      asset0: cUSDProxy,
      asset1: CELOProxy,
      rateFeedId: cUSDProxy,
      currentResetSize: 7_200_000 * 1e18,
      targetResetSize: 3_000_000 * 1e18
    });

    return overrides;
  }

  function getNewExchangeCfg(
    IBiPoolManager.PoolExchange memory currentExchange
  ) public view returns (IBiPoolManager.PoolExchange memory) {
    IBiPoolManager.PoolExchange memory newExchange = currentExchange;
    newExchange.bucket0 = 0;
    newExchange.bucket1 = 0;
    newExchange.lastBucketUpdate = 0;
    newExchange.config.minimumReports = 1;
    newExchange.config.referenceRateResetFrequency = 6 minutes;

    // (bool hasNewSpread, uint256 newSpread) = hasNewSpread(currentExchange);
    // if (hasNewSpread) {
    //   newExchange.config.spread = FixidityLib.wrap(newSpread);
    //   // newExchange.config.spread = newSpread;
    // }

    // (bool hasNewResetSize, uint256 newResetSize) = hasNewResetSize(currentExchange);
    // if (hasNewResetSize) {
    //   newExchange.config.stablePoolResetSize = newResetSize;
    // }
    return newExchange;
  }

  // function hasNewSpread(IBiPoolManager.PoolExchange memory poolCfg) public view returns (bool, uint256) {
  //   SpreadOverride[] memory overrides = spreadOverrides();
  //   for (uint256 i = 0; i < overrides.length; i++) {
  //     if (overrides[i].asset0 == poolCfg.asset0 && overrides[i].asset1 == poolCfg.asset1) {
  //       require(
  //         overrides[i].rateFeedId == poolCfg.config.referenceRateFeedID,
  //         "Rate feed ID mismatch on spread override"
  //       );
  //       require(overrides[i].currentSpread == poolCfg.config.spread, "Current spread mismatch on spread override");

  //       return (true, overrides[i].targetSpread.unwrap());
  //     }
  //   }

  //   return (false, poolCfg.config.spread.unwrap());
  // }

  // function hasNewResetSize(IBiPoolManager.PoolExchange memory poolCfg) public view returns (bool, uint256) {
  //   StablePoolResetSizeOverride[] memory overrides = resetSizeOverrides();
  //   for (uint256 i = 0; i < overrides.length; i++) {
  //     if (overrides[i].asset0 == poolCfg.asset0 && overrides[i].asset1 == poolCfg.asset1) {
  //       require(
  //         overrides[i].rateFeedId == poolCfg.config.referenceRateFeedID,
  //         "Rate feed ID mismatch on reset size override"
  //       );
  //       require(
  //         overrides[i].currentResetSize == poolCfg.config.stablePoolResetSize,
  //         "Current reset size mismatch on reset size override"
  //       );

  //       return (true, overrides[i].targetResetSize);
  //     }
  //   }

  //   return (false, poolCfg.config.stablePoolResetSize);
  // }

  function isRedstonePowered(address rateFeedIdentifier) public view returns (bool) {
    return Arrays.contains(redstonePoweredFeeds(), rateFeedIdentifier);
  }

  function isChainlinkPowered(address rateFeedIdentifier) public view returns (bool) {
    return Arrays.contains(chainlinkPoweredFeeds(), rateFeedIdentifier);
  }

  function PHPUSDIdentifier() public pure returns (address) {
    return toRateFeedId("relayed:PHPUSD");
  }
}
