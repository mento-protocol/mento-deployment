// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";

library MU05Config {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  struct MU05 {
    Config.Pool cUSDUSDC;
    Config.Pool cEURUSDC;
    Config.Pool cBRLUSDC;
    Config.Pool cEURaxlUSDC;
    Config.Pool cBRLaxlUSDC;
    Config.Pool[] pools;
  }

  function get(Contracts.Cache storage contracts) internal returns (MU05 memory config) {
    config.pools = new Config.Pool[](5);
    config.pools[0] = config.cUSDUSDC = cUSDUSDC_PoolConfig(contracts);
    config.pools[1] = config.cEURUSDC = cEURUSDC_PoolConfig(contracts);
    config.pools[2] = config.cBRLUSDC = cBRLUSDC_PoolConfig(contracts);
    config.pools[3] = config.cEURaxlUSDC = cEURaxlUSDC_PoolConfig(contracts);
    config.pools[4] = config.cBRLaxlUSDC = cBRLaxlUSDC_PoolConfig(contracts);
  }

  function cUSDUSDC_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.dependency("NativeUSDC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(2, 10000), // 0.0002
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

  function cEURUSDC_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableTokenEUR"),
      asset1: contracts.dependency("NativeUSDC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      minimumReports: 5,
      stablePoolResetSize: 1_800_000 * 1e18, // 1.8 million
      referenceRateResetFrequency: 5 minutes,
      referenceRateFeedID: contracts.dependency("USDCEURRateFeedAddr"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 500_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 1_000_000,
        enabledGlobal: true,
        limitGlobal: 7_000_000
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cBRLUSDC_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableTokenBRL"),
      asset1: contracts.dependency("NativeUSDC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      minimumReports: 5,
      stablePoolResetSize: 1_800_000 * 1e18, // 1.8 million
      referenceRateResetFrequency: 5 minutes,
      referenceRateFeedID: contracts.dependency("USDCBRLRateFeedAddr"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 500_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 1_000_000,
        enabledGlobal: true,
        limitGlobal: 2_500_000
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cEURaxlUSDC_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
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
        limit0: 500_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 1_000_000,
        enabledGlobal: true,
        limitGlobal: 7_000_000
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cBRLaxlUSDC_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
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
        limit0: 500_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 1_000_000,
        enabledGlobal: true,
        limitGlobal: 2_500_000
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }
}
