// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console2 as console } from "forge-std/Script.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { IFeeCurrencyWhitelist } from "script/interfaces/IFeeCurrencyWhitelist.sol";
import { ICeloGovernance } from "script/interfaces/ICeloGovernance.sol";
import { TradingLimits } from "mento-core-2.4.0/libraries/TradingLimits.sol";
import { StableTokenKESProxy } from "mento-core-2.4.0/legacy/proxies/StableTokenKESProxy.sol";

import { IRegistry } from "mento-core-2.4.0/common/interfaces/IRegistry.sol";
import { IBiPoolManager } from "mento-core-2.4.0/interfaces/IBiPoolManager.sol";
import { IERC20Metadata } from "mento-core-2.4.0/common/interfaces/IERC20Metadata.sol";
import { IStableTokenV2 } from "mento-core-2.4.0/interfaces/IStableTokenV2.sol";

import { Reserve } from "mento-core-2.4.0/swap/Reserve.sol";
import { Ownable } from "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import { Proxy } from "mento-core-2.4.0/common/Proxy.sol";
import { BiPoolManager } from "mento-core-2.4.0/swap/BiPoolManager.sol";
import { BreakerBox } from "mento-core-2.4.0/oracles/BreakerBox.sol";
import { MedianDeltaBreaker } from "mento-core-2.4.0/oracles/breakers/MedianDeltaBreaker.sol";

import { cKESChecksBase } from "./cKESChecks.base.sol";
import { cKESConfig, Config } from "./Config.sol";

/**
 * @title IBrokerWithCasts
 * @notice Interface for Broker with tuple -> struct casting
 * @dev This is used to access the internal trading limits
 * config as a struct as opposed to a tuple.
 */
interface IBrokerWithCasts {
  function tradingLimitsConfig(bytes32 id) external view returns (TradingLimits.Config memory);
}

