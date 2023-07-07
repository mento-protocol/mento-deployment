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

  uint8 private constant L0 = 1; // 0b001 Limit0
  uint8 private constant L1 = 2; // 0b010 Limit1
  uint8 private constant LG = 4; // 0b100 LimitGlobal

  function cUSDCeloConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.PoolConfiguration memory config) {
    config = Config.PoolConfiguration({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.celoRegistry("GoldToken"),
      isConstantSum: false,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 7_200_000 * 1e18, // 7.2 million
      isMedianDeltaBreakerEnabled: true,
      medianDeltaBreakerThreshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      medianDeltaBreakerCooldown: 30 minutes,
      smoothingFactor: 0,
      isValueDeltaBreakerEnabled: false,
      valueDeltaBreakerThreshold: FixidityLib.wrap(0),
      valueDeltaBreakerReferenceValue: 0,
      valueDeltaBreakerCooldown: 0,
      referenceRateFeedID: contracts.celoRegistry("StableToken"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: 100_000, // [10_000, 100_000, 500_000][phase - 1],
      asset0_limit1: 500_000, // [50_000, 500_000, 2_500_000][phase - 1],
      asset0_limitGlobal: 0,
      asset0_flags: L0 | L1
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cEURCeloConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.PoolConfiguration memory config) {
    config = Config.PoolConfiguration({
      asset0: contracts.celoRegistry("StableTokenEUR"),
      asset1: contracts.celoRegistry("GoldToken"),
      isConstantSum: false,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 1_800_000 * 1e18, // 1.8 million
      isMedianDeltaBreakerEnabled: true,
      medianDeltaBreakerThreshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      medianDeltaBreakerCooldown: 30 minutes,
      smoothingFactor: 0,
      isValueDeltaBreakerEnabled: false,
      valueDeltaBreakerThreshold: FixidityLib.wrap(0),
      valueDeltaBreakerReferenceValue: 0,
      valueDeltaBreakerCooldown: 0,
      referenceRateFeedID: contracts.celoRegistry("StableTokenEUR"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: 100_000, // [10_000, 100_000, 500_000][phase - 1],
      asset0_limit1: 500_000, // [50_000, 500_000, 2_500_000][phase - 1],
      asset0_limitGlobal: 0,
      asset0_flags: L0 | L1
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cBRLCeloConfig(
    Contracts.Cache storage contracts
  ) internal view returns (Config.PoolConfiguration memory config) {
    config = Config.PoolConfiguration({
      asset0: contracts.celoRegistry("StableTokenBRL"),
      asset1: contracts.celoRegistry("GoldToken"),
      isConstantSum: false,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 3_000_000 * 1e18, // 3 million
      isMedianDeltaBreakerEnabled: true,
      medianDeltaBreakerThreshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      medianDeltaBreakerCooldown: 30 minutes,
      smoothingFactor: 0,
      isValueDeltaBreakerEnabled: false,
      valueDeltaBreakerThreshold: FixidityLib.wrap(0),
      valueDeltaBreakerReferenceValue: 0,
      valueDeltaBreakerCooldown: 0,
      referenceRateFeedID: contracts.celoRegistry("StableTokenBRL"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: 100_000, // [10_000, 100_000, 500_000][phase - 1],
      asset0_limit1: 500_000, // [50_000, 500_000, 2_500_000][phase - 1],
      asset0_limitGlobal: 0,
      asset0_flags: L0 | L1
    });
    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cUSDUSDCConfig(Contracts.Cache storage contracts) internal returns (Config.PoolConfiguration memory config) {
    config = Config.PoolConfiguration({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.dependency("BridgedUSDC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(2, 10000), // 0.0002
      minimumReports: 5,
      referenceRateResetFrequency: 5 minutes,
      stablePoolResetSize: 12_000_000 * 1e18, // 12 million
      isMedianDeltaBreakerEnabled: false,
      medianDeltaBreakerThreshold: FixidityLib.wrap(0),
      medianDeltaBreakerCooldown: 0,
      smoothingFactor: 0,
      isValueDeltaBreakerEnabled: true,
      valueDeltaBreakerThreshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      valueDeltaBreakerReferenceValue: 1e24, // 1$ numerator for 1e24 denominator
      valueDeltaBreakerCooldown: 1 seconds,
      referenceRateFeedID: contracts.dependency("USDCUSDRateFeedAddr"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: 500_000, // [50_000, 500_000, 2_500_000][phase - 1],
      asset0_limit1: 1_000_000, // [100_000, 1_000_000, 5_000_000][phase - 1],
      asset0_limitGlobal: 0,
      asset0_flags: L0 | L1
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cEURUSDCConfig(Contracts.Cache storage contracts) internal returns (Config.PoolConfiguration memory config) {
    config = Config.PoolConfiguration({
      asset0: contracts.celoRegistry("StableTokenEUR"),
      asset1: contracts.dependency("BridgedUSDC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      minimumReports: 5,
      referenceRateResetFrequency: 5 minutes,
      stablePoolResetSize: 1_800_000 * 1e18, // 1.8 million
      isMedianDeltaBreakerEnabled: true,
      medianDeltaBreakerThreshold: FixidityLib.newFixedFraction(2, 100),
      medianDeltaBreakerCooldown: 15 minutes,
      smoothingFactor: FixidityLib.newFixedFraction(5, 10000).unwrap(),
      isValueDeltaBreakerEnabled: true,
      valueDeltaBreakerThreshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      valueDeltaBreakerReferenceValue: 1e24, // 1$ numerator for 1e24 denominator
      valueDeltaBreakerCooldown: 1 seconds,
      referenceRateFeedID: contracts.dependency("USDCEURRateFeedAddr"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: 10_000, // [10_000, 10_000, 500_000][phase - 1],
      asset0_limit1: 50_000, // [50_000, 50_000, 1_000_000][phase - 1],
      asset0_limitGlobal: 5_000_000, // [50_000, 5_000_000, 14_000_000][phase - 1],
      asset0_flags: L0 | L1 | LG
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cBRLUSDCConfig(Contracts.Cache storage contracts) internal returns (Config.PoolConfiguration memory config) {
    config = Config.PoolConfiguration({
      asset0: contracts.celoRegistry("StableTokenBRL"),
      asset1: contracts.dependency("BridgedUSDC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      minimumReports: 5,
      referenceRateResetFrequency: 5 minutes,
      stablePoolResetSize: 1_800_000 * 1e18, // 1.8 million
      isMedianDeltaBreakerEnabled: true,
      medianDeltaBreakerThreshold: FixidityLib.newFixedFraction(25, 1000), // 0.025
      medianDeltaBreakerCooldown: 15 minutes,
      smoothingFactor: FixidityLib.newFixedFraction(5, 10000).unwrap(), //0.0005 
      isValueDeltaBreakerEnabled: true,
      valueDeltaBreakerThreshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      valueDeltaBreakerReferenceValue: 1e24, // 1$ numerator for 1e24 denominator
      valueDeltaBreakerCooldown: 1 seconds,
      referenceRateFeedID: contracts.dependency("USDCBRLRateFeedAddr"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: 10_000, // [10_000, 10_000, 500_000][phase - 1],
      asset0_limit1: 50_000, // [50_000, 50_000, 1_000_000][phase - 1],
      asset0_limitGlobal: 2_000_000, // [50_000, 2_000_000, 5_000_000][phase - 1],
      asset0_flags: L0 | L1 | LG
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }
}
