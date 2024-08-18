// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console } from "forge-std/console.sol";

import { FixidityLib } from "script/utils/FixidityLib.sol";
import { Chain } from "script/utils/v1/Chain.sol";
import { Config } from "script/utils/v1/Config.sol";
import { Contracts } from "script/utils/v1/Contracts.sol";
import { Arrays } from "script/utils/v1/Arrays.sol";

library MU01Config {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  struct MU01 {
    Config.PartialReserve partialReserve;
    Config.Pool cUSDCelo;
    Config.Pool cEURCelo;
    Config.Pool cBRLCelo;
    Config.Pool cUSDUSDC;
    Config.Pool[] pools;
    Config.RateFeed CELOUSD;
    Config.RateFeed CELOEUR;
    Config.RateFeed CELOBRL;
    Config.RateFeed USDCUSD;
    Config.RateFeed[] rateFeeds;
  }

  function get(Contracts.Cache storage contracts) internal returns (MU01 memory config) {
    config.pools = new Config.Pool[](4);
    config.pools[0] = config.cUSDCelo = cUSDCelo_PoolConfig(contracts);
    config.pools[1] = config.cEURCelo = cEURCelo_PoolConfig(contracts);
    config.pools[2] = config.cBRLCelo = cBRLCelo_PoolConfig(contracts);
    config.pools[3] = config.cUSDUSDC = cUSDUSDC_PoolConfig(contracts);

    config.rateFeeds = new Config.RateFeed[](4);
    config.rateFeeds[0] = config.CELOUSD = CELOUSD_RateFeedConfig(contracts);
    config.rateFeeds[1] = config.CELOEUR = CELOEUR_RateFeedConfig(contracts);
    config.rateFeeds[2] = config.CELOBRL = CELOBRL_RateFeedConfig(contracts);
    config.rateFeeds[3] = config.USDCUSD = USDCUSD_RateFeedConfig(contracts);

    config.partialReserve = partialReserveConfig(contracts);
  }

  function partialReserveConfig(
    Contracts.Cache storage contracts
  ) internal returns (Config.PartialReserve memory config) {
    config = Config.PartialReserve({
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
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      referenceRateResetFrequency: 5 minutes,
      minimumReports: 5,
      stablePoolResetSize: 3_000_000 * 1e18, // 3 million
      referenceRateFeedID: contracts.celoRegistry("StableTokenBRL"),
      asset0limits: Config.TradingLimit({
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
      stablePoolResetSize: 12_000_000 * 1e18, // 12 million
      referenceRateResetFrequency: 5 minutes,
      referenceRateFeedID: contracts.dependency("USDCUSDRateFeedAddr"),
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

  function USDCUSD_RateFeedConfig(Contracts.Cache storage contracts) internal returns (Config.RateFeed memory config) {
    config.rateFeedID = contracts.dependency("USDCUSDRateFeedAddr");
    config.valueDeltaBreaker0 = Config.ValueDeltaBreaker({
      enabled: true,
      threshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      referenceValue: 1e24, // 1$ numerator for 1e24 denominator
      cooldown: 1 seconds
    });
  }
}
