// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;
import { Arrays } from "script/utils/Arrays.sol";

import { console2 } from "forge-std/console2.sol";
import { GovernanceScript } from "script/utils/Script.sol";
import { IBiPoolManager, FixidityLib } from "mento-core-2.5.0/interfaces/IBiPoolManager.sol";

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

  mapping(address => string) private rateFeedIdToName;

  address private CELOProxy;
  address private cUSDProxy;
  address private cEURProxy;
  address private cBRLProxy;
  address private eXOFProxy;
  address private cKESProxy;
  address private nativeUSDCProxy;
  address private nativeUSDTProxy;
  address private axlUSDCProxy;
  address private axlEUROCProxy;

  function load() public {
    contracts.load("cKES-00-Create-Proxies", "latest");
    contracts.load("eXOF-00-Create-Proxies", "latest");

    CELOProxy = contracts.celoRegistry("GoldToken");
    cUSDProxy = contracts.celoRegistry("StableToken");
    cEURProxy = contracts.celoRegistry("StableTokenEUR");
    cBRLProxy = contracts.celoRegistry("StableTokenBRL");
    eXOFProxy = contracts.deployed("StableTokenXOFProxy");
    cKESProxy = contracts.deployed("StableTokenKESProxy");
    nativeUSDCProxy = contracts.dependency("NativeUSDC");
    nativeUSDTProxy = contracts.dependency("NativeUSDT");
    axlUSDCProxy = contracts.dependency("BridgedUSDC");
    axlEUROCProxy = contracts.dependency("BridgedEUROC");

    setFeedsNames();
  }

  function setFeedsNames() public {
    rateFeedIdToName[cUSDProxy] = "CELO/USD";
    rateFeedIdToName[cEURProxy] = "CELO/EUR";
    rateFeedIdToName[cBRLProxy] = "CELO/BRL";
    rateFeedIdToName[eXOFProxy] = "CELO/XOF";
    rateFeedIdToName[cKESProxy] = "CELO/KES";
    rateFeedIdToName[toRateFeedId("USDCUSD")] = "USDC/USD";
    rateFeedIdToName[toRateFeedId("USDCEUR")] = "USDC/EUR";
    rateFeedIdToName[toRateFeedId("USDCBRL")] = "USDC/BRL";
    rateFeedIdToName[toRateFeedId("EUROCEUR")] = "EUROC/EUR";
    rateFeedIdToName[toRateFeedId("EUROCXOF")] = "EUROC/XOF";
    rateFeedIdToName[toRateFeedId("EURXOF")] = "EUR/XOF";
    rateFeedIdToName[toRateFeedId("KESUSD")] = "KES/USD";
    rateFeedIdToName[toRateFeedId("USDTUSD")] = "USDT/USD";
    rateFeedIdToName[toRateFeedId("relayed:EURUSD")] = "EUR/USD";
    rateFeedIdToName[toRateFeedId("relayed:BRLUSD")] = "BRL/USD";
    rateFeedIdToName[toRateFeedId("relayed:XOFUSD")] = "XOF/USD";
    rateFeedIdToName[toRateFeedId("relayed:PHPUSD")] = "PHP/USD";
  }

  function getFeedName(address rateFeedId) public view returns (string memory) {
    return rateFeedIdToName[rateFeedId];
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

    return feeds;
  }

  function additionalRelayersToWhitelist() public view returns (address[] memory) {
    // The following feeds will be used in the next proposal once we get rid of redundant pools
    // and route most all the stables through cUSD, so we will take the opportunity to whitelist them
    // ahead of the next proposal.
    address[] memory feeds = new address[](3);
    feeds[0] = toRateFeedId("relayed:EURUSD");
    feeds[1] = toRateFeedId("relayed:BRLUSD");
    feeds[2] = toRateFeedId("relayed:XOFUSD");
    return feeds;
  }

  function spreadOverrides() public view returns (SpreadOverride[] memory) {
    SpreadOverride[] memory overrides = new SpreadOverride[](8);
    // cUSD/nativeUSDC
    overrides[0] = SpreadOverride({
      asset0: cUSDProxy,
      asset1: nativeUSDCProxy,
      rateFeedId: toRateFeedId("USDCUSD"),
      currentSpread: FixidityLib.newFixed(0), // 0%
      targetSpread: FixidityLib.newFixedFraction(5, 10000) // 0.05%
    });
    // cUSD/axlUSDC
    overrides[1] = SpreadOverride({
      asset0: cUSDProxy,
      asset1: axlUSDCProxy,
      rateFeedId: toRateFeedId("USDCUSD"),
      currentSpread: FixidityLib.newFixed(0), // 0%
      targetSpread: FixidityLib.newFixedFraction(25, 10000) // 0.25%
    });
    // cEUR/axlUSDC
    overrides[2] = SpreadOverride({
      asset0: cEURProxy,
      asset1: axlUSDCProxy,
      rateFeedId: toRateFeedId("USDCEUR"),
      currentSpread: FixidityLib.newFixedFraction(25, 10000), // 0.25%
      targetSpread: FixidityLib.newFixedFraction(50, 10000) // 0.5%
    });
    // cREAL/axlUSDC
    overrides[3] = SpreadOverride({
      asset0: cBRLProxy,
      asset1: axlUSDCProxy,
      rateFeedId: toRateFeedId("USDCBRL"),
      currentSpread: FixidityLib.newFixedFraction(25, 10000), // 0.25%
      targetSpread: FixidityLib.newFixedFraction(50, 10000) // 0.5%
    });
    // cEUR/axlEUROC
    overrides[4] = SpreadOverride({
      asset0: cEURProxy,
      asset1: axlEUROCProxy,
      rateFeedId: toRateFeedId("EUROCEUR"),
      currentSpread: FixidityLib.newFixedFraction(2, 10000), // 0.02%
      targetSpread: FixidityLib.newFixedFraction(50, 10000) // 0.5%
    });
    // cUSD/USDT
    overrides[5] = SpreadOverride({
      asset0: cUSDProxy,
      asset1: nativeUSDTProxy,
      rateFeedId: toRateFeedId("USDTUSD"),
      currentSpread: FixidityLib.newFixed(0), // 0%
      targetSpread: FixidityLib.newFixedFraction(5, 10000) // 0.05%
    });
    // eXOF/CELO
    overrides[6] = SpreadOverride({
      asset0: eXOFProxy,
      asset1: CELOProxy,
      rateFeedId: eXOFProxy,
      currentSpread: FixidityLib.newFixedFraction(50, 10_000), // 0.5%
      targetSpread: FixidityLib.newFixedFraction(2, 100) // 2%
    });
    // eXOF/EUROC
    overrides[7] = SpreadOverride({
      asset0: eXOFProxy,
      asset1: axlEUROCProxy,
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

  function feedsToMigrate() public view returns (address[] memory) {
    return Arrays.merge(redstonePoweredFeeds(), chainlinkPoweredFeeds());
  }

  function shouldRecreateExchange(address rateFeedIdentifier) external view returns (bool) {
    return
      Arrays.contains(feedsToMigrate(), rateFeedIdentifier) ||
      // PHPUSD is already 1/1 and operated by Chainlink, however we want to re-create it to set
      // the bucket reset frequency to 6 minutes, since it's currently set to 5.
      isPHPUSD(rateFeedIdentifier);
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

    if (hasNewSpread(currentExchange)) {
      (FixidityLib.Fraction memory currentSpread, FixidityLib.Fraction memory targetSpread) = getCurrentAndTargetSpread(
        currentExchange
      );
      require(
        FixidityLib.equals(newExchange.config.spread, currentSpread),
        "❌ Current spread mismatch on spread override"
      );
      newExchange.config.spread = targetSpread;
    }

    if (hasNewResetSize(currentExchange)) {
      (uint256 currentResetSize, uint256 targetResetSize) = getCurrentAndTargetResetSizes(currentExchange);
      require(
        newExchange.config.stablePoolResetSize == currentResetSize,
        "❌ Current reset size mismatch on stable pool reset size override"
      );
      newExchange.config.stablePoolResetSize = targetResetSize;
    }

    return newExchange;
  }

  function hasNewSpread(IBiPoolManager.PoolExchange memory poolCfg) public view returns (bool) {
    SpreadOverride[] memory overrides = spreadOverrides();
    for (uint256 i = 0; i < overrides.length; i++) {
      if (overrides[i].asset0 == poolCfg.asset0 && overrides[i].asset1 == poolCfg.asset1) {
        require(
          overrides[i].rateFeedId == poolCfg.config.referenceRateFeedID,
          "Rate feed ID mismatch on spread override"
        );
        return true;
      }
    }

    return false;
  }

  function getCurrentAndTargetSpread(
    IBiPoolManager.PoolExchange memory poolCfg
  ) public view returns (FixidityLib.Fraction memory, FixidityLib.Fraction memory) {
    SpreadOverride[] memory overrides = spreadOverrides();
    for (uint256 i = 0; i < overrides.length; i++) {
      if (overrides[i].asset0 == poolCfg.asset0 && overrides[i].asset1 == poolCfg.asset1) {
        return (overrides[i].currentSpread, overrides[i].targetSpread);
      }
    }

    require(false, "getCurrentAndTargetSpread() called on a pool with no spread override");
  }

  function hasNewResetSize(IBiPoolManager.PoolExchange memory poolCfg) public view returns (bool) {
    StablePoolResetSizeOverride[] memory overrides = resetSizeOverrides();
    for (uint256 i = 0; i < overrides.length; i++) {
      if (overrides[i].asset0 == poolCfg.asset0 && overrides[i].asset1 == poolCfg.asset1) {
        require(
          overrides[i].rateFeedId == poolCfg.config.referenceRateFeedID,
          "Rate feed ID mismatch on reset size override"
        );
        return true;
      }
    }
    return false;
  }

  function getCurrentAndTargetResetSizes(
    IBiPoolManager.PoolExchange memory poolCfg
  ) public view returns (uint256, uint256) {
    StablePoolResetSizeOverride[] memory overrides = resetSizeOverrides();
    for (uint256 i = 0; i < overrides.length; i++) {
      if (overrides[i].asset0 == poolCfg.asset0 && overrides[i].asset1 == poolCfg.asset1) {
        return (overrides[i].currentResetSize, overrides[i].targetResetSize);
      }
    }

    require(false, "getCurrentAndTargetResetSizes() called on a pool with no reset size override");
  }

  function isRedstonePowered(address rateFeedIdentifier) public view returns (bool) {
    return Arrays.contains(redstonePoweredFeeds(), rateFeedIdentifier);
  }

  function isChainlinkPowered(address rateFeedIdentifier) public view returns (bool) {
    return Arrays.contains(chainlinkPoweredFeeds(), rateFeedIdentifier);
  }

  function isPHPUSD(address rateFeedIdentifier) public view returns (bool) {
    return toRateFeedId("relayed:PHPUSD") == rateFeedIdentifier;
  }

  function PHPUSDIdentifier() public pure returns (address) {
    return toRateFeedId("relayed:PHPUSD");
  }
}
