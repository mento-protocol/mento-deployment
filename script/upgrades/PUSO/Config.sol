// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";

/**
 * @dev This library contains the configuration required for the PUSO governance proposal.
 *      The following configuration is used:
 *     - 1 pool: PUSO<->cUSD
 *     - 1 rate feed: PHPUSD
 *     - Configuration params needed to initialize the PUSO stable token
 */
library PUSOConfig {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  struct PUSO {
    Config.Pool poolConfig;
    Config.RateFeed rateFeedConfig;
    Config.StableTokenV2 stableTokenConfig;
  }

  /**
   * @dev Returns the populated configuration object for the PUSO governance proposal.
   */
  function get(Contracts.Cache storage contracts) internal view returns (PUSO memory config) {
    config.poolConfig = PUSOcUSD_PoolConfig(contracts);
    config.rateFeedConfig = PHPUSD_RateFeedConfig();
    config.stableTokenConfig = stableTokenPUSOConfig();
  }

  /* ==================== Rate Feed Configuration ==================== */

  /**
   * @dev Returns the configuration for the PHPUSD rate feed.
   */
  function PHPUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory rateFeedConfig) {
    rateFeedConfig.rateFeedID = Config.rateFeedID("PHPUSD");
    rateFeedConfig.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(4, 100), // 4%
      cooldown: 15 minutes,
      smoothingFactor: FixidityLib.newFixedFraction(5, 1000).unwrap() // 0.005
    });
  }

  /* ==================== Pool Configuration ==================== */

  /**
   * @dev Returns the configuration for the PUSOcUSD pool.
   */
  function PUSOcUSD_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory poolConfig) {
    poolConfig = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.deployed("StableTokenPUSOProxy"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(3, 1000), // 0.3%, in line with current DT of chainlink feed
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 1,
      stablePoolResetSize: 10_000_000 * 1e18,
      referenceRateFeedID: Config.rateFeedID("PHPUSD"),
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

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      poolConfig.minimumReports = 1;
    }
  }

  /* ==================== Stable Token Configuration ==================== */

  /**
   * @dev Returns the configuration for the PUSO stable token.
   */
  function stableTokenPUSOConfig() internal pure returns (Config.StableTokenV2 memory config) {
    config = Config.StableTokenV2({ name: "PUSO", symbol: "PUSO" });
  }
}
