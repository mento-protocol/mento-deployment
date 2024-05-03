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
    config.stableTokenConfig = stableTokenCOPConfig();
  }

  /* ==================== Rate Feed Configuration ==================== */

  /**
   * @dev Returns the configuration for the COPUSD rate feed.
   */
  function COPUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory rateFeedConfig) {
    rateFeedConfig.rateFeedID = Config.rateFeedID("COPUSD");
    // TODO: Should be updated after config values have been finalized
    rateFeedConfig.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: false,
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
    // TODO: Should be updated after config values have been finalized
    poolConfig = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.deployed("StableTokenCOPProxy"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(1, 100), // 1%
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 10_0000_000,
      referenceRateFeedID: Config.rateFeedID("COPUSD"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 250_000,
        enabledGlobal: true,
        limitGlobal: 1_000_000
      }),
      asset1limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 3886 * 100_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 3886 * 250_000,
        enabledGlobal: true,
        limitGlobal: 3886 * 1_000_000
      })
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      poolConfig.minimumReports = 0;
    }
  }

  /* ==================== Stable Token Configuration ==================== */

  /**
   * @dev Returns the configuration for the cCOP stable token.
   */
  function stableTokenCOPConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "Celo Colombian Peso", symbol: "cCOP" });
  }
}