contract cKESChecksVerify is cKESChecksBase {
  using TradingLimits for TradingLimits.Config;

  uint256 constant PRE_EXISTING_POOLS = 12;

  ICeloGovernance celoGovernance;

  constructor() public {
    setUp();
    celoGovernance = ICeloGovernance(governance);
  }

  function run() public {
    cKESConfig.cKES memory config = cKESConfig.get(contracts);
    console.log("\nStarting cKES checks:");

    console.log("\n==  Rate feeds ==");
    console.log("   KESUSD: %s", config.rateFeedConfig.rateFeedID);

    verifyToken(config);
    verifyExchange(config);
    verifyCircuitBreaker(config);
  }

  function verifyToken(cKESConfig.cKES memory config) internal {
    console.log("\n== Verifying Token Config Transactions ==");
    verifyOwner();
    verifyCKESStableToken(config);
    verifycKESAddedToReserve();
    verifycKESAddedToFeeCurrencyWhitelist();
    verifyConstitution();
  }

  function verifyOwner() internal view {
    address cKESImplementation = contracts.deployed("StableTokenKES");
    require(
      Ownable(cKESImplementation).owner() == governance,
      "StableTokenKES ownership not transferred to governance"
    );

    require(Proxy(cKES)._getOwner() == governance, "StableTokenKES Proxy ownership not transferred to governance");

    console.log("🟢 Contract ownerships transferred to governance");
  }

  function verifyCKESStableToken(cKESConfig.cKES memory config) internal {
    StableTokenKESProxy stableTokenKESProxy = StableTokenKESProxy(cKES);
    address stableTokenV2 = contracts.deployed("StableTokenV2");

    address cKESImplementation = stableTokenKESProxy._getImplementation();
    if (cKESImplementation != stableTokenV2) {
      console.log(
        "The implementation from StableTokenKESProxy: %s does not match the deployed StableTokenV2 address: %s.",
        cKESImplementation,
        stableTokenV2
      );
      revert("StableTokenKESProxy does not points to StableTokenV2 deployed implementation. See logs.");
    }
    console.log("🟢 StableTokenKESProxy has the correct implementation address");

    // ----- verify initialization parameters -----
    IStableTokenV2 cKESToken = IStableTokenV2(cKES);
    IERC20Metadata cKESTokenMetadata = IERC20Metadata(cKES);

    assertEq(cKESTokenMetadata.name(), config.stableTokenConfig.name, "❗️❌ cKES name not set correctly!");
    assertEq(cKESTokenMetadata.symbol(), config.stableTokenConfig.symbol, "❗️❌ cKES symbol not set correctly!");
    assertEq(cKESToken.broker(), broker, "❗️❌ cKES broker not set correctly!");

    // no pre-mint
    assertEq(cKESToken.totalSupply(), 0, "❗️❌ cKES pre-minted tokens!");
  }

  function verifycKESAddedToReserve() internal view {
    if (!Reserve(address(uint160(reserve))).isStableAsset(cKES)) {
      revert("cKES has not been added to the reserve.");
    }

    console.log("🟢 cKES has been added to the reserve");
  }

  function verifycKESAddedToFeeCurrencyWhitelist() internal view {
    address[] memory feeCurrencyWhitelist = IFeeCurrencyWhitelist(contracts.celoRegistry("FeeCurrencyWhitelist"))
      .getWhitelist();

    if (!Arrays.contains(feeCurrencyWhitelist, cKES)) {
      revert("cKES has not been added to the fee currency whitelist.");
    }

    console.log("🟢 cKES has been added to the fee currency whitelist");
  }

  function verifyConstitution() internal view {
    // These are now non config static values, but we can still check them to make sure they are set correctly
    bytes4[] memory constitutionFunctionSelectors = Config.getCeloStableConstitutionSelectors();
    uint256[] memory constitutionThresholds = Config.getCeloStableConstitutionThresholds();

    for (uint256 i = 0; i < constitutionFunctionSelectors.length; i++) {
      bytes4 selector = constitutionFunctionSelectors[i];
      uint256 expectedValue = constitutionThresholds[i];

      checkConstitutionParam(selector, expectedValue);
    }

    console.log("🟢 Constitution params configured correctly");
  }

  function checkConstitutionParam(bytes4 functionSelector, uint256 expectedValue) internal view {
    uint256 actualConstitutionValue = celoGovernance.getConstitution(cKES, functionSelector);

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

  function verifyExchange(cKESConfig.cKES memory config) internal view {
    console.log("\n== Verifying exchanges ==");

    verifyPoolExchange(config);
    verifyPoolConfig(config);
    verifyTradingLimits(config);
  }

  function verifyPoolExchange(cKESConfig.cKES memory config) internal view {
    bytes32[] memory exchanges = BiPoolManager(biPoolManagerProxy).getExchangeIds();

    // check configured pools against the config
    require(
      exchanges.length == PRE_EXISTING_POOLS + 1,
      "Number of expected pools does not match the number of deployed pools."
    );

    bytes32 exchangeId = getExchangeId(
      config.poolConfig.asset0,
      config.poolConfig.asset1,
      config.poolConfig.isConstantSum
    );

    IBiPoolManager.PoolExchange memory deployedPool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
    Config.Pool memory expectedPoolConfig = config.poolConfig;

    // verify asset0 of the deployed pool against the config
    if (deployedPool.asset0 != expectedPoolConfig.asset0) {
      console.log(
        "The asset0 of deployed pool: %s does not match the expected asset0: %s.",
        deployedPool.asset0,
        expectedPoolConfig.asset0
      );
      revert("asset0 of pool does not match the expected asset0. See logs.");
    }

    // verify asset1 of the deployed pool against the config
    if (deployedPool.asset1 != expectedPoolConfig.asset1) {
      console.log(
        "The asset1 of deployed pool: %s does not match the expected asset1: %s.",
        deployedPool.asset1,
        expectedPoolConfig.asset1
      );
      revert("asset1 of pool does not match the expected asset1. See logs.");
    }

    // Ensure the pricing module is the constant product
    if (address(deployedPool.pricingModule) != constantProduct) {
      console.log(
        "The pricing module of deployed pool: %s does not match the expected pricing module: %s.",
        address(deployedPool.pricingModule),
        constantProduct
      );
      revert("pricing module of pool does not match the expected pricing module. See logs.");
    }

    console.log("🟢 PoolExchange has correct assets and pricing 🤘🏼");
  }

  function verifyPoolConfig(cKESConfig.cKES memory config) internal view {
    bytes32 exchangeId = getExchangeId(
      config.poolConfig.asset0,
      config.poolConfig.asset1,
      config.poolConfig.isConstantSum
    );
    IBiPoolManager.PoolExchange memory deployedPool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
    Config.Pool memory expectedPoolConfig = config.poolConfig;

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
      revert("referenceRateResetFrequency of pool does not match the expected referenceRateResetFrequency. See logs.");
    }

    if (deployedPool.config.stablePoolResetSize != expectedPoolConfig.stablePoolResetSize) {
      console.log(
        "The stablePoolResetSize of deployed pool: %s does not match the expected stablePoolResetSize: %s.",
        deployedPool.config.stablePoolResetSize,
        expectedPoolConfig.stablePoolResetSize
      );
      revert("stablePoolResetSize of pool does not match the expected stablePoolResetSize. See logs.");
    }

    console.log("🟢 Pool config is correct🤘🏼");
  }

  function verifyTradingLimits(cKESConfig.cKES memory config) internal view {
    IBrokerWithCasts _broker = IBrokerWithCasts(address(broker));

    bytes32 exchangeId = getExchangeId(
      config.poolConfig.asset0,
      config.poolConfig.asset1,
      config.poolConfig.isConstantSum
    );
    IBiPoolManager.PoolExchange memory pool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
    Config.Pool memory expectedPoolConfig = config.poolConfig;

    bytes32 asset0LimitId = exchangeId ^ bytes32(uint256(uint160(pool.asset0)));
    TradingLimits.Config memory asset0ActualLimit = _broker.tradingLimitsConfig(asset0LimitId);

    bytes32 asset1LimitId = exchangeId ^ bytes32(uint256(uint160(pool.asset1)));
    TradingLimits.Config memory asset1ActualLimit = _broker.tradingLimitsConfig(asset1LimitId);

    checkTradingLimt(expectedPoolConfig.asset0limits, asset0ActualLimit);
    checkTradingLimt(expectedPoolConfig.asset1limits, asset1ActualLimit);

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

  function verifyCircuitBreaker(cKESConfig.cKES memory config) internal view {
    console.log("\n== Checking circuit breaker ==");

    verifyBreakersAreEnabled(config);
    verifyMedianDeltaBreaker(config);
  }

  function verifyBreakersAreEnabled(cKESConfig.cKES memory config) internal view {
    // verify that MedianDeltaBreaker is enabled
    Config.RateFeed memory expectedRateFeedConfig = config.rateFeedConfig;

    if (expectedRateFeedConfig.medianDeltaBreaker0.enabled) {
      bool medianDeltaEnabled = BreakerBox(breakerBox).isBreakerEnabled(
        medianDeltaBreaker,
        expectedRateFeedConfig.rateFeedID
      );
      if (!medianDeltaEnabled) {
        console.log("MedianDeltaBreaker not enabled for rate feed %s", expectedRateFeedConfig.rateFeedID);
        revert("MedianDeltaBreaker not enabled for all rate feeds");
      }
    }
    console.log("🟢 Breakers enabled for the rate feed 🗳️");
  }

  function verifyMedianDeltaBreaker(cKESConfig.cKES memory config) internal view {
    // verify that cooldown period, rate change threshold and smoothing factor were set correctly
    Config.RateFeed memory expectedRateFeedConfig = config.rateFeedConfig;

    if (expectedRateFeedConfig.medianDeltaBreaker0.enabled) {
      // Get the actual values from the deployed median delta breaker contract
      uint256 cooldown = MedianDeltaBreaker(medianDeltaBreaker).getCooldown(expectedRateFeedConfig.rateFeedID);
      uint256 rateChangeThreshold = MedianDeltaBreaker(medianDeltaBreaker).rateChangeThreshold(
        expectedRateFeedConfig.rateFeedID
      );
      uint256 smoothingFactor = MedianDeltaBreaker(medianDeltaBreaker).getSmoothingFactor(
        expectedRateFeedConfig.rateFeedID
      );

      // verify cooldown period
      verifyCooldownTime(
        cooldown,
        expectedRateFeedConfig.medianDeltaBreaker0.cooldown,
        expectedRateFeedConfig.rateFeedID,
        false
      );

      // verify rate change threshold
      verifyRateChangeTheshold(
        rateChangeThreshold,
        expectedRateFeedConfig.medianDeltaBreaker0.threshold.unwrap(),
        expectedRateFeedConfig.rateFeedID,
        false
      );

      // verify smoothing factor
      if (smoothingFactor != expectedRateFeedConfig.medianDeltaBreaker0.smoothingFactor) {
        console.log("expected: %s", expectedRateFeedConfig.medianDeltaBreaker0.smoothingFactor);
        console.log("got:      %s", smoothingFactor);
        console.log(
          "MedianDeltaBreaker smoothing factor not set correctly for the rate feed: %s",
          expectedRateFeedConfig.rateFeedID
        );
        revert("MedianDeltaBreaker smoothing factor not set correctly for all rate feeds");
      }
    }
    console.log("🟢 MedianDeltaBreaker cooldown, rate change threshold and smoothing factor set correctly 🔒");
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