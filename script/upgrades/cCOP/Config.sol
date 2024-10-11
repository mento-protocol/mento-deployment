// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";

/**
 * @dev This library contains the configuration required for the cCOP governance proposal.
 *      The following configuration is used:
 *     - 1 pool: cCOP<->cUSD
 *     - 1 rate feed: COPUSD
 *     - Configuration params needed to initialize the cCOP stable token
 */
library cCOPConfig {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  struct cCOP {
    Config.Pool poolConfig;
    Config.RateFeed rateFeedConfig;
    Config.StableTokenV2 stableTokenConfig;
  }

  /**
   * @dev Returns the populated configuration object for the cCOP governance proposal.
   */
  function get(Contracts.Cache storage contracts) internal view returns (cCOP memory config) {
    config.poolConfig = cCOPcUSD_PoolConfig(contracts);
    config.rateFeedConfig = COPUSD_RateFeedConfig();
    config.stableTokenConfig = stableTokencCOPConfig();
  }

  /* ==================== Rate Feed Configuration ==================== */

  /**
   * @dev Returns the configuration for the COPUSD rate feed.
   */
  function COPUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory rateFeedConfig) {
    // TODO: Get confirmation for Roman that these are OK
    // These are the exact same as the $PUSO rate feed config
    rateFeedConfig.rateFeedID = Config.rateFeedID("relayed:COPUSD");
    rateFeedConfig.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(4, 100), // 4%
      cooldown: 15 minutes,
      smoothingFactor: FixidityLib.newFixedFraction(5, 1000).unwrap() // 0.005
    });
  }

  /* ==================== Pool Configuration ==================== */

  /**
   * @dev Returns the configuration for the cCOPcUSD pool.
   */
  function cCOPcUSD_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory poolConfig) {
    // TODO: Get confirmation from Roman that these are OK
    // These were taken from the $PUSO pool and adjusted to the COP/USD exchange rate,
    // which was 0.00023747 at the time of writing
    poolConfig = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.deployed("StableTokenCOPProxy"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(3, 1000), // 0.3%, in line with current DT of chainlink feed
      referenceRateResetFrequency: 6 minutes,
      minimumReports: 1,
      stablePoolResetSize: 10_000_000 * 1e18,
      referenceRateFeedID: Config.rateFeedID("relayed:COPUSD"),
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
        limit0: 4211 * 200_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 4211 * 1_000_000,
        enabledGlobal: true,
        limitGlobal: 4211 * 5_000_000
      })
    });
  }

  /* ==================== Stable Token Configuration ==================== */

  /**
   * @dev Returns the configuration for the cCOP stable token.
   */
  function stableTokencCOPConfig() internal pure returns (Config.StableTokenV2 memory config) {
    // TODO: Confirm the name of the currency with the Colombian DAO
    config = Config.StableTokenV2({ name: "Colombian Peso", symbol: "cCOP" });
  }
}
