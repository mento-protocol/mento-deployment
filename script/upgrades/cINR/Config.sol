// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";

/**
 * @dev This library contains the configuration required for the cINR governance proposal.
 *      The following configuration is used:
 *     - 1 pool: cINR<->cUSD
 *     - 1 rate feed: INRUSD
 *     - Configuration params needed to initialize the cINR stable token
 */
library cINRConfig {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  struct cINR {
    Config.Pool poolConfig;
    Config.RateFeed rateFeedConfig;
    Config.StableTokenV2 stableTokenConfig;
  }

  /**
   * @dev Returns the populated configuration object for the cINR governance proposal.
   */
  function get(Contracts.Cache storage contracts) internal view returns (cINR memory config) {
    config.poolConfig = cINRcUSD_PoolConfig(contracts);
    config.rateFeedConfig = INRUSD_RateFeedConfig();
    config.stableTokenConfig = stableTokenINRConfig();
  }

  /* ==================== Rate Feed Configuration ==================== */

  /**
   * @dev Returns the configuration for the INRUSD rate feed.
   */
  function INRUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory rateFeedConfig) {
    rateFeedConfig.rateFeedID = Config.rateFeedID("INRUSD");
    rateFeedConfig.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: true, 
      threshold: FixidityLib.newFixedFraction(5, 1000), //  0.005
      cooldown: 15 minutes, 
      smoothingFactor: FixidityLib.newFixedFraction(5, 10000).unwrap() // 0.0005
    });
  }

  /* ==================== Pool Configuration ==================== */

  /**
   * @dev Returns the configuration for the cINRcUSD pool.
   */
  function cINRcUSD_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory poolConfig) {
    poolConfig = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.deployed("StableTokenINRProxy"),
      isConstantSum: true, 
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      referenceRateResetFrequency: 5 minutes, 
      minimumReports: 3, // assuming 5 oracle clients
      stablePoolResetSize: 10_000_000 * 1e18, //
      referenceRateFeedID: Config.rateFeedID("INRUSD"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,
        enabledGlobal: true,
        limitGlobal: 1_250_000
      }),
      asset1limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 84 * 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 84 * 500_000,
        enabledGlobal: true,
        limitGlobal: 84 * 1_250_000
      })
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      poolConfig.minimumReports = 2;
    }
  }

  /* ==================== Stable Token Configuration ==================== */

  /**
   * @dev Returns the configuration for the cINR stable token.
   */
  function stableTokenINRConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "Celo Indian Rupee ", symbol: "cINR" });
  }
}
