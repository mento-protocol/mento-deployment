// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Script as BaseScript, console2 } from "forge-std/Script.sol";
import { FixidityLib } from "mento-core/contracts/common/FixidityLib.sol";
import { Chain } from "./Chain.sol";
import { Contracts } from "./Contracts.sol";
import { GovernanceHelper } from "./GovernanceHelper.sol";
import { IPricingModule } from "mento-core/contracts/interfaces/IPricingModule.sol";

contract Script is BaseScript {
  using Contracts for Contracts.Cache;
  using FixidityLib for FixidityLib.Fraction;

  address public constant REGISTRY_ADDRESS = 0x000000000000000000000000000000000000ce10;

  Contracts.Cache public contracts;
}

contract GovernanceScript is Script, GovernanceHelper {
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
     * @dev The minimum number of oracle reports that must be submitted for the reference rate.
     *      This is used to determine whether or not the buckets should upfate.
     */
    uint256 minimumReports;
    /**
     * @dev The size the stable buckets should be set to during bucket updates
     */
    uint256 stablePoolResetSize;
    /* ================================================================ */
    /* ==================== Circuit Breaker Config ==================== */
    /* ================================================================ */

    /******************************************/
    /********** Median Delta Breaker **********/
    /******************************************/

    /**
     * @dev This determines the permitted deviation of the median report changes.
     *      The new median must fall within a range calculated based on this threshold
     *      to be considered valid. This range also affects whether the breaker will
     *      trigger or not. The threshold is stored as a FixidityLib.Fraction, with 24
     *      decimal places. When setting the value, it should be scaled by 10^24.
     *      For example, to set it to 0.1%, you would pass 100000000000000000000000 (0.1% * 10^24)
     */
    uint256 medianDeltaBreakerThreshold;
    /**
     * @dev Time interval (in seconds) required before resetting the median delta
     *      breaker, calculated from the moment it was triggered for the pool to the present.
     */
    uint256 medianDeltaBreakerCooldown;
    /******************************************/
    /********** Value Delta Breaker ***********/
    /******************************************/

    /**
     * @dev  The allowed change in the new median relative to the reference value.
     *       This variable determines the range of acceptable values for the new median,
     *       which in turn affects whether the breaker will trigger or not. The range is
     *       represented as a FixidityLib.Fraction using 24 decimal places. To set the
     *       value to 0.8%, you need to pass 800000000000000000000000 (081% * 10^24)
     */
    uint256 valueDeltaBreakerThreshold;
    /**
     * @dev The reference value used to calculate the value delta breakers allowed min and max threshold.
     *      This value is stored as a FixidityLib.Fraction, which uses 24 decimal places,
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
  }
}
