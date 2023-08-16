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

  struct MU03 {
    Config.Pool cUSDCelo;
    Config.Pool cEURCelo;
    Config.Pool cBRLCelo;
    Config.Pool cUSDUSDC;
    Config.Pool cEURUSDC;
    Config.Pool cBRLUSDC;
    Config.Pool cEUREUROC;
    Config.Pool[] pools;
    Config.RateFeed CELOUSD;
    Config.RateFeed CELOEUR;
    Config.RateFeed CELOBRL;
    Config.RateFeed USDCUSD;
    Config.RateFeed USDCEUR;
    Config.RateFeed USDCBRL;
    Config.RateFeed EUROCEUR;
    Config.RateFeed[] rateFeeds;
  }

  function get(Contracts.Cache storage contracts) internal returns (MU03 memory config) {
    config.pools = new Config.Pool[](7);
    config.pools[0] = config.cUSDCelo = cUSDCelo_PoolConfig(contracts);
    config.pools[1] = config.cEURCelo = cEURCelo_PoolConfig(contracts);
    config.pools[2] = config.cBRLCelo = cBRLCelo_PoolConfig(contracts);
    config.pools[3] = config.cUSDUSDC = cUSDUSDC_PoolConfig(contracts);
    config.pools[4] = config.cEURUSDC = cEURUSDC_PoolConfig(contracts);
    config.pools[5] = config.cBRLUSDC = cBRLUSDC_PoolConfig(contracts);
    config.pools[6] = config.cEUREUROC = cEUREUROC_PoolConfig(contracts);

    config.rateFeeds = new Config.RateFeed[](7);
    config.rateFeeds[0] = config.CELOUSD = CELOUSD_RateFeedConfig(contracts);
    config.rateFeeds[1] = config.CELOEUR = CELOEUR_RateFeedConfig(contracts);
    config.rateFeeds[2] = config.CELOBRL = CELOBRL_RateFeedConfig(contracts);
    config.rateFeeds[3] = config.USDCUSD = USDCUSD_RateFeedConfig(contracts);
    config.rateFeeds[4] = config.USDCEUR = USDCEUR_RateFeedConfig(contracts);
    config.rateFeeds[5] = config.USDCBRL = USDCBRL_RateFeedConfig(contracts);
    config.rateFeeds[6] = config.EUROCEUR = EUROCEUR_RateFeedConfig(contracts);
  }

  function cUSDCelo_PoolConfig(Contracts.Cache storage contracts) internal view returns (Config.Pool memory config) {
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

  function CELOUSD_RateFeedConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.RateFeed memory config) {
    config.rateFeedID = contracts.celoRegistry("StableToken");
    config.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      cooldown: 30 minutes,
      smoothingFactor: 0
    });
  }

  function cEURCelo_PoolConfig(Contracts.Cache storage contracts) internal view returns (Config.Pool memory config) {
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

  function CELOEUR_RateFeedConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.RateFeed memory config) {
    config.rateFeedID = contracts.celoRegistry("StableTokenEUR");
    config.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      cooldown: 30 minutes,
      smoothingFactor: 0
    });
  }

  function cBRLCelo_PoolConfig(Contracts.Cache storage contracts) internal view returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableTokenBRL"),
      asset1: contracts.celoRegistry("GoldToken"),
      isConstantSum: false,
      spread: FixidityLib.newFixedFraction(25, 10_000), // 0.0025
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

  function CELOBRL_RateFeedConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.RateFeed memory config) {
    config.rateFeedID = contracts.celoRegistry("StableTokenBRL");
    config.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: true,
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

  function USDCUSD_RateFeedConfig(Contracts.Cache storage contracts) internal returns (Config.RateFeed memory config) {
    config.rateFeedID = contracts.dependency("USDCUSDRateFeedAddr");
    config.valueDeltaBreaker0 = Config.ValueDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      referenceValue: 1e24, // 1$ numerator for 1e24 denominator
      cooldown: 1 seconds
    });
  }

  function cEURUSDC_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
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

  function USDCEUR_RateFeedConfig(Contracts.Cache storage contracts) internal returns (Config.RateFeed memory config) {
    config.rateFeedID = contracts.dependency("USDCEURRateFeedAddr");
    config.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(2, 100), // 0.02
      cooldown: 15 minutes,
      smoothingFactor: FixidityLib.newFixedFraction(5, 10000).unwrap()
    });
    config.dependentRateFeeds = Arrays.addresses(contracts.dependency("USDCUSDRateFeedAddr"));
  }

  function cBRLUSDC_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
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

  function USDCBRL_RateFeedConfig(Contracts.Cache storage contracts) internal returns (Config.RateFeed memory config) {
    config.rateFeedID = contracts.dependency("USDCBRLRateFeedAddr");
    config.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(25, 1000), // 0.025
      cooldown: 15 minutes,
      smoothingFactor: FixidityLib.newFixedFraction(5, 10000).unwrap()
    });
    config.dependentRateFeeds = Arrays.addresses(contracts.dependency("USDCUSDRateFeedAddr"));
  }

  function cEUREUROC_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableTokenEUR"),
      asset1: contracts.dependency("BridgedEUROC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(2, 10000), // 0.0002
      minimumReports: 5,
      referenceRateResetFrequency: 5 minutes,
      stablePoolResetSize: 12_000_000 * 1e18, // 12 million
      referenceRateFeedID: contracts.dependency("EUROCEURRateFeedAddr"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 50_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 100_000,
        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function EUROCEUR_RateFeedConfig(Contracts.Cache storage contracts) internal returns (Config.RateFeed memory config) {
    config.rateFeedID = contracts.dependency("EUROCEURRateFeedAddr");
    config.valueDeltaBreaker0 = Config.ValueDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      referenceValue: 1e24, // 1€ numerator for 1e24 denominator
      cooldown: 1 seconds
    });
  }
}
