// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";
import { Arrays } from "script/utils/Arrays.sol";

/**
 * @dev This library contains the configuration required for the FX03 governance proposal.
 *      The following configuration is used:
 *     - 3 pools:
 *              - cCHF<->cUSD
 *              - cNGN<->cUSD
 *              - cJPY<->cUSD
 *
 *     - 3 rate feeds:
 *              - CHFUSD
 *              - NGNUSD
 *              - JPYUSD
 *
 *     - Configuration params needed to initialize all four tokens
 */
library FX03Config {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  struct FX03 {
    Config.Pool[] pools;
    Config.RateFeed CHFUSD;
    Config.RateFeed NGNUSD;
    Config.RateFeed JPYUSD;
    Config.RateFeed[] rateFeeds;
    Config.StableTokenV2 cCHFConfig;
    Config.StableTokenV2 cNGNConfig;
    Config.StableTokenV2 cJPYConfig;
    Config.StableTokenV2[] stableTokenConfigs;
    address payable[] stableTokenAddresses;
  }

  /**
   * @dev Returns the populated configuration object for the FX03 governance proposal.
   */
  function get(Contracts.Cache storage contracts) internal view returns (FX03 memory config) {
    config.pools = new Config.Pool[](3);
    config.pools[0] = cCHFcUSD_PoolConfig(contracts);
    config.pools[1] = cNGNcUSD_PoolConfig(contracts);
    config.pools[2] = cJPYcUSD_PoolConfig(contracts);

    config.rateFeeds = new Config.RateFeed[](3);
    config.rateFeeds[0] = CHFUSD_RateFeedConfig();
    config.rateFeeds[1] = NGNUSD_RateFeedConfig();
    config.rateFeeds[2] = JPYUSD_RateFeedConfig();

    config.stableTokenConfigs = new Config.StableTokenV2[](3);
    config.stableTokenConfigs[0] = stableTokenCHFConfig();
    config.stableTokenConfigs[1] = stableTokenNGNConfig();
    config.stableTokenConfigs[2] = stableTokenJPYConfig();

    config.stableTokenAddresses = new address payable[](3);
    config.stableTokenAddresses[0] = contracts.deployed("StableTokenCHFProxy");
    config.stableTokenAddresses[1] = contracts.deployed("StableTokenNGNProxy");
    config.stableTokenAddresses[2] = contracts.deployed("StableTokenJPYProxy");

    config.CHFUSD = CHFUSD_RateFeedConfig();
    config.NGNUSD = NGNUSD_RateFeedConfig();
    config.JPYUSD = JPYUSD_RateFeedConfig();

    config.cCHFConfig = stableTokenCHFConfig();
    config.cNGNConfig = stableTokenNGNConfig();
    config.cJPYConfig = stableTokenJPYConfig();
  }

  /* ==================== Rate Feed Configurations ==================== */

  /**
   * @dev Returns the default configuration for a MedianDeltaBreaker.
   */
  function getDefaultMedianDeltaBreakerConfig() internal pure returns (Config.MedianDeltaBreaker memory) {
    return
      Config.MedianDeltaBreaker({
        enabled: true,
        threshold: FixidityLib.newFixedFraction(4, 100), // 4%
        cooldown: 15 minutes,
        smoothingFactor: FixidityLib.newFixedFraction(5, 1000).unwrap() // 0.005
      });
  }

  /**
   * @dev Returns a RateFeed configuration for the specified rate feed ID.
   */
  function createRateFeedConfig(
    string memory rateFeedName
  ) internal pure returns (Config.RateFeed memory rateFeedConfig) {
    rateFeedConfig.rateFeedID = Config.rateFeedID(rateFeedName);
    rateFeedConfig.medianDeltaBreaker0 = getDefaultMedianDeltaBreakerConfig();
  }

  /**
   * @dev Returns the configuration for the CHFUSD rate feed.
   */
  function CHFUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory) {
    return createRateFeedConfig("relayed:CHFUSD");
  }

  /**
   * @dev Returns the configuration for the NGNUSD rate feed.
   */
  function NGNUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory) {
    return createRateFeedConfig("relayed:NGNUSD");
  }

  /**
   * @dev Returns the configuration for the JPYUSD rate feed.
   */
  function JPYUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory) {
    return createRateFeedConfig("relayed:JPYUSD");
  }

  /* ==================== Pool Configurations ==================== */

  /**
   * @dev Returns default trading limits for asset0 (cUSD)
   */
  function getDefaultAsset0Limits() internal pure returns (Config.TradingLimit memory) {
    return
      Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 200_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 1_000_000,
        enabledGlobal: true,
        limitGlobal: 5_000_000
      });
  }

  /**
   * @dev Returns trading limits for asset1 with explicit limit values
   */
  function getAsset1Limits(
    int48 asset1Limit0,
    int48 asset1Limit1,
    int48 asset1LimitGlobal
  ) internal pure returns (Config.TradingLimit memory) {
    return
      Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: asset1Limit0,
        enabled1: true,
        timeStep1: 1 days,
        limit1: asset1Limit1,
        enabledGlobal: true,
        limitGlobal: asset1LimitGlobal
      });
  }

  /**
   * @dev Creates a base pool configuration with explicit limit values
   */
  function createBasePoolConfig(
    Contracts.Cache storage contracts,
    address payable asset1,
    string memory rateFeedName,
    int48 asset1Limit0,
    int48 asset1Limit1,
    int48 asset1LimitGlobal
  ) internal view returns (Config.Pool memory poolConfig) {
    poolConfig = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: asset1,
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(3, 1000), // TODO: Confirm spread.
      referenceRateResetFrequency: 6 minutes,
      minimumReports: 1,
      stablePoolResetSize: 10_000_000 * 1e18,
      referenceRateFeedID: Config.rateFeedID(string(abi.encodePacked("relayed:", rateFeedName))),
      asset0limits: getDefaultAsset0Limits(),
      asset1limits: getAsset1Limits(asset1Limit0, asset1Limit1, asset1LimitGlobal)
    });
  }

  /**
   * @dev Returns the configuration for the cCHFcUSD pool.
   */
  function cCHFcUSD_PoolConfig(Contracts.Cache storage contracts) internal view returns (Config.Pool memory) {
    return
      createBasePoolConfig(
        contracts,
        contracts.deployed("StableTokenCHFProxy"),
        "CHFUSD",
        88 * 2_000,
        88 * 10_000,
        88 * 50_000
      );
  }

  /**
   * @dev Returns the configuration for the cNGNcUSD pool.
   */
  function cNGNcUSD_PoolConfig(Contracts.Cache storage contracts) internal view returns (Config.Pool memory) {
    return
      createBasePoolConfig(
        contracts,
        contracts.deployed("StableTokenNGNProxy"),
        "NGNUSD",
        1532 * 200_000,
        1532 * 1_000_000,
        1532 * 5_000_000
      );
  }

  /**
   * @dev Returns the configuration for the cJPYcUSD pool.
   */
  function cJPYcUSD_PoolConfig(Contracts.Cache storage contracts) internal view returns (Config.Pool memory) {
    return
      createBasePoolConfig(
        contracts,
        contracts.deployed("StableTokenJPYProxy"),
        "JPYUSD",
        149 * 200_000,
        149 * 1_000_000,
        149 * 5_000_000
      );
  }

  /* ==================== Stable Token Configurations ==================== */

  /**
   * @dev Returns the configuration for the cCHF stable token.
   */
  function stableTokenCHFConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "Celo Swiss Franc", symbol: "cCHF" });
  }

  /**
   * @dev Returns the configuration for the cNGN stable token.
   */
  function stableTokenNGNConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "Celo Nigerian Naira", symbol: "cNGN" });
  }

  /**
   * @dev Returns the configuration for the cJPY stable token.
   */
  function stableTokenJPYConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "Celo Japanese Yen", symbol: "cJPY" });
  }
}
