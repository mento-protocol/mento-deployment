// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";

/**
 * @dev This library contains the configuration required for the cPHP governance proposal.
 *      The following configuration is used:
 *     - 1 pool: cPHP<->cUSD
 *     - 1 rate feed: PHPUSD
 *     - Configuration params needed to initialize the cPHP stable token
 */
library cPHPConfig {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  struct cPHP {
    Config.Pool poolConfig;
    Config.RateFeed rateFeedConfig;
    Config.StableTokenV2 stableTokenConfig;
  }

  /**
   * @dev Returns the populated configuration object for the cPHP governance proposal.
   */
  function get(Contracts.Cache storage contracts) internal view returns (cPHP memory config) {
    config.poolConfig = cPHPcUSD_PoolConfig(contracts);
    config.rateFeedConfig = PHPUSD_RateFeedConfig();
    config.stableTokenConfig = stableTokenPHPConfig();
  }

  /* ==================== Rate Feed Configuration ==================== */

  /**
   * @dev Returns the configuration for the PHPUSD rate feed.
   */
  function PHPUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory rateFeedConfig) {
    rateFeedConfig.rateFeedID = Config.rateFeedID("PHPUSD");
    rateFeedConfig.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: true, // TODO
      threshold: FixidityLib.newFixedFraction(0, 0), // TODO
      cooldown: 0, // TODO
      smoothingFactor: FixidityLib.newFixedFraction(0, 0).unwrap() // TODO
    });
  }

  /* ==================== Pool Configuration ==================== */

  /**
   * @dev Returns the configuration for the cPHPcUSD pool.
   */
  function cPHPcUSD_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory poolConfig) {
    poolConfig = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.deployed("StableTokenPHPProxy"),
      isConstantSum: true, //TODO
      spread: FixidityLib.newFixedFraction(0, 0), //TODO
      referenceRateResetFrequency: 0, //TODO
      minimumReports: 0, //TODO
      stablePoolResetSize: 0, //TODO
      referenceRateFeedID: Config.rateFeedID("PHPUSD"),
      asset0limits: Config.TradingLimit({
        enabled0: true, //TODO
        timeStep0: 0, //TODO
        limit0: 0, //TODO
        enabled1: true, //TODO
        timeStep1: 0, //TODO
        limit1: 0, //TODO
        enabledGlobal: true, //TODO
        limitGlobal: 0 //TODO
      }),
      asset1limits: Config.TradingLimit({
        enabled0: true, //TODO
        timeStep0: 0, //TODO
        limit0: 0, //TODO
        enabled1: true, //TODO
        timeStep1: 1 days,
        limit1: 0, //TODO
        enabledGlobal: true, //TODO
        limitGlobal: 0 //TODO
      })
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      poolConfig.minimumReports = 2;
    }
  }

  /* ==================== Stable Token Configuration ==================== */

  /**
   * @dev Returns the configuration for the cPHP stable token.
   */
  function stableTokenPHPConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "Celo Philippine Peso  ", symbol: "cPHP" });
  }
}