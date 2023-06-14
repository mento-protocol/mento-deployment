// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { FixidityLib } from "mento-core/contracts/common/FixidityLib.sol";
import { console2 as console } from "forge-std/Script.sol";

import { Chain } from "script/utils/Chain.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { Arrays } from "script/utils/Arrays.sol";

library Config {
  using FixidityLib for FixidityLib.Fraction;
  using Contracts for Contracts.Cache;

  uint8 private constant L0 = 1; // 0b001 Limit0
  uint8 private constant L1 = 2; // 0b010 Limit1
  uint8 private constant LG = 4; // 0b100 LimitGlobal

  struct PoolConfiguration {
    /* ================================================================ */
    /* ==================== BiPool Exchange Config ==================== */
    /* ================================================================ */

    /**
     * @dev The address of the first asset in the pool, typically will be the mento stable.
     */
    address asset0;
    /**
     * @dev The address of the second asset in the pool.
     */
    address asset1;
    /**
     * @dev Flag indicating the pool is a constant sum pool.
     *      If false, the pool will use constant product pricing as default.
     */
    bool isConstantSum;
    /**
     * @dev The spread applied to the pool.
     */
    FixidityLib.Fraction spread;
    /**
     * @dev The frequency at which the reference rate is reset.
     *      This is used to determine bucket updates for the pool.
     */
    uint256 referenceRateResetFrequency;
    /**
     * @dev The ID of the reference oracle rate that's used to stabilize
     *      the pool.
     */
    address referenceRateFeedID;
    /**
     * @dev The minimum number of oracle reports that must be submitted for the reference rate.
     *      This is used to determine whether or not the buckets should upfate.
     */
    uint256 minimumReports;
    /**
     * @dev The size, in number of stable tokens, that stable buckets should be set to during bucket updates
     */
    uint256 stablePoolResetSize;
    /* ================================================================ */
    /* ==================== Circuit Breaker Config ==================== */
    /* ================================================================ */

    /******************************************/
    /********** Median Delta Breaker **********/
    /******************************************/

    /**
     * @dev This determines whether a MedianDeltaBreaker is enabled
     */
    bool isMedianDeltaBreakerEnabled;
    /**
     * @dev This determines the permitted deviation of the median report changes.
     *      The new median must fall within a range calculated based on this threshold
     *      to be considered valid. This range also affects whether the breaker will
     *      trigger or not. The threshold is stored as a FixidityLib.Fraction, with 24
     *      decimal places. When setting the value, it should be scaled by 10^24.
     *      For example, to set it to 0.1%, you would pass 100000000000000000000000 (0.1% * 10^24)
     */
    FixidityLib.Fraction medianDeltaBreakerThreshold;
    /**
     * @dev Time interval (in seconds) required before resetting the median delta
     *      breaker, calculated from the moment it was triggered for the pool to the present.
     */
    uint256 medianDeltaBreakerCooldown;
    /******************************************/
    /********** Value Delta Breaker ***********/
    /******************************************/

    /**
     * @dev This determines whether a MedianDeltaBreaker is enabled
     */
    bool isValueDeltaBreakerEnabled;
    /**
     * @dev  The allowed change in the new median relative to the reference value.
     *       This variable determines the range of acceptable values for the new median,
     *       which in turn affects whether the breaker will trigger or not. The range is
     *       represented as a FixidityLib.Fraction using 24 decimal places. To set the
     *       value to 0.8%, you need to pass 800000000000000000000000 (0.8% * 10^24)
     */
    FixidityLib.Fraction valueDeltaBreakerThreshold;
    /**
     * @dev The reference value used to calculate the value delta breakers allowed min and max threshold.
     *      This value has the same precision as the numerator of the median value, which is 24 decimal places.
     *      however the setter expects the value is already scaled by 10^24.
     *      So if you want to set the value to 1.0, you would pass in 1000000000000000000000000 (1.0 * 10^24).
     */
    uint256 valueDeltaBreakerReferenceValue;
    /**
     * @dev Time interval (in seconds) required before resetting the value delta
     *      breaker, calculated from the moment it was triggered for the pool to the present.
     */
    uint256 valueDeltaBreakerCooldown;
    /* ================================================================ */
    /* ==================== Trading Limit Config ==================== */
    /* ================================================================ */

    /**
     * @dev The time window in seconds for the L0 trading limit of asset0.
     */
    uint32 asset0_timeStep0;
    /**
     * @dev The time window in seconds for the L1 trading limit of asset0.
     */
    uint32 asset0_timeStep1;
    /**
     * @dev The maximum allowed netflow of asset0 for L0 within the time window.
     * The value is in unints, without any decimal places. See TradingLimit.sol for more details.
     */
    int48 asset0_limit0;
    /**
     * @dev The maximum allowed netflow of asset0 for L1 within the time window.
     * The value is in unints, without any decimal places. See TradingLimit.sol for more details.
     */
    int48 asset0_limit1;
    /**
     * @dev The maximum allowed netflow of asset0 for the lifetime of the limit.
     * The value is in unints, without any decimal places. See TradingLimit.sol for more details.
     */
    int48 asset0_limitGlobal;
    /**
     * @dev Configuration flags that can enable or disable the three different
     *      trading limits for asset 0.
     */
    uint8 asset0_flags;
  }

  /* ================================================================ */
  /* ==================== Partial Reserve Config ==================== */
  /* ================================================================ */
  struct PartialReserveConfiguration {
    /* ================================================================ */
    /* ==================== Unused/non relevant config ================ */
    /* ================================================================ */
    /**
      The parameters in this block are not relevant for the Partial Reserve integration with the broker 
      but will be taken from the existing Reserve contract to not have dummy values on a mainnet contract.
    */ 
    uint256 tobinTaxStalenessThreshold;
    bytes32[] assetAllocationSymbols;
    uint256[] assetAllocationWeights;
    uint256 tobinTax;
    uint256 tobinTaxReserveRatio;
    uint256 frozenGold; // not copied but should be set to 0
    uint256 frozenDays; // not copied but should be set to 0

    /* ================================================================ */
    /* ==================== Important/required config ================= */
    /* ================================================================ */
    /**
      The parameters in this block are relevant for the Partial Reserve integration with the broker
      and need to be customized.
    */

    /**
    * @dev The address of the celo registry
    */
    address registryAddress; 
    /**
    * @dev The % of Celo that can be spent per day by spenders (in fixidity format)
    */
    uint256 spendingRatioForCelo;
    /**
    * @dev The collateral assets of the Reserve (which are checked agains't assets of Exchanges by the broker)
    */
    address[] collateralAssets;
    /**
    * @dev The % of each collateral asset that can be spent per day by spenders (in fixidity format)
    */
    uint256[] collateralAssetDailySpendingRatios;
  }

  function partialReserveConfig(
    Contracts.Cache storage contracts
  ) internal returns (PartialReserveConfiguration memory config) {
    config = PartialReserveConfiguration({
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

  function cUSDCeloConfig(Contracts.Cache storage contracts, uint8 phase) internal returns (PoolConfiguration memory config) {
    require(phase >= 1 && phase <= 3, "phase must be 1, 2, or 3");
    config = PoolConfiguration({
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
      isValueDeltaBreakerEnabled: false,
      valueDeltaBreakerThreshold: FixidityLib.wrap(0),
      valueDeltaBreakerReferenceValue: 0,
      valueDeltaBreakerCooldown: 0,
      referenceRateFeedID: contracts.celoRegistry("StableToken"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: [10_000, 100_000, 500_000][phase - 1],
      asset0_limit1: [50_000, 500_000, 2_500_000][phase - 1],
      asset0_limitGlobal: 0,
      asset0_flags: L0 | L1
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cEURCeloConfig(Contracts.Cache storage contracts, uint8 phase) internal returns (PoolConfiguration memory config) {
    require(phase >= 1 && phase <= 3, "phase must be 1, 2, or 3");
    config = PoolConfiguration({
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
      isValueDeltaBreakerEnabled: false,
      valueDeltaBreakerThreshold: FixidityLib.wrap(0),
      valueDeltaBreakerReferenceValue: 0,
      valueDeltaBreakerCooldown: 0,
      referenceRateFeedID: contracts.celoRegistry("StableTokenEUR"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: [10_000, 100_000, 500_000][phase - 1],
      asset0_limit1: [50_000, 500_000, 2_500_000][phase - 1],
      asset0_limitGlobal: 0,
      asset0_flags: L0 | L1
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }
  
  function cBRLCeloConfig(Contracts.Cache storage contracts, uint8 phase) internal returns (PoolConfiguration memory config) {
    require(phase >= 1 && phase <= 3, "phase must be 1, 2, or 3");
    config = PoolConfiguration({
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
      isValueDeltaBreakerEnabled: false,
      valueDeltaBreakerThreshold: FixidityLib.wrap(0),
      valueDeltaBreakerReferenceValue: 0,
      valueDeltaBreakerCooldown: 0,
      referenceRateFeedID: contracts.celoRegistry("StableTokenBRL"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: [10_000, 100_000, 500_000][phase - 1],
      asset0_limit1: [50_000, 500_000, 2_500_000][phase - 1],
      asset0_limitGlobal: 0,
      asset0_flags: L0 | L1
    });
    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cUSDUSDCConfig(Contracts.Cache storage contracts, uint8 phase) internal returns (PoolConfiguration memory config) {
    require(phase >= 1 && phase <= 3, "phase must be 1, 2, or 3");
    config = PoolConfiguration({
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
      isValueDeltaBreakerEnabled: true,
      valueDeltaBreakerThreshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      valueDeltaBreakerReferenceValue: 1e24, // 1$ numerator for 1e24 denominator
      valueDeltaBreakerCooldown: 1 seconds,
      referenceRateFeedID: contracts.dependency("USDCUSDRateFeedAddr"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: [50_000, 500_000, 2_500_000][phase - 1],
      asset0_limit1: [100_000, 1_000_000, 5_000_000][phase - 1],
      asset0_limitGlobal: 0,
      asset0_flags: L0 | L1
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cEURUSDCConfig(Contracts.Cache storage contracts, uint8 phase) internal returns (PoolConfiguration memory config) {
    require(phase >= 1 && phase <= 3, "phase must be 1, 2, or 3");
    config = PoolConfiguration({
      asset0: contracts.celoRegistry("StableTokenEUR"),
      asset1: contracts.dependency("BridgedUSDC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      minimumReports: 5,
      referenceRateResetFrequency: 5 minutes,
      stablePoolResetSize: 1_800_000 * 1e18, // 12 million
      isMedianDeltaBreakerEnabled: false,
      medianDeltaBreakerThreshold: FixidityLib.wrap(0),
      medianDeltaBreakerCooldown: 0,
      isValueDeltaBreakerEnabled: true,
      smoothingFactor: 
      valueDeltaBreakerThreshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      valueDeltaBreakerReferenceValue: 1e24, // 1$ numerator for 1e24 denominator
      valueDeltaBreakerCooldown: 1 seconds,
      referenceRateFeedID: contracts.dependency("USDCEURRateFeedAddr"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: [10_000, 10_000, 500_000][phase - 1],
      asset0_limit1: [50_000, 50_000, 1_000_000][phase - 1],
      asset0_limitGlobal: [50_000, 5_000_000, 14_000_000][phase - 1]],
      asset0_flags: L0 | L1 | LG
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }

  function cBRLUSDCConfig(Contracts.Cache storage contracts, uint8 phase) internal returns (PoolConfiguration memory config) {
    require(phase >= 1 && phase <= 3, "phase must be 1, 2, or 3");
    config = PoolConfiguration({
      asset0: contracts.celoRegistry("StableTokenBRL"),
      asset1: contracts.dependency("BridgedUSDC"),
      isConstantSum: true,
      spread: FixidityLib.newFixedFraction(25, 10000), // 0.0025
      minimumReports: 5,
      referenceRateResetFrequency: 5 minutes,
      stablePoolResetSize: 1_800_000 * 1e18, // 12 million
      isMedianDeltaBreakerEnabled: false,
      medianDeltaBreakerThreshold: FixidityLib.wrap(0),
      medianDeltaBreakerCooldown: 0,
      isValueDeltaBreakerEnabled: true,
      smoothingFactor: 
      valueDeltaBreakerThreshold: FixidityLib.newFixedFraction(5, 1000), // 0.005
      valueDeltaBreakerReferenceValue: 1e24, // 1$ numerator for 1e24 denominator
      valueDeltaBreakerCooldown: 1 seconds,
      referenceRateFeedID: contracts.dependency("USDCEURRateFeedAddr"),
      asset0_timeStep0: 5 minutes,
      asset0_timeStep1: 1 days,
      asset0_limit0: [10_000, 10_000, 500_000][phase - 1],
      asset0_limit1: [50_000, 50_000, 1_000_000][phase - 1],
      asset0_limitGlobal: [50_000, 2_000_000, 5_000_000][phase - 1]],
      asset0_flags: L0 | L1 | LG
    });

    if (Chain.isBaklava() || Chain.isAlfajores()) {
      config.minimumReports = 2;
    }
  }
}
