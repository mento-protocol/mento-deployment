// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";

/**
 * @dev This library contains the configuration required for the cKES governance proposal.
 *      The following configuration is used:
 *     - 1 pool: cKES<->cUSD
 *     - 1 rate feed: KESUSD
 *     - Configuration params needed to initialize the cKES stable token
 */
library cKESConfig {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  struct cKES {
    Config.Pool cKEScUSDPool;
    Config.RateFeed KESUSDRateFeed;
    Config.StableTokenV2 stableTokenKES;
  }

  /**
   * @dev Returns the populated configuration object for the cKES governance proposal.
   */
  function get(Contracts.Cache storage contracts) internal view returns (cKES memory config) {
    config.cKEScUSDPool = cKEScUSD_PoolConfig(contracts);
    config.KESUSDRateFeed = KESUSD_RateFeedConfig();
    config.stableTokenKES = stableTokenKESConfig();
  }

  /* ==================== Rate Feed Configuration ==================== */

  /**
   * @dev Returns the configuration for the KESUSD rate feed.
   */
  function KESUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory rateFeedConfig) {
    rateFeedConfig.rateFeedID = Config.rateFeedID("KESUSD");
    // TODO: Should be updated after config values have been finalized
    rateFeedConfig.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: false,
      threshold: FixidityLib.newFixedFraction(1, 1),
      cooldown: 0 minutes,
      smoothingFactor: 1e1
    });
  }

  /* ==================== Pool Configuration ==================== */

  /**
   * @dev Returns the configuration for the cKEScUSD pool.
   */
  function cKEScUSD_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory poolConfig) {
    // TODO: Should be updated after config values have been finalized
    poolConfig = Config.Pool({
      asset0: contracts.deployed("StableTokenKESProxy"),
      asset1: contracts.celoRegistry("StableTokenProxy"),
      isConstantSum: false,
      spread: FixidityLib.newFixedFraction(1, 1),
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 0,
      stablePoolResetSize: 0,
      referenceRateFeedID: Config.rateFeedID("KESUSD"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 3886 * 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 3886 * 250_000,
        enabledGlobal: true,
        limitGlobal: 3886 * 1_000_000
      }),
      asset1limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 50_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 250_000,
        enabledGlobal: true,
        limitGlobal: 1_000_000
      })
    });

    // TODO: Should be updated after config values have been finalized
    if (Chain.isBaklava() || Chain.isAlfajores()) {
      poolConfig.minimumReports = 0;
    }
  }

  /* ==================== Stable Token Configuration ==================== */

  /**
   * @dev Returns the configuration for the cKES stable token.
   */
  function stableTokenKESConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "Celo Kenyan Shilling", symbol: "cKES" });
  }
}
