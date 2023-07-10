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
        uint256(0.5 * 10 ** 24),
        uint256(0.1 * 10 ** 24),
        uint256(0.1 * 10 ** 24),
        uint256(0.295 * 10 ** 24),
        uint256(0.005 * 10 ** 24)
      ),
      tobinTax: FixidityLib.newFixed(0).unwrap(), // disabled
      tobinTaxReserveRatio: FixidityLib.newFixed(0).unwrap(), // disabled
      frozenGold: 0, // no frozen gold
      frozenDays: 0, // no frozen gold
      // ===== relevant parameters below
      registryAddress: address(0x000000000000000000000000000000000000ce10), // celo registry address
      spendingRatioForCelo: FixidityLib.fixed1().unwrap(), // 100% CELO spending
      // CELO and bridgedUSDC as collateral assets with 100% spending
      collateralAssets: Arrays.addresses(contracts.dependency("BridgedUSDC"), contracts.celoRegistry("GoldToken")),
      collateralAssetDailySpendingRatios: Arrays.uints(FixidityLib.fixed1().unwrap(), FixidityLib.fixed1().unwrap())
    });
  }

  function cUSDCelo_PoolConfig(
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
      referenceRateFeedID: contracts.celoRegistry("StableToken"),

      asset0limits: Config.TradingLimitConfig({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 10_000,

        enabled1: true,
        timeStep1: 1 days,
        limit1: 50_000,

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
  ) internal view returns (Config.RateFeedConfig memory config) {
    config.rateFeedID = contracts.celoRegistry("StableToken");
    config.medianDeltaBreakerConfigs = new Config.MedianDeltaBreakerConfig[](1);
    config.medianDeltaBreakerConfigs[0] = Config.MedianDeltaBreakerConfig({
      threshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      cooldown: 30 minutes,
      smoothingFactor: 0
    });
  }

  function cEURCelo_PoolConfig(
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
      referenceRateFeedID: contracts.celoRegistry("StableTokenEUR"),

      asset0limits: Config.TradingLimitConfig({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 10_000,

        enabled1: true,
        timeStep1: 1 days,
        limit1: 50_000,

        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function CELOEUR_RateFeedConfig(Contracts.Cache storage contracts) internal view returns (Config.RateFeedConfig memory config) {
    config.rateFeedID = contracts.celoRegistry("StableTokenEUR");
    config.medianDeltaBreakerConfigs = new Config.MedianDeltaBreakerConfig[](1);
    config.medianDeltaBreakerConfigs[0] = Config.MedianDeltaBreakerConfig({
      threshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      cooldown: 30 minutes,
      smoothingFactor: 0
    });
  }


  function cREALCelo_PoolConfig(
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
      referenceRateFeedID: contracts.celoRegistry("StableTokenBRL"),

      asset0limits: Config.TradingLimitConfig({
        enabled0: true,
        timeStep0: 5 minutes,
        limit0: 10_000,

        enabled1: true,
        timeStep1: 1 days,
        limit1: 50_000,

        enabledGlobal: false,
        limitGlobal: 0
      }),
      asset1limits: Config.emptyTradingLimitConfig()
    });
    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function CELOBRL_RateFeedConfig(Contracts.Cache storage contracts) internal view returns (Config.RateFeedConfig memory config) {
    config.rateFeedID = contracts.celoRegistry("StableTokenBRL");
    config.medianDeltaBreakerConfigs = new Config.MedianDeltaBreakerConfig[](1);
    config.medianDeltaBreakerConfigs[0] = Config.MedianDeltaBreakerConfig({
      threshold: FixidityLib.newFixedFraction(3, 100), // 0.03
      cooldown: 30 minutes,
      smoothingFactor: 0
    });
  }

  function cUSDUSDC_PoolConfig(Contracts.Cache storage contracts) internal returns (Config.PoolConfiguration memory config) {
    config = Config.PoolConfiguration({
      asset0: contracts.celoRegistry("StableToken"),
      asset1: contracts.dependency("BridgedUSDC"),
      isConstantSum: true,

      spread: FixidityLib.newFixedFraction(2, 10000), // 0.0002
      minimumReports: 5,
      referenceRateResetFrequency: 5 minutes,
      stablePoolResetSize: 12_000_000 * 1e18, // 12 million

      referenceRateFeedID: contracts.dependency("USDCUSDRateFeedAddr"),
      asset0limits: Config.TradingLimitConfig({
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

  function USDCUSD_RateFeedConfig(
    Contracts.Cache storage contracts
  ) internal returns (Config.RateFeedConfig memory config) {
    config.rateFeedID = contracts.dependency("USDCUSDRateFeedAddr");
    config.valueDeltaBreakerConfigs = new Config.ValueDeltaBreakerConfig[](1);
    config.valueDeltaBreakerConfigs[0] = Config.ValueDeltaBreakerConfig({
      threshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      referenceValue: 1e24, // 1$ numerator for 1e24 denominator
      cooldown: 1 seconds
    });
  }
}
