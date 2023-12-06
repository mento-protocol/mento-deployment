// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { FixidityLib } from "script/utils/FixidityLib.sol";

library MU04Config {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  struct MU04 {
    Config.Pool cUSDCelo;
    Config.Pool cEURCelo;
    Config.Pool cBRLCelo;
    Config.Pool cUSDUSDC;
    Config.Pool cEURUSDC;
    Config.Pool cBRLUSDC;
    Config.Pool cEUREUROC;
    Config.Pool eXOFCelo;
    Config.Pool eXOFEUROC;
    Config.Pool[] pools;
  }

  function get(Contracts.Cache storage contracts) internal returns (MU04 memory config) {
    config.pools = new Config.Pool[](9);
    config.pools[0] = config.cUSDCelo = cUSDCelo_PoolConfig(contracts);
    config.pools[1] = config.cEURCelo = cEURCelo_PoolConfig(contracts);
    config.pools[2] = config.cBRLCelo = cBRLCelo_PoolConfig(contracts);

    config.pools[3] = config.cUSDUSDC = cUSDUSDC_PoolConfig(contracts);
    config.pools[4] = config.cEURUSDC = cEURUSDC_PoolConfig(contracts);
    config.pools[5] = config.cBRLUSDC = cBRLUSDC_PoolConfig(contracts);
    config.pools[6] = config.cEUREUROC = cEUREUROC_PoolConfig(contracts);

    config.pools[7] = config.eXOFCelo = eXOFCelo_PoolConfig(contracts);
    config.pools[8] = config.eXOFEUROC = eXOFEUROC_PoolConfig(contracts);
  }

  function cUSDCelo_PoolConfig(Contracts.Cache storage contracts) internal view returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.celoRegistry("GoldToken"),
      isConstantSum: false,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 7_200_000 * 1e18, // 7.2 million ~ 720k with 10% slippage
      referenceRateFeedID: contracts.celoRegistry("StableToken"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 500_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 2_500_000,
        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cEURCelo_PoolConfig(Contracts.Cache storage contracts) internal view returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableTokenEUR"),
      asset1: contracts.celoRegistry("GoldToken"),
      isConstantSum: false,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 1_800_000 * 1e18, // 1.8 million ~ 180k with 10% slippage
      referenceRateFeedID: contracts.celoRegistry("StableTokenEUR"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 500_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 2_500_000,
        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cBRLCelo_PoolConfig(Contracts.Cache storage contracts) internal view returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableTokenBRL"),
      asset1: contracts.celoRegistry("GoldToken"),
      isConstantSum: false,
      spread: FixidityLib.newFixedFraction(25, 10_000), // 0.0025
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 3_000_000 * 1e18, // 3 million ~ 300k with 10% slippage
      referenceRateFeedID: contracts.celoRegistry("StableTokenBRL"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 500_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 2_500_000,
        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
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
        limitGlobal: 14_000_000
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
        limitGlobal: 5_000_000
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
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

  function eXOFCelo_PoolConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.Pool memory poolConfig) {
    poolConfig = Config.Pool({
      asset0: contracts.deployed("StableTokenXOFProxy"),
      asset1: contracts.celoRegistry("GoldToken"),
      isConstantSum: false,
      spread: FixidityLib.newFixedFraction(50, 10_000), // 0.0050
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 656 * 250_000 * 1e18, // 164 million ~ 16.4 million with 10% slippage
      referenceRateFeedID: contracts.deployed("StableTokenXOFProxy"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 656 * 10_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 656 * 50_000,
        enabledGlobal: true,
        limitGlobal: 656 * 300_000
      }),
      asset1limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 20_000, // assuming Celo/EUR = 0.5
        enabled1: true,
        timeStep1: 1 days,
        limit1: 100_000, // assuming Celo/EUR = 0.5
        enabledGlobal: true,
        limitGlobal: 600_000 // assuming Celo/EUR = 0.5
      })
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      poolConfig.minimumReports = 2;
    }
  }

  function eXOFEUROC_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory poolConfig) {
    poolConfig = Config.Pool({
      asset0: contracts.deployed("StableTokenXOFProxy"),
      asset1: contracts.dependency("BridgedEUROC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      minimumReports: 5,
      referenceRateResetFrequency: 5 minutes,
      stablePoolResetSize: 656 * 1_000_000 * 1e18, // 656 * 1.0 million
      referenceRateFeedID: Config.rateFeedID("EUROCXOF"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 656 * 50_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 656 * 250_000,
        enabledGlobal: true,
        limitGlobal: 656 * 2_000_000
      }),
      asset1limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 50_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 250_000,
        enabledGlobal: true,
        limitGlobal: 2_000_000
      })
    });
    if (Chain.isBaklava() || Chain.isAlfajores()) {
      poolConfig.minimumReports = 2;
    }
  }
}
