// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console2 as console } from "forge-std/Script.sol";

import { FixidityLib } from "script/utils/FixidityLib.sol";
import { Chain } from "script/utils/Chain.sol";
import { Config } from "script/utils/Config.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Arrays } from "script/utils/Arrays.sol";

library MU01Config {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  uint8 private constant L0 = 1; // 0b001 Limit0
  uint8 private constant L1 = 2; // 0b010 Limit1
  uint8 private constant LG = 4; // 0b100 LimitGlobal

  function partialReserveConfig(
    Contracts.Cache storage contracts
  ) internal returns (Config.PartialReserveConfiguration memory config) {
    config = Config.PartialReserveConfiguration({
      // ===== not relevant parameters, copied from current mainnet Reserve.sol config
      tobinTaxStalenessThreshold: 3153600000, // 100 years
      assetAllocationSymbols: Arrays.bytes32s(
        bytes32("cGLD"),
        bytes32("BTC"),
        bytes32("ETH"),
        bytes32("DAI"),
        bytes32("cMCO2")
      ),
      assetAllocationWeights: Arrays.uints(
        uint256(0.5 * 10**24),
        uint256(0.1 * 10**24),
        uint256(0.1 * 10**24),
        uint256(0.295 * 10**24),
        uint256(0.005 * 10**24)
      ),
      tobinTax: FixidityLib.newFixed(0).unwrap(), // disabled
      tobinTaxReserveRatio: FixidityLib.newFixed(0).unwrap(), // disabled
      frozenGold: 0, // no frozen gold
      frozenDays: 0,  // no frozen gold

      // ===== relevant parameters below
      registryAddress: address(0x000000000000000000000000000000000000ce10), // celo registry address
      spendingRatioForCelo: FixidityLib.fixed1().unwrap(), // 100% CELO spending
      // CELO and bridgedUSDC as collateral assets with 100% spending
      collateralAssets: Arrays.addresses(
        contracts.dependency("BridgedUSDC"),
        contracts.celoRegistry("GoldToken")
      ),
      collateralAssetDailySpendingRatios: Arrays.uints(
        FixidityLib.fixed1().unwrap(), 
        FixidityLib.fixed1().unwrap()
      )
    });
  } 

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
      asset0_limit0: 10_000, // [10_000, 100_000, 500_000][phase - 1],
      asset0_limit1: 50_000, // [50_000, 500_000, 2_500_000][phase - 1],
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
      asset0_limit0: 10_000, // [10_000, 100_000, 500_000][phase - 1],
      asset0_limit1: 50_000, // [50_000, 500_000, 2_500_000][phase - 1],
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
      asset0_limit0: 10_000, // [10_000, 100_000, 500_000][phase - 1],
      asset0_limit1: 50_000, // [50_000, 500_000, 2_500_000][phase - 1],
      asset0_limitGlobal: 0,
      asset0_flags: L0 | L1
    });
    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cUSDUSDCConfig(
    Contracts.Cache storage contracts
  ) internal returns (Config.PoolConfiguration memory config) {
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
      asset0_limit0: 50_000, // [50_000, 500_000, 2_500_000][phase - 1],
      asset0_limit1: 100_000, // [100_000, 1_000_000, 5_000_000][phase - 1],
      asset0_limitGlobal: 0,
      asset0_flags: L0 | L1
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cEURUSDCConfig(
    Contracts.Cache storage contracts
  ) internal returns (Config.PoolConfiguration memory config) {
    config = Config.PoolConfiguration({
      asset0: contracts.celoRegistry("StableTokenEUR"),
      asset1: contracts.dependency("BridgedUSDC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      minimumReports: 5,
      referenceRateResetFrequency: 5 minutes,
      stablePoolResetSize: 1_800_000 * 1e18, // 1.8 million
      isMedianDeltaBreakerEnabled: false,
      medianDeltaBreakerThreshold: FixidityLib.wrap(0),
      medianDeltaBreakerCooldown: 0,
      smoothingFactor: 0,
      isValueDeltaBreakerEnabled: true,
      valueDeltaBreakerThreshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      valueDeltaBreakerReferenceValue: 1e24, // 1$ numerator for 1e24 denominator
      valueDeltaBreakerCooldown: 1 seconds,
      referenceRateFeedID: contracts.dependency("USDCEURRateFeedAddr"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: 10_000, // [10_000, 10_000, 500_000][phase - 1],
      asset0_limit1: 50_000, // [50_000, 50_000, 1_000_000][phase - 1],
      asset0_limitGlobal: 50_000, // [50_000, 5_000_000, 14_000_000][phase - 1],
      asset0_flags: L0 | L1 | LG
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cBRLUSDCConfig(
    Contracts.Cache storage contracts,
    uint8 phase
  ) internal returns (Config.PoolConfiguration memory config) {
    require(phase >= 1 && phase <= 3, "phase must be 1, 2, or 3");
    config = Config.PoolConfiguration({
      asset0: contracts.celoRegistry("StableTokenBRL"),
      asset1: contracts.dependency("BridgedUSDC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      minimumReports: 5,
      referenceRateResetFrequency: 5 minutes,
      stablePoolResetSize: 1_800_000 * 1e18, // 1.8 million
      isMedianDeltaBreakerEnabled: false,
      medianDeltaBreakerThreshold: FixidityLib.wrap(0),
      medianDeltaBreakerCooldown: 0,
      smoothingFactor: 0,
      isValueDeltaBreakerEnabled: true,
      valueDeltaBreakerThreshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      valueDeltaBreakerReferenceValue: 1e24, // 1$ numerator for 1e24 denominator
      valueDeltaBreakerCooldown: 1 seconds,
      referenceRateFeedID: contracts.dependency("USDCEURRateFeedAddr"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: 10_000, // [10_000, 10_000, 500_000][phase - 1],
      asset0_limit1: 50_000, // [50_000, 50_000, 1_000_000][phase - 1],
      asset0_limitGlobal: 50_000, // [50_000, 2_000_000, 5_000_000][phase - 1],
      asset0_flags: L0 | L1 | LG
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }
}
