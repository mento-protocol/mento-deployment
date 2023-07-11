// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";

library MU03Config {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  function cUSDCelo_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.celoRegistry("GoldToken"),
      isConstantSum: false,

      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 7_200_000 * 1e18, // 7.2 million
      referenceRateFeedID: contracts.celoRegistry("StableToken"),

      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100000,

        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,

        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function CELOUSD_BreakerConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Breaker memory config) {
    config.rateFeedID = contracts.celoRegistry("StableToken");
    config.medianDeltaBreakers = new Config.MedianDeltaBreaker[](1);
    config.medianDeltaBreakers[0] = Config.MedianDeltaBreaker({
      threshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      cooldown: 30 minutes,
      smoothingFactor: 0
    });
  }

  function cEURCelo_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableTokenEUR"),
      asset1: contracts.celoRegistry("GoldToken"),
      isConstantSum: false,

      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 1_800_000 * 1e18, // 1.8 million
      referenceRateFeedID: contracts.celoRegistry("StableTokenEUR"),

      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: l00_000,

        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,

        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function CELOEUR_BreakerConfig(Contracts.Cache storage contracts) internal view returns (Config.Breaker memory config) {
    config.rateFeedID = contracts.celoRegistry("StableTokenEUR");
    config.medianDeltaBreakers = new Config.MedianDeltaBreaker[](1);
    config.medianDeltaBreakers[0] = Config.MedianDeltaBreaker({
      threshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      cooldown: 30 minutes,
      smoothingFactor: 0
    });
  }

  function cREALCelo_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableTokenBRL"),
      asset1: contracts.celoRegistry("GoldToken"),
      isConstantSum: false,

      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 3_000_000 * 1e18, // 3 million
      referenceRateFeedID: contracts.celoRegistry("StableTokenBRL"),

      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 100_000,

        enabled1: true,
        timeStep1: 1 days,
        limit1: 500_000,

        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function CELOBRL_BreakerConfig(Contracts.Cache storage contracts) internal view returns (Config.Breaker memory config) {
    config.rateFeedID = contracts.celoRegistry("StableTokenBRL");
    config.medianDeltaBreakers = new Config.MedianDeltaBreaker[](1);
    config.medianDeltaBreakers[0] = Config.MedianDeltaBreaker({
      threshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      cooldown: 30 minutes,
      smoothingFactor: 0
    });
  }

  function cUSDUSDC_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.dependency("BridgedUSDC"),
      isConstantSum: true,

      spread: FixidityLib.newFixedFraction(2, 10000), // 0.0002
      minimumReports: 5,
      referenceRateResetFrequency: 5 minutes,
      stablePoolResetSize: 12_000_000 * 1e18, // 12 million
      referenceRateFeedID: contracts.dependency("USDCUSDRateFeedAddr"),

      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 500_000,

        enabled1: true,
        timeStep1: 1 days,
        limit1: 1_000_000,

        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function USDCUSD_BreakerConfig(
    Contracts.Cache storage contracts
  ) internal returns (Config.Breaker memory config) {
    config.rateFeedID = contracts.dependency("USDCUSDRateFeedAddr");
    config.valueDeltaBreakers = new Config.ValueDeltaBreaker[](1);
    config.valueDeltaBreakers[0] = Config.ValueDeltaBreaker({
      threshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      referenceValue: 1e24, // 1$ numerator for 1e24 denominator
      cooldown: 1 seconds
    });
  }

  function cEURUSDCConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableTokenEUR"),
      asset1: contracts.dependency("BridgedUSDC"),
      isConstantSum: true,

      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      minimumReports: 5,
      stablePoolResetSize: 1_800_000 * 1e18, // 1.8 million
      referenceRateResetFrequency: 5 minutes,
      referenceRateFeedID: contracts.dependency("USDCEURRateFeedAddr"),

      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 10_000,

        enabled1: true,
        timeStep1: 1 days,
        limit1: 50_000,

        enabledGlobal: true,
        limitGlobal: 5_000_000
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function USDCEUR_BreakerConfig(Contracts.Cache storage contracts) internal view returns (Config.Breaker memory config) {
    config.rateFeedID = contracts.dependency("USDCEURRateFeedAddr");
    config.medianDeltaBreakers = new Config.MedianDeltaBreaker[](1);
    config.medianDeltaBreakers[0] = Config.MedianDeltaBreaker({
      threshold: FixidityLib.newFixedFraction(2, 100), // 0.02
      cooldown: 15 minutes,
      smoothingFactor: FixidityLib.newFixedFraction(5, 10000).unwrap()
    });
    config.dependentRateFeeds = Arrays.addresses(
      contracts.dependency("USDCUSDRateFeedAddr")
    );
  }

  function cBRLUSDCConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableTokenBRL"),
      asset1: contracts.dependency("BridgedUSDC"),
      isConstantSum: true,

      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      minimumReports: 5,
      stablePoolResetSize: 1_800_000 * 1e18, // 1.8 million
      referenceRateResetFrequency: 5 minutes,
      referenceRateFeedID: contracts.dependency("USDCBRLRateFeedAddr"),

      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 10_000,

        enabled1: true,
        timeStep1: 1 days,
        limit1: 50_000,

        enabledGlobal: true,
        limitGlobal: 2_000_000
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function USDCBRL_BreakerConfig(Contracts.Cache storage contracts) internal view returns (Config.Breaker memory config) {
    config.rateFeedID = contracts.dependency("USDCBRLRateFeedAddr");
    config.medianDeltaBreakers = new Config.MedianDeltaBreaker[](1);
    config.medianDeltaBreakers[0] = Config.MedianDeltaBreaker({
      threshold: FixidityLib.newFixedFraction(25, 1000), // 0.025
      cooldown: 15 minutes,
      smoothingFactor: FixidityLib.newFixedFraction(5, 10000).unwrap()
    });
    config.dependentRateFeeds = Arrays.addresses(
      contracts.dependency("USDCUSDRateFeedAddr")
    );
  }
}
