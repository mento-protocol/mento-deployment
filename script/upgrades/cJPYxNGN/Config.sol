// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";
import { Arrays } from "script/utils/Arrays.sol";

// TODO: Confirm symbol for the NGN and update accordingly
// TODO: Confirm pool and ratefeed configuratinos for both and update
// TODO: Confirm name for both tokens e.g. Celo... or Mento...

/**
 * @dev This library contains the configuration required for the cJPYxNGN governance proposal.
 *      The following configuration is used:
 *     - 2 pools:
 *              - cJPY<->cUSD
 *              - cNGN<->cUSD
 *     - 2 rate feeds:
 *              - JPYUSD
 *              - NGNUSD
 *     - Configuration params needed to initialize both tokens
 */
library cJPYxNGNConfig {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  struct cJPYxNGN {
    Config.Pool cJPYcUSD;
    Config.Pool cNGNcUSD;
    Config.Pool[] pools;
    Config.RateFeed JPYUSD;
    Config.RateFeed NGNUSD;
    Config.RateFeed[] rateFeeds;
    Config.StableTokenV2 cJPYConfig;
    Config.StableTokenV2 cNGNConfig;
    Config.StableTokenV2[] stableTokenConfigs;
    address[] stableTokenAddresses;
  }

  /**
   * @dev Returns the populated configuration object for the cJPYxNGN governance proposal.
   */
  function get(Contracts.Cache storage contracts) internal view returns (cJPYxNGN memory config) {
    config.pools = new Config.Pool[](2);
    config.pools[0] = cJPYcUSD_PoolConfig(contracts);
    config.pools[1] = cNGNcUSD_PoolConfig(contracts);

    config.rateFeeds = new Config.RateFeed[](2);
    config.rateFeeds[0] = JPYUSD_RateFeedConfig();
    config.rateFeeds[1] = NGNUSD_RateFeedConfig();

    config.stableTokenConfigs = new Config.StableTokenV2[](2);
    config.stableTokenConfigs[0] = stableTokenJPYConfig();
    config.stableTokenConfigs[1] = stableTokenNGNConfig();

    config.stableTokenAddresses = Arrays.addresses(
      contracts.deployed("StableTokenJPYProxy"),
      contracts.deployed("StableTokenNGNProxy")
    );
  }

  /* ==================== Rate Feed Configurations ==================== */

  /**
   * @dev Returns the configuration for the JPYUSD rate feed.
   */
  function JPYUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory rateFeedConfig) {
    rateFeedConfig.rateFeedID = Config.rateFeedID("JPYUSD");
    rateFeedConfig.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(4, 100), // 4%
      cooldown: 15 minutes,
      smoothingFactor: FixidityLib.newFixedFraction(5, 1000).unwrap() // 0.005
    });
  }

  /**
   * @dev Returns the configuration for the NGNUSD rate feed.
   */
  function NGNUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory rateFeedConfig) {
    rateFeedConfig.rateFeedID = Config.rateFeedID("NGNUSD");
    rateFeedConfig.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(4, 100), // 4%
      cooldown: 15 minutes,
      smoothingFactor: FixidityLib.newFixedFraction(5, 1000).unwrap() // 0.005
    });
  }

  /* ==================== Pool Configurations ==================== */

  /**
   * @dev Returns the configuration for the cJPYcUSD pool.
   */
  function cJPYcUSD_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory poolConfig) {
    poolConfig = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.deployed("StableTokenJPYProxy"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(3, 1000), // 0.3%
      referenceRateResetFrequency: 6 minutes,
      minimumReports: 1,
      stablePoolResetSize: 10_000_000 * 1e18,
      referenceRateFeedID: Config.rateFeedID("relayed:JPYUSD"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 200_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 1_000_000,
        enabledGlobal: true,
        limitGlobal: 5_000_000
      }),
      asset1limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 133 * 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 133 * 500_000,
        enabledGlobal: true,
        limitGlobal: 133 * 2_500_000
      })
    });
  }

  /**
   * @dev Returns the configuration for the cNGNcUSD pool.
   */
  function cNGNcUSD_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory poolConfig) {
    poolConfig = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.deployed("StableTokenNGNProxy"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(3, 1000), // 0.3%
      referenceRateResetFrequency: 6 minutes,
      minimumReports: 1,
      stablePoolResetSize: 10_000_000 * 1e18,
      referenceRateFeedID: Config.rateFeedID("relayed:NGNUSD"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 200_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 1_000_000,
        enabledGlobal: true,
        limitGlobal: 5_000_000
      }),
      asset1limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 133 * 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 133 * 500_000,
        enabledGlobal: true,
        limitGlobal: 133 * 2_500_000
      })
    });
  }

  /* ==================== Stable Token Configurations ==================== */

  /**
   * @dev Returns the configuration for the cJPY stable token.
   */
  function stableTokenJPYConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "Celo Japanese Yen", symbol: "cJPY" });
  }

  /**
   * @dev Returns the configuration for the cNGN stable token.
   */
  function stableTokenNGNConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "Celo Nigerian Naira", symbol: "cNGN" });
  }
}
