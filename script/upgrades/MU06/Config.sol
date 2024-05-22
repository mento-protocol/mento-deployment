// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";

library MU06Config {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  struct MU06 {
    Config.Pool cUSDUSDC;
    Config.Pool cUSDUSDT;
    Config.Pool cUSDaxlUSDC;
    Config.Pool[] pools;
    Config.RateFeed rateFeedConfig;
  }

  /**
   * @dev Returns the populated configuration object for the MU06 governance proposal.
   */

  function get(Contracts.Cache storage contracts) internal returns (MU06 memory config) {
    config.pools = new Config.Pool[](3);
    config.pools[0] = config.cUSDUSDC = cUSDUSDC_PoolConfig(contracts);
    config.pools[1] = config.cUSDaxlUSDC = cUSDaxlUSDC_PoolConfig(contracts);
    config.pools[2] = config.cUSDUSDT = cUSDUSDT_PoolConfig(contracts);

    config.rateFeedConfig = USDTUSD_RateFeedConfig();
  }

  /* ==================== Rate Feed Configuration ==================== */

  /**
   * @dev Returns the configuration for the USDT/USD rate feed.
   */
  function USDTUSD_RateFeedConfig() internal pure returns (Config.RateFeed memory rateFeedConfig) {
    rateFeedConfig.rateFeedID = Config.rateFeedID("USDTUSD");
    rateFeedConfig.valueDeltaBreaker0 = Config.ValueDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      referenceValue: 1e24, // 1$ numerator for 1e24 denominator
      cooldown: 1 seconds
    });
  }

  /* ==================== Pool Configuration ==================== */

  function cUSDUSDC_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.dependency("NativeUSDC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(0, 1), // 0%
      minimumReports: 5,
      referenceRateResetFrequency: 5 minutes,
      stablePoolResetSize: 12_000_000 * 1e18, // 12 million
      referenceRateFeedID: contracts.dependency("USDCUSDRateFeedAddr"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 2_500_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 5_000_000,
        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  /**
   * @dev Returns the configuration for the cUSD/axlUSDC pool.
   */

  function cUSDaxlUSDC_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.dependency("BridgedUSDC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(0, 1), // 0%
      minimumReports: 5,
      referenceRateResetFrequency: 5 minutes,
      stablePoolResetSize: 12_000_000 * 1e18, // 12 million
      referenceRateFeedID: contracts.dependency("USDCUSDRateFeedAddr"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 2_500_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 5_000_000,
        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  /**
   * @dev Returns the configuration for the cUSD/USDT pool.
   */
  function cUSDUSDT_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.dependency("NativeUSDT"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(0, 1), // 0%
      minimumReports: 5,
      referenceRateResetFrequency: 5 minutes,
      stablePoolResetSize: 12_000_000 * 1e18, // 12 million
      referenceRateFeedID: Config.rateFeedID("USDTUSD"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 5_000_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 10_000_000,
        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }
}
