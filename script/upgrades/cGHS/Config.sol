// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";

/**
 * @dev This library contains the configuration required for the cGHS governance proposal.
 *      The following configuration is used:
 *     - 1 pool: cGHS<->cUSD
 *     - 1 rate feed: GHSUSD
 *     - Configuration params needed to initialize the cGHS stable token
 */
library cGHSConfig {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  struct cGHS {
    Config.Pool poolConfig;
    Config.RateFeed rateFeedConfig;
    Config.StableTokenV2 stableTokenConfig;
  }

  /**
   * @dev Returns the populated configuration object for the cGHS governance proposal.
   */
  function get(Contracts.Cache storage contracts) internal view returns (cGHS memory config) {
    config.poolConfig = cGHScUSD_PoolConfig(contracts);
    config.rateFeedConfig = GHSUSD_RateFeedConfig();
    config.stableTokenConfig = stableTokencGHSConfig();
  }

  /* ==================== Rate Feed Configuration ==================== */

  /**
   * @dev Returns the configuration for the GHSUSD rate feed.
   */
  function GHSUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory rateFeedConfig) {
    rateFeedConfig.rateFeedID = Config.rateFeedID("relayed:GHSUSD");
    rateFeedConfig.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(4, 100), // 4%
      cooldown: 15 minutes,
      smoothingFactor: FixidityLib.newFixedFraction(5, 1000).unwrap() // 0.005
    });
  }

  /* ==================== Pool Configuration ==================== */

  /**
   * @dev Returns the configuration for the cGHScUSD pool.
   */
  function cGHScUSD_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory poolConfig) {
    poolConfig = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.deployed("StableTokenGHSProxy"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(1, 100), // 1%, in line with current DT of chainlink feed
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 1,
      stablePoolResetSize: 10_000_000 * 1e18,
      referenceRateFeedID: Config.rateFeedID("relayed:GHSUSD"),
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
        limit0: 57 * 200_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 57 * 1_000_000,
        enabledGlobal: true,
        limitGlobal: 57 * 5_000_000
      })
    });
  }

  /* ==================== Stable Token Configuration ==================== */

  /**
   * @dev Returns the configuration for the cGHS stable token.
   */
  function stableTokencGHSConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "cGHS", symbol: "cGHS" });
  }
}
