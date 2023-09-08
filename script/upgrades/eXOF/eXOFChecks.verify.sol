// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console2 as console } from "forge-std/Script.sol";

import { Arrays } from "script/utils/Arrays.sol";

import { IFeeCurrencyWhitelist } from "script/interfaces/IFeeCurrencyWhitelist.sol";
import { ICeloGovernance } from "script/interfaces/ICeloGovernance.sol";

import { IRegistry } from "mento-core-2.2.0/common/interfaces/IRegistry.sol";
import { IBiPoolManager } from "mento-core-2.2.0/interfaces/IBiPoolManager.sol";
import { IERC20Metadata } from "mento-core-2.2.0/common/interfaces/IERC20Metadata.sol";

import { StableTokenXOF } from "mento-core-2.2.0/legacy/StableTokenXOF.sol";
import { StableTokenXOFProxy } from "mento-core-2.2.0/legacy/proxies/StableTokenXOFProxy.sol";
import { MedianDeltaBreaker } from "mento-core-2.2.0/oracles/breakers/MedianDeltaBreaker.sol";
import { ValueDeltaBreaker } from "mento-core-2.2.0/oracles/breakers/ValueDeltaBreaker.sol";
import { Reserve } from "mento-core-2.2.0/swap/Reserve.sol";
import { BiPoolManager } from "mento-core-2.2.0/swap/BiPoolManager.sol";
import { TradingLimits } from "mento-core-2.2.0/libraries/TradingLimits.sol";
import { BreakerBox } from "mento-core-2.2.0/oracles/BreakerBox.sol";
import { Proxy } from "mento-core-2.2.0/common/Proxy.sol";

import { eXOFChecksBase } from "./eXOFChecks.base.sol";
import { eXOFConfig, Config } from "./Config.sol";

/**
 * @title IBrokerWithCasts
 * @notice Interface for Broker with tuple -> struct casting
 * @dev This is used to access the internal trading limits
 * config as a struct as opposed to a tuple.
 */
interface IBrokerWithCasts {
  function tradingLimitsConfig(bytes32 id) external view returns (TradingLimits.Config memory);
}

contract eXOFChecksVerify is eXOFChecksBase {
  using TradingLimits for TradingLimits.Config;

  uint256 constant PRE_EXISTING_POOLS = 7;

  ICeloGovernance celoGovernance;

  constructor() public {
    setUp();
    celoGovernance = ICeloGovernance(governance);
  }

  function run() public {
    eXOFConfig.eXOF memory config = eXOFConfig.get(contracts);
    console.log("\nStarting eXOF checks:");

    console.log("\n==  Information");
    console.log("   EUROCXOF: %s", config.EUROCXOF.rateFeedID);
    console.log("   EURXOF: %s", config.EURXOF.rateFeedID);
    console.log("   CELOXOF: %s", config.CELOXOF.rateFeedID);

    verifyToken(config);
    verifyExchanges(config);
    verifyCircuitBreaker(config);
  }

  function verifyToken(eXOFConfig.eXOF memory config) internal {
    console.log("\n== Verifying Token Transactions ==");
    verifyOwner();
    verifyEXOFStableToken();
    verifyConstitution(config);
    verifyEXOFAddedToReserve();
    verifyEXOFAddedToFeeCurrencyWhitelist();
  }

  function verifyOwner() internal view {
    address eXOFImplementation = contracts.deployed("StableTokenXOF");
    require(
      StableTokenXOF(eXOFImplementation).owner() == governance,
      "StableTokenXOF ownership not transferred to governance"
    );

    require(Proxy(eXOF)._getOwner() == governance, "StableTokenXOF Proxy ownership not transferred to governance");

    console.log("🟢 Contract ownerships transferred to governance");
  }

  function verifyEXOFStableToken() internal view {
    StableTokenXOFProxy stableTokenXOFProxy = StableTokenXOFProxy(eXOF);
    address eXOFDeployedImplementation = contracts.deployed("StableTokenXOF");

    address eXOFImplementation = stableTokenXOFProxy._getImplementation();
    if (eXOFImplementation != eXOFDeployedImplementation) {
      console.log(
        "The implementation from StableTokenXOFProxy: %s does not match the deployed address: %s.",
        eXOFImplementation,
        eXOFDeployedImplementation
      );
      revert("Deployed StableTokenXOF does not match what proxy points to. See logs.");
    }
    console.log("🟢 StableTokenXOFProxy has the correct implementation address");
  }

  function verifyEXOFAddedToReserve() internal view {
    if (!Reserve(address(uint160(partialReserve))).isStableAsset(eXOF)) {
      revert("eXOF has not been added to the partial reserve.");
    }

    console.log("🟢 eXOF has been added to the reserve");
  }

  function verifyEXOFAddedToFeeCurrencyWhitelist() internal view {
    address[] memory feeCurrencyWhitelist = IFeeCurrencyWhitelist(contracts.celoRegistry("FeeCurrencyWhitelist"))
      .getWhitelist();

    if (!Arrays.contains(feeCurrencyWhitelist, eXOF)) {
      revert("eXOF has not been added to the fee currency whitelist.");
    }

    console.log("🟢 eXOF has been added to the fee currency whitelist");
  }

  function verifyConstitution(eXOFConfig.eXOF memory config) internal {
    bytes4[] memory functionSelectors = config.stableTokenXOF.constitutionFunctionSelectors;
    uint256[] memory expectedThresholdValues = config.stableTokenXOF.constitutionThresholds;

    for (uint256 i = 0; i < functionSelectors.length; i++) {
      bytes4 selector = functionSelectors[i];
      uint256 expectedValue = expectedThresholdValues[i];

      checkConstitutionParam(selector, expectedValue);
    }

    console.log("🟢 Constitution params configured correctly");
  }

  function checkConstitutionParam(bytes4 functionSelector, uint256 expectedValue) internal view {
    uint256 actualConstitutionValue = celoGovernance.getConstitution(eXOF, functionSelector);

    if (actualConstitutionValue != expectedValue) {
      console.log(
        "The constitution value for function selector: %s is not set correctly. Expected: %s, Actual: %s",
        bytes4ToStr(functionSelector),
        expectedValue,
        actualConstitutionValue
      );
      revert("Constitution value not set correctly. See logs.");
    }
  }

  function verifyExchanges(eXOFConfig.eXOF memory config) internal {
    console.log("\n== Verifying exchanges ==");

    verifyPoolExchange(config);
    verifyPoolConfig(config);
    verifyTradingLimits(config);
  }

  function verifyPoolExchange(eXOFConfig.eXOF memory config) internal view {
    bytes32[] memory exchanges = BiPoolManager(biPoolManagerProxy).getExchangeIds();

    // check configured pools against the config
    require(
      exchanges.length == config.pools.length + PRE_EXISTING_POOLS,
      "Number of expected pools does not match the number of deployed pools."
    );

    for (uint256 i = 0; i < config.pools.length; i++) {
      bytes32 exchangeId = getExchangeId(config.pools[i].asset0, config.pools[i].asset1, config.pools[i].isConstantSum);

      IBiPoolManager.PoolExchange memory pool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
      Config.Pool memory poolConfig = config.pools[i];

      // verify asset0 of the deployed pool against the config
      if (pool.asset0 != poolConfig.asset0) {
        console.log(
          "The asset0 of deployed pool: %s does not match the expected asset0: %s.",
          pool.asset0,
          poolConfig.asset0
        );
        revert("asset0 of pool does not match the expected asset0. See logs.");
      }

      // verify asset1 of the deployed pool against the config
      if (pool.asset1 != poolConfig.asset1) {
        console.log(
          "The asset1 of deployed pool: %s does not match the expected asset1: %s.",
          pool.asset1,
          poolConfig.asset1
        );
        revert("asset1 of pool does not match the expected asset1. See logs.");
      }

      if (poolConfig.isConstantSum) {
        if (address(pool.pricingModule) != constantSum) {
          console.log(
            "The pricing module of deployed pool: %s does not match the expected pricing module: %s.",
            address(pool.pricingModule),
            constantSum
          );
          revert("pricing module of pool does not match the expected pricing module. See logs.");
        }
      } else {
        if (address(pool.pricingModule) != constantProduct) {
          console.log(
            "The pricing module of deployed pool: %s does not match the expected pricing module: %s.",
            address(pool.pricingModule),
            constantProduct
          );
          revert("pricing module of pool does not match the expected pricing module. See logs.");
        }
      }
      // verify asset0 is always a stable asset
      require(
        pool.asset0 == cUSD || pool.asset0 == cEUR || pool.asset0 == cBRL || pool.asset0 == eXOF,
        "asset0 is not a stable asset in the exchange"
      );
      // verify asset1 is always a collateral asset
      require(
        pool.asset1 == celoToken || pool.asset1 == bridgedUSDC || pool.asset1 == bridgedEUROC,
        "asset1 is not CELO or bridgedUSDC or bridgedEUROC in the exchange"
      );
    }
    console.log("🟢 PoolExchange correctly configured 🤘🏼");
  }

  function verifyPoolConfig(eXOFConfig.eXOF memory config) internal view {
    for (uint256 i = 0; i < config.pools.length; i++) {
      bytes32 exchangeId = getExchangeId(config.pools[i].asset0, config.pools[i].asset1, config.pools[i].isConstantSum);
      IBiPoolManager.PoolExchange memory deployedPool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
      Config.Pool memory expectedPoolConfig = config.pools[i];

      if (deployedPool.config.spread.unwrap() != expectedPoolConfig.spread.unwrap()) {
        console.log(
          "The spread of deployed pool: %s does not match the expected spread: %s.",
          deployedPool.config.spread.unwrap(),
          expectedPoolConfig.spread.unwrap()
        );
        revert("spread of pool does not match the expected spread. See logs.");
      }

      if (deployedPool.config.referenceRateFeedID != expectedPoolConfig.referenceRateFeedID) {
        console.log(
          "The referenceRateFeedID of deployed pool: %s does not match the expected referenceRateFeedID: %s.",
          deployedPool.config.referenceRateFeedID,
          expectedPoolConfig.referenceRateFeedID
        );
        revert("referenceRateFeedID of pool does not match the expected referenceRateFeedID. See logs.");
      }

      if (deployedPool.config.minimumReports != expectedPoolConfig.minimumReports) {
        console.log(
          "The minimumReports of deployed pool: %s does not match the expected minimumReports: %s.",
          deployedPool.config.minimumReports,
          expectedPoolConfig.minimumReports
        );
        revert("minimumReports of pool does not match the expected minimumReports. See logs.");
      }

      if (deployedPool.config.referenceRateResetFrequency != expectedPoolConfig.referenceRateResetFrequency) {
        console.log(
          "The referenceRateResetFrequency of deployed pool: %s does not match the expected: %s.",
          deployedPool.config.referenceRateResetFrequency,
          expectedPoolConfig.referenceRateResetFrequency
        );
        revert(
          "referenceRateResetFrequency of pool does not match the expected referenceRateResetFrequency. See logs."
        );
      }

      if (deployedPool.config.stablePoolResetSize != expectedPoolConfig.stablePoolResetSize) {
        console.log(
          "The stablePoolResetSize of deployed pool: %s does not match the expected stablePoolResetSize: %s.",
          deployedPool.config.stablePoolResetSize,
          expectedPoolConfig.stablePoolResetSize
        );
        revert("stablePoolResetSize of pool does not match the expected stablePoolResetSize. See logs.");
      }
    }
    console.log("🟢 Pool config is correctly configured 🤘🏼");
  }

  function verifyTradingLimits(eXOFConfig.eXOF memory config) internal view {
    IBrokerWithCasts _broker = IBrokerWithCasts(address(broker));

    for (uint256 i = 0; i < config.pools.length; i++) {
      bytes32 exchangeId = getExchangeId(config.pools[i].asset0, config.pools[i].asset1, config.pools[i].isConstantSum);
      IBiPoolManager.PoolExchange memory pool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
      Config.Pool memory poolConfig = config.pools[i];

      bytes32 asset0LimitId = exchangeId ^ bytes32(uint256(uint160(pool.asset0)));
      TradingLimits.Config memory asset0ActualLimit = _broker.tradingLimitsConfig(asset0LimitId);

      bytes32 asset1LimitId = exchangeId ^ bytes32(uint256(uint160(pool.asset1)));
      TradingLimits.Config memory asset1ActualLimit = _broker.tradingLimitsConfig(asset1LimitId);

      checkTradingLimt(poolConfig.asset0limits, asset0ActualLimit);
      checkTradingLimt(poolConfig.asset1limits, asset1ActualLimit);
    }

    console.log("🟢 Trading limits set for all exchanges 🔒");
  }

  function checkTradingLimt(
    Config.TradingLimit memory expectedTradingLimit,
    TradingLimits.Config memory actualTradingLimit
  ) internal view {
    if (expectedTradingLimit.limit0 != actualTradingLimit.limit0) {
      console.log("limit0 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.limit1 != actualTradingLimit.limit1) {
      console.log("limit1 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.limitGlobal != actualTradingLimit.limitGlobal) {
      console.log("limitGlobal was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.timeStep0 != actualTradingLimit.timestep0) {
      console.log("timestep0 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
    if (expectedTradingLimit.timeStep1 != actualTradingLimit.timestep1) {
      console.log("timestep1 was not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }

    uint8 tradingLimitFlags = Config.tradingLimitConfigToFlag(expectedTradingLimit);
    if (tradingLimitFlags != actualTradingLimit.flags) {
      console.log("flags were not set as expected ❌");
      revert("Not all trading limits were configured correctly.");
    }
  }

  /* ================================================================ */
  /* ======================== Circuit Breaker ======================= */
  /* ================================================================ */

  function verifyCircuitBreaker(eXOFConfig.eXOF memory config) internal {
    console.log("\n== Checking circuit breaker ==");

    verifyBreakerBox(config);
    verifyBreakersAreEnabled(config);
    verifyMedianDeltaBreaker(config);
    verifyValueDeltaBreaker(config);
  }

  function verifyBreakerBox(eXOFConfig.eXOF memory config) internal view {
    // verify that rate feed dependencies were configured correctly
    require(
      BreakerBox(breakerBox).rateFeedDependencies(config.EUROCXOF.rateFeedID, 0) ==
      Config.rateFeedID("EURXOF"),
      "EUROC/XOF rate feed dependency not set correctly"
    );

    require(
      BreakerBox(breakerBox).rateFeedDependencies(config.EUROCXOF.rateFeedID, 1) ==
      Config.rateFeedID("EUROCEUR"),
      "EUROC/XOF rate feed dependency not set correctly"
    );

    require(
      BreakerBox(breakerBox).rateFeedDependencies(config.CELOXOF.rateFeedID, 0) ==
      Config.rateFeedID("EURXOF"),
      "EUROC/CELO rate feed dependency not set correctly"
    );


    console.log("🟢 Rate feed dependencies configured correctly 🗳️");
  }

  function verifyBreakersAreEnabled(eXOFConfig.eXOF memory config) internal view {
    // verify that MedianDeltaBreaker && ValueDeltaBreakers were enabled for rateFeeds
    for (uint256 i = 0; i < config.rateFeeds.length; i++) {
      Config.RateFeed memory rateFeed = config.rateFeeds[i];

      if (rateFeed.medianDeltaBreaker0.enabled) {
        bool medianDeltaEnabled = BreakerBox(breakerBox).isBreakerEnabled(medianDeltaBreaker, rateFeed.rateFeedID);
        if (!medianDeltaEnabled) {
          console.log("MedianDeltaBreaker not enabled for rate feed %s", rateFeed.rateFeedID);
          revert("MedianDeltaBreaker not enabled for all rate feeds");
        }

        if (rateFeed.valueDeltaBreaker0.enabled) {
          bool valueDeltaEnabled = BreakerBox(breakerBox).isBreakerEnabled(valueDeltaBreaker, rateFeed.rateFeedID);
          if (!valueDeltaEnabled) {
            console.log("ValueDeltaBreaker not enabled for rate feed %s", rateFeed.rateFeedID);
            revert("ValueDeltaBreaker not enabled for all rate feeds");
          }
        }
      }
    }
    console.log("🟢 Breakers enabled for all rate feeds 🗳️");
  }

  function verifyMedianDeltaBreaker(eXOFConfig.eXOF memory config) internal view {
    // verify that cooldown period, rate change threshold and smoothing factor were set correctly
    for (uint256 i = 0; i < config.rateFeeds.length; i++) {
      Config.RateFeed memory rateFeed = config.rateFeeds[i];

      if (rateFeed.medianDeltaBreaker0.enabled) {
        uint256 cooldown = MedianDeltaBreaker(medianDeltaBreaker).rateFeedCooldownTime(rateFeed.rateFeedID);
        uint256 rateChangeThreshold = MedianDeltaBreaker(medianDeltaBreaker).rateChangeThreshold(rateFeed.rateFeedID);
        uint256 smoothingFactor = MedianDeltaBreaker(medianDeltaBreaker).smoothingFactors(rateFeed.rateFeedID);

        // verify cooldown period
        verifyCooldownTime(cooldown, rateFeed.medianDeltaBreaker0.cooldown, rateFeed.rateFeedID, false);

        // verify rate change threshold
        verifyRateChangeTheshold(
          rateChangeThreshold,
          rateFeed.medianDeltaBreaker0.threshold.unwrap(),
          rateFeed.rateFeedID,
          false
        );

        // verify smoothing factor
        if (smoothingFactor != rateFeed.medianDeltaBreaker0.smoothingFactor) {
          console.log(
            "MedianDeltaBreaker smoothing factor not set correctly for the rate feed: %s",
            rateFeed.rateFeedID
          );
          revert("MedianDeltaBreaker smoothing factor not set correctly for all rate feeds");
        }
      }
    }
    console.log("🟢 MedianDeltaBreaker cooldown, rate change threshold and smoothing factor set correctly 🔒");
  }

  function verifyValueDeltaBreaker(eXOFConfig.eXOF memory config) internal view {
    // verify that cooldown period, rate change threshold and reference value were set correctly
    for (uint256 i = 0; i < config.rateFeeds.length; i++) {
      Config.RateFeed memory rateFeed = config.rateFeeds[i];

      if (rateFeed.valueDeltaBreaker0.enabled) {
        uint256 cooldown = ValueDeltaBreaker(valueDeltaBreaker).rateFeedCooldownTime(rateFeed.rateFeedID);
        uint256 rateChangeThreshold = ValueDeltaBreaker(valueDeltaBreaker).rateChangeThreshold(rateFeed.rateFeedID);
        uint256 referenceValue = ValueDeltaBreaker(valueDeltaBreaker).referenceValues(rateFeed.rateFeedID);

        // verify cooldown period
        verifyCooldownTime(cooldown, rateFeed.valueDeltaBreaker0.cooldown, rateFeed.rateFeedID, true);

        // verify rate change threshold
        verifyRateChangeTheshold(
          rateChangeThreshold,
          rateFeed.valueDeltaBreaker0.threshold.unwrap(),
          rateFeed.rateFeedID,
          true
        );

        // verify reference value
        if (referenceValue != rateFeed.valueDeltaBreaker0.referenceValue) {
          console.log("ValueDeltaBreaker reference value not set correctly for the rate feed: %s", rateFeed.rateFeedID);
          revert("ValueDeltaBreaker reference values not set correctly for all rate feeds");
        }
      }
    }
    console.log("🟢 ValueDeltaBreaker cooldown, rate change threshold and reference value set correctly 🔒");
  }

  function verifyRateChangeTheshold(
    uint256 currentThreshold,
    uint256 expectedThreshold,
    address rateFeedID,
    bool isValueDeltaBreaker
  ) internal view {
    if (currentThreshold != expectedThreshold) {
      if (isValueDeltaBreaker) {
        console.log("ValueDeltaBreaker rate change threshold not set correctly for rate feed with id %s", rateFeedID);
        revert("ValueDeltaBreaker rate change threshold not set correctly for rate feed");
      }
      console.log("MedianDeltaBreaker rate change threshold not set correctly for rate feed %s", rateFeedID);
      revert("MedianDeltaBreaker rate change threshold not set correctly for all rate feeds");
    }
  }

  function verifyCooldownTime(
    uint256 currentCoolDown,
    uint256 expectedCoolDown,
    address rateFeedID,
    bool isValueDeltaBreaker
  ) internal view {
    if (currentCoolDown != expectedCoolDown) {
      console.log("currentCoolDown: %s", currentCoolDown);
      console.log("expectedCoolDown: %s", expectedCoolDown);
      if (isValueDeltaBreaker) {
        console.log("ValueDeltaBreaker cooldown not set correctly for rate feed with id %s", rateFeedID);
        revert("ValueDeltaBreaker cooldown not set correctly for rate feed");
      }
      console.log("MedianDeltaBreaker cooldown not set correctly for rate feed %s", rateFeedID);
      revert("MedianDeltaBreaker cooldown not set correctly for all rate feeds");
    }
  }

  function bytes4ToStr(bytes4 _bytes) public pure returns (string memory) {
    bytes memory bytesArray = new bytes(4);
    for (uint256 i; i < 4; i++) {
      bytesArray[i] = _bytes[i];
    }
    return string(bytesArray);
  }
}
