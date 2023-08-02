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
    Config.Pool[] pools;
    Config.RateFeed CELOUSD;
    Config.RateFeed CELOEUR;
    Config.RateFeed CELOBRL;
    Config.RateFeed USDCUSD;
    Config.RateFeed USDCEUR;
    Config.RateFeed USDCBRL;
    Config.RateFeed[] rateFeeds;
  }

  function get(Contracts.Cache storage contracts) internal returns (MU03 memory config) {
    config.pools = new Config.Pool[](6);
    config.pools[0] = config.cUSDCelo = cUSDCelo_PoolConfig(contracts);
    config.pools[1] = config.cEURCelo = cEURCelo_PoolConfig(contracts);
    config.pools[2] = config.cBRLCelo = cBRLCelo_PoolConfig(contracts);
    config.pools[3] = config.cUSDUSDC = cUSDUSDC_PoolConfig(contracts);
    config.pools[4] = config.cEURUSDC = cEURUSDC_PoolConfig(contracts);
    config.pools[5] = config.cBRLUSDC = cBRLUSDC_PoolConfig(contracts);

    config.rateFeeds = new Config.RateFeed[](6);
    config.rateFeeds[0] = config.CELOUSD = CELOUSD_RateFeedConfig(contracts);
    config.rateFeeds[1] = config.CELOEUR = CELOEUR_RateFeedConfig(contracts);
    config.rateFeeds[2] = config.CELOBRL = CELOBRL_RateFeedConfig(contracts);
    config.rateFeeds[3] = config.USDCUSD = USDCUSD_RateFeedConfig(contracts);
    config.rateFeeds[4] = config.USDCEUR = USDCEUR_RateFeedConfig(contracts);
    config.rateFeeds[5] = config.USDCBRL = USDCBRL_RateFeedConfig(contracts);
  }


  


       

  function eXOFCelo_PoolConfig(Contracts.Cache storage contracts) internal view returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableTokenXOF"),
      asset1: contracts.celoRegistry("GoldToken"),
      isConstantSum: false,
      spread: FixidityLib.newFixedFraction(50, 10_000), // 0.0050
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 656 * 250_000 * 1e18, // 164 million
      referenceRateFeedID: contracts.celoRegistry("StableTokenBRL"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 656 * 10_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 656 * 50_000,
        enabledGlobal: true,
        limitGlobal: limitGlobal: 656 * 300_000
      }),
      asset1limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 20_000, // assuming Celo/EUR = 0.5
        enabled1: true,
        timeStep1: 1 days,
        limit1: 100_000, // assuming Celo/EUR = 0.5
        enabledGlobal: true,
        limitGlobal: limitGlobal: 600_000 // assuming Celo/EUR = 0.5
      })
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function CELOXOF_RateFeedConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.RateFeed memory config) {
    config.rateFeedID = contracts.celoRegistry("StableTokenXOF");
    config.medianDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      cooldown: 30 minutes,
      smoothingFactor: 0
    });
  }


  function eXOFEUROC_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.Pool memory config) {
    config = Config.Pool({
      asset0: contracts.celoRegistry("StableTokenEUR"),
      asset1: contracts.dependency("BridgedUSDC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      minimumReports: 5, 
      stablePoolResetSize: 656 * 1_000_000 * 1e18, // 656 * 1.0 million
      referenceRateResetFrequency: 5 minutes,
      referenceRateFeedID: contracts.dependency("USDCEURRateFeedAddr"),
      asset0limits: Config.TradingLimit({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 656 * 10_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 656 * 50_000,
        enabledGlobal: true,
        limitGlobal: 656 * 1_000_000
      }),
      asset1limits: Config.emptyTradingLimitConfig({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 10_000,
        enabled1: true,
        timeStep1: 1 days,
        limit1: 50_000,
        enabledGlobal: true,
        limitGlobal: 1_000_000
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function EUROCXOF_RateFeedConfig(Contracts.Cache storage contracts) internal returns (Config.RateFeed memory config) {
    config.rateFeedID = contracts.dependency("USDCEURRateFeedAddr");
    config.valueDeltaBreaker0 = Config.MedianDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      cooldown: 15 minutes,
      smoothingFactor: FixidityLib.newFixedFraction(5, 10000).unwrap()
    });
    config.valueDeltaBreaker1 = Config.ValueDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(10, 100), // 0.10
      cooldown: 999 years,
    });
    config.dependentRateFeeds = Arrays.addresses(contracts.dependency("EUROCEURRateFeedAddr"));
  }

  