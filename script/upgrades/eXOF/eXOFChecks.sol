// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console2 as console } from "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";
import { PrecompileHandler } from "celo-foundry/PrecompileHandler.sol";
import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { FixidityLib } from "mento-core-2.2.0/common/FixidityLib.sol";
import { IBiPoolManager } from "mento-core-2.2.0/interfaces/IBiPoolManager.sol";
import { IBroker } from "mento-core-2.2.0/interfaces/IBroker.sol";
import { IERC20Metadata } from "mento-core-2.2.0/common/interfaces/IERC20Metadata.sol";
import { IRegistry } from "mento-core-2.2.0/common/interfaces/IRegistry.sol";

import { IFeeCurrencyWhitelist } from "script/interfaces/IFeeCurrencyWhitelist.sol";

import { BiPoolManagerProxy } from "mento-core-2.2.0/proxies/BiPoolManagerProxy.sol";
import { StableTokenXOFProxy } from "mento-core-2.2.0/legacy/proxies/StableTokenXOFProxy.sol";
import { StableTokenXOF } from "mento-core-2.2.0/legacy/StableTokenXOF.sol";
import { Broker } from "mento-core-2.2.0/swap/Broker.sol";
import { BiPoolManager } from "mento-core-2.2.0/swap/BiPoolManager.sol";
import { Exchange } from "mento-core-2.2.0/legacy/Exchange.sol";
import { TradingLimits } from "mento-core-2.2.0/libraries/TradingLimits.sol";
import { BreakerBox } from "mento-core-2.2.0/oracles/BreakerBox.sol";
import { SortedOracles } from "mento-core-2.2.0/oracles/SortedOracles.sol";
import { Reserve } from "mento-core-2.2.0/swap/Reserve.sol";
import { MedianDeltaBreaker } from "mento-core-2.2.0/oracles/breakers/MedianDeltaBreaker.sol";
import { ValueDeltaBreaker } from "mento-core-2.2.0/oracles/breakers/ValueDeltaBreaker.sol";
import { ConstantSumPricingModule } from "mento-core-2.2.0/swap/ConstantSumPricingModule.sol";
import { SafeMath } from "celo-foundry/test/SafeMath.sol";
import { Proxy } from "mento-core-2.2.0/common/Proxy.sol";

import { SortedOracles } from "mento-core-2.2.0/oracles/SortedOracles.sol";

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

contract eXOFChecks is Script, Test {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;
  using SafeMath for uint256;

  address public celoToken;
  address public cUSD;
  address public cEUR;
  address public cBRL;
  address payable public eXOF;
  address public bridgedUSDC;
  address public bridgedEUROC;
  address public governance;
  address public medianDeltaBreaker;
  address public valueDeltaBreaker;
  address public nonrecoverableValueDeltaBreaker;
  address public biPoolManager;
  address payable sortedOraclesProxy;
  address public sortedOracles;
  address public constantSum;
  address public constantProduct;
  address payable biPoolManagerProxy;
  address public partialReserve;
  address public reserve;
  address public broker;
  address public breakerBox;

  function setUp() public {
    new PrecompileHandler(); // needed for reserve CELO transfer checks
    // Load addresses from deployments
    contracts.load("MU01-00-Create-Proxies", "latest");
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.load("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.load("MU03-02-Create-Implementations", "latest");
    contracts.load("eXOF-00-Create-Proxies", "latest");
    contracts.load("eXOF-01-Create-Implementations", "latest");
    contracts.load("eXOF-02-Create-Nonupgradeable-Contracts", "latest");

    // Get proxy addresses
    eXOF = contracts.deployed("StableTokenXOFProxy");
    cUSD = contracts.celoRegistry("StableToken");
    cEUR = contracts.celoRegistry("StableTokenEUR");
    cBRL = contracts.celoRegistry("StableTokenBRL");
    partialReserve = contracts.deployed("PartialReserveProxy");
    reserve = contracts.celoRegistry("Reserve");
    celoToken = contracts.celoRegistry("GoldToken");
    broker = contracts.celoRegistry("Broker");
    governance = contracts.celoRegistry("Governance");
    sortedOraclesProxy = address(uint160(contracts.celoRegistry("SortedOracles")));

    // Get Deployment addresses
    bridgedUSDC = contracts.dependency("BridgedUSDC");
    bridgedEUROC = contracts.dependency("BridgedEUROC");
    breakerBox = contracts.deployed("BreakerBox");
    medianDeltaBreaker = contracts.deployed("MedianDeltaBreaker");
    valueDeltaBreaker = contracts.deployed("ValueDeltaBreaker");
    nonrecoverableValueDeltaBreaker = contracts.deployed("NonrecoverableValueDeltaBreaker");
    biPoolManager = contracts.deployed("BiPoolManager");
    constantSum = contracts.deployed("ConstantSumPricingModule");
    constantProduct = contracts.deployed("ConstantProductPricingModule");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    sortedOracles = contracts.deployed("SortedOracles");
  }

  function run() public {
    setUp();
    console.log("\nStarting eXOF checks: \n");
    verifyOwner();
    verifyEXOFStableToken();
    verifyEXOFAddedToRegistry();
    verifyEXOFAddedToReserves();
    verifyEXOFAddedToFeeCurrencyWhitelist();
    verifyExchanges();
    verifyCircuitBreaker();
  }

  function verifyOwner() internal view {
    console.log("== Verifying Token Stuff... ==");

    address eXOFImplementation = contracts.deployed("StableTokenXOF");
    require(
      StableTokenXOF(eXOFImplementation).owner() == governance,
      "StableTokenXOF ownership not transferred to governance"
    );
    require(
      ValueDeltaBreaker(nonrecoverableValueDeltaBreaker).owner() == governance,
      "Nonrecoverable Value Delta Breaker ownership not transferred to governance"
    );
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

  function verifyEXOFAddedToRegistry() internal view {
    address registryEXOFAddress = IRegistry(REGISTRY_ADDRESS).getAddressForStringOrDie("StableTokenXOF");
    address deployedEXOFAddress = contracts.deployed("StableTokenXOFProxy");

    if (registryEXOFAddress != deployedEXOFAddress) {
      console.log(
        "The eXOF address from the registry: %s does not match the deployed address: %s.",
        registryEXOFAddress,
        deployedEXOFAddress
      );
      revert("Deployed eXOF does not match what registry points to. See logs.");
    }

    console.log("🟢 eXOF has been added to the registry");
  }

  function verifyEXOFAddedToReserves() internal view {
    if (!Reserve(address(uint160(partialReserve))).isStableAsset(eXOF)) {
      revert("eXOF has not been added to the partial reserve.");
    }

    if (!Reserve(address(uint160(reserve))).isStableAsset(eXOF)) {
      revert("eXOF has not been added to the reserve.");
    }

    console.log("🟢 eXOF has been added to the reserves");
  }

  function verifyEXOFAddedToFeeCurrencyWhitelist() internal view {
    address[] memory feeCurrencyWhitelist = IFeeCurrencyWhitelist(contracts.celoRegistry("FeeCurrencyWhitelist"))
      .getWhitelist();

    if (!Arrays.contains(feeCurrencyWhitelist, eXOF)) {
      revert("eXOF has not been added to the fee currency whitelist.");
    }

    console.log("🟢 eXOF has been added to the fee currency whitelist");
  }

  /* ================================================================ */
  /* =========================== Exchanges ========================== */
  /* ================================================================ */

  function verifyExchanges() internal {
    eXOFConfig.eXOF memory config = eXOFConfig.get(contracts);

    console.log("\n== Verifying exchanges... ==");

    verifyPoolExchange(config);
    verifyPoolConfig(config);
    verifyTradingLimits(config);
  }

  function verifyPoolExchange(eXOFConfig.eXOF memory config) internal view {
    bytes32[] memory exchanges = BiPoolManager(biPoolManagerProxy).getExchangeIds();

    // check configured pools against the config
    require(
      exchanges.length == config.pools.length + 7,
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
        "asset1 is not CELO or bridgedUSDC in the exchange"
      );
    }
    console.log("🟢 PoolExchange correctly configured 🤘🏼");
  }

  function verifyPoolConfig(eXOFConfig.eXOF memory config) internal view {
    for (uint256 i = 0; i < config.pools.length; i++) {
      bytes32 exchangeId = getExchangeId(config.pools[i].asset0, config.pools[i].asset1, config.pools[i].isConstantSum);
      IBiPoolManager.PoolExchange memory pool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
      Config.Pool memory poolConfig = config.pools[i];

      if (pool.config.spread.unwrap() != poolConfig.spread.unwrap()) {
        console.log(
          "The spread of deployed pool: %s does not match the expected spread: %s.",
          pool.config.spread.unwrap(),
          poolConfig.spread.unwrap()
        );
        revert("spread of pool does not match the expected spread. See logs.");
      }

      if (pool.config.referenceRateFeedID != poolConfig.referenceRateFeedID) {
        console.log(
          "The referenceRateFeedID of deployed pool: %s does not match the expected referenceRateFeedID: %s.",
          pool.config.referenceRateFeedID,
          poolConfig.referenceRateFeedID
        );
        revert("referenceRateFeedID of pool does not match the expected referenceRateFeedID. See logs.");
      }

      if (pool.config.minimumReports != poolConfig.minimumReports) {
        console.log(
          "The minimumReports of deployed pool: %s does not match the expected minimumReports: %s.",
          pool.config.minimumReports,
          poolConfig.minimumReports
        );
        revert("minimumReports of pool does not match the expected minimumReports. See logs.");
      }

      if (pool.config.referenceRateResetFrequency != poolConfig.referenceRateResetFrequency) {
        console.log(
          "The referenceRateResetFrequency of deployed pool: %s does not match the expected: %s.",
          pool.config.referenceRateResetFrequency,
          poolConfig.referenceRateResetFrequency
        );
        revert(
          "referenceRateResetFrequency of pool does not match the expected referenceRateResetFrequency. See logs."
        );
      }

      if (pool.config.stablePoolResetSize != poolConfig.stablePoolResetSize) {
        console.log(
          "The stablePoolResetSize of deployed pool: %s does not match the expected stablePoolResetSize: %s.",
          pool.config.stablePoolResetSize,
          poolConfig.stablePoolResetSize
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

      bytes32 limitId = exchangeId ^ bytes32(uint256(uint160(pool.asset0)));
      TradingLimits.Config memory limits = _broker.tradingLimitsConfig(limitId);

      // verify configured trading limits for all pools
      if (poolConfig.asset0limits.limit0 != limits.limit0) {
        console.log("limit0 for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (poolConfig.asset0limits.limit1 != limits.limit1) {
        console.log("limit1 for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (poolConfig.asset0limits.limitGlobal != limits.limitGlobal) {
        console.log("limitGlobal for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (poolConfig.asset0limits.timeStep0 != limits.timestep0) {
        console.log("timestep0 for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (poolConfig.asset0limits.timeStep1 != limits.timestep1) {
        console.log("timestep1 for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (Config.tradingLimitConfigToFlag(poolConfig.asset0limits) != limits.flags) {
        console.log("flags for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
    }
    console.log("🟢 Trading limits set for all exchanges 🔒");
  }

  /* ================================================================ */
  /* ======================== Circuit Breaker ======================= */
  /* ================================================================ */

  function verifyCircuitBreaker() internal {
    eXOFConfig.eXOF memory config = eXOFConfig.get(contracts);

    console.log("\n== Checking circuit breaker... ==");

    verifyBreakerBox(config);
    verifyBreakersAreEnabled(config);
    verifyMedianDeltaBreaker(config);
    verifyValueDeltaBreaker(config);
  }

  function verifyBreakerBox(eXOFConfig.eXOF memory config) internal view {
    // verify that breakers were set with trading mode 3
    if (BreakerBox(breakerBox).breakerTradingMode(nonrecoverableValueDeltaBreaker) != 3) {
      console.log("The Nonrecoverable ValueDeltaBreaker was not set with trading halted ❌");
      revert("Nonrecoverable ValueDeltaBreaker was not set with trading halted");
    }
    console.log("🟢 Nonrecoverable ValueDeltaBreaker set with trading mode 3");

    // verify that rate feed dependencies were configured correctly
    address EUROCXOFDependency = BreakerBox(breakerBox).rateFeedDependencies(config.EUROXOF.rateFeedID, 0);
    require(
      EUROCXOFDependency == config.EUROXOF.dependentRateFeeds[0],
      "EUROC/XOF rate feed dependency not set correctly"
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

        if (rateFeed.valueDeltaBreaker1.enabled) {
          bool nonrecoverableValueDeltaEnabled = BreakerBox(breakerBox).isBreakerEnabled(
            nonrecoverableValueDeltaBreaker,
            rateFeed.rateFeedID
          );
          if (!nonrecoverableValueDeltaEnabled) {
            console.log("Nonrecoverable ValueDeltaBreaker not enabled for rate feed %s", rateFeed.rateFeedID);
            revert("Nonrecoverable ValueDeltaBreaker not enabled for all rate feeds");
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

        // verify refernece value
        if (referenceValue != rateFeed.valueDeltaBreaker0.referenceValue) {
          console.log("ValueDeltaBreaker reference value not set correctly for the rate feed: %s", rateFeed.rateFeedID);
          revert("ValueDeltaBreaker reference values not set correctly for all rate feeds");
        }
      }
    }
    console.log("🟢 ValueDeltaBreaker cooldown, rate change threshold and reference value set correctly 🔒 \n");
  }

  function verifyNonrecoverableValueDeltaBreaker(eXOFConfig.eXOF memory config) internal view {
    // verify that cooldown period, rate change threshold and reference value were set correctly
    for (uint256 i = 0; i < config.rateFeeds.length; i++) {
      Config.RateFeed memory rateFeed = config.rateFeeds[i];

      if (rateFeed.valueDeltaBreaker1.enabled) {
        uint256 cooldown = ValueDeltaBreaker(nonrecoverableValueDeltaBreaker).rateFeedCooldownTime(rateFeed.rateFeedID);
        uint256 rateChangeThreshold = ValueDeltaBreaker(nonrecoverableValueDeltaBreaker).rateChangeThreshold(
          rateFeed.rateFeedID
        );
        uint256 referenceValue = ValueDeltaBreaker(nonrecoverableValueDeltaBreaker).referenceValues(
          rateFeed.rateFeedID
        );

        // verify cooldown period
        verifyCooldownTime(cooldown, rateFeed.valueDeltaBreaker1.cooldown, rateFeed.rateFeedID, true);

        // verify rate change threshold
        verifyRateChangeTheshold(
          rateChangeThreshold,
          rateFeed.valueDeltaBreaker1.threshold.unwrap(),
          rateFeed.rateFeedID,
          true
        );

        // verify refernece value
        if (referenceValue != rateFeed.valueDeltaBreaker1.referenceValue) {
          console.log(
            "Nonrecoverable ValueDeltaBreaker reference value not set correctly for the rate feed: %s",
            rateFeed.rateFeedID
          );
          revert("Nonrecoverable ValueDeltaBreaker reference values not set correctly for all rate feeds");
        }
      }
    }
    console.log(
      "\tNonrecoverable ValueDeltaBreaker cooldown, rate change threshold and reference value set correctly 🔒"
    );
  }

  // /* ================================================================ */
  // /* ============================= Swaps ============================ */
  // /* ================================================================ */
  function doSwaps() internal {
    eXOFConfig.eXOF memory config = eXOFConfig.get(contracts);

    console.log("\n== Doing some test swaps... ==");

    swapCeloToEXOF(config);
    swapEXOFtoCelo(config);
    swapBridgedEUROCtoEXOF(config);
    swapEXOFtoBridgedEUROC(config);
  }

  function swapCeloToEXOF(eXOFConfig.eXOF memory config) internal {
    bytes32 exchangeID = getExchangeId(config.eXOFCelo.asset0, config.eXOFCelo.asset1, config.eXOFCelo.isConstantSum);

    address trader = vm.addr(5);
    address tokenIn = celoToken;
    address tokenOut = eXOF;
    uint256 amountIn = 100e18;

    // Give trader some celo
    vm.deal(trader, amountIn);

    testAndPerformConstantProductSwap(exchangeID, trader, tokenIn, tokenOut, amountIn);

    console.log("\tCELO -> eXOF swap successful 🚀");
  }

  function swapEXOFtoCelo(eXOFConfig.eXOF memory config) internal {
    bytes32 exchangeID = getExchangeId(config.eXOFCelo.asset0, config.eXOFCelo.asset1, config.eXOFCelo.isConstantSum);

    address trader = vm.addr(5);
    address tokenIn = eXOF;
    address tokenOut = celoToken;
    uint256 amountIn = 100e18;

    testAndPerformConstantProductSwap(exchangeID, trader, tokenIn, tokenOut, amountIn);

    console.log("\teXOF -> CELO swap successful 🚀");
  }

  function swapBridgedEUROCtoEXOF(eXOFConfig.eXOF memory config) internal {
    bytes32 exchangeID = getExchangeId(
      config.eXOFEUROC.asset0,
      config.eXOFEUROC.asset1,
      config.eXOFEUROC.isConstantSum
    );

    address trader = vm.addr(4);
    address tokenIn = bridgedEUROC;
    address tokenOut = eXOF;
    uint256 amountIn = 10e6;

    // Mint some EUROC to trader
    deal(bridgedUSDC, trader, amountIn, true);

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.eXOFEUROC.referenceRateFeedID,
      true
    );

    console.log("\tbridgedEUROC -> eXOF swap successful 🚀");
  }

  function swapEXOFtoBridgedEUROC(eXOFConfig.eXOF memory config) internal {
    bytes32 exchangeID = getExchangeId(
      config.eXOFEUROC.asset0,
      config.eXOFEUROC.asset1,
      config.eXOFEUROC.isConstantSum
    );

    address trader = vm.addr(4);
    address tokenIn = eXOF;
    address tokenOut = bridgedEUROC;
    uint256 amountIn = 100e18;

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.eXOFEUROC.referenceRateFeedID,
      false
    );

    console.log("\teXOF -> bridgedEUROC swap successful 🚀");
  }

  // /* ================================================================ */
  // /* ============================ Helpers =========================== */
  // /* ================================================================ */

  function verifyRateChangeTheshold(
    uint256 currentThreshold,
    uint256 expectedThreshold,
    address rateFeedID,
    bool isValueDeltaBreaker
  ) internal view {
    if (currentThreshold != expectedThreshold) {
      if (isValueDeltaBreaker) {
        console.log("ValueDeltaBreaker rate change threshold not set correctly for USDC/USD rate feed %s", rateFeedID);
        revert("ValueDeltaBreaker rate change threshold not set correctly for USDC/USD rate feed");
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
      if (isValueDeltaBreaker) {
        console.log("ValueDeltaBreaker cooldown not set correctly for USDC/USD rate feed %s", rateFeedID);
        revert("ValueDeltaBreaker cooldown not set correctly for USDC/USD rate feed");
      }
      console.log("MedianDeltaBreaker cooldown not set correctly for rate feed %s", rateFeedID);
      revert("MedianDeltaBreaker cooldown not set correctly for all rate feeds");
    }
  }

  function testAndPerformConstantProductSwap(
    bytes32 exchangeID,
    address trader,
    address tokenIn,
    address tokenOut,
    uint256 amountIn
  ) internal {
    uint256 amountOut = Broker(broker).getAmountOut(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn);
    IBiPoolManager.PoolExchange memory pool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeID);

    FixidityLib.Fraction memory numerator;
    FixidityLib.Fraction memory denominator;

    if (tokenIn == pool.asset0) {
      numerator = FixidityLib.newFixed(amountIn).multiply(FixidityLib.newFixed(pool.bucket1));
      denominator = FixidityLib.newFixed(pool.bucket0).add(FixidityLib.newFixed(amountIn));
    } else {
      numerator = FixidityLib.newFixed(amountIn).multiply(FixidityLib.newFixed(pool.bucket0));
      denominator = FixidityLib.newFixed(pool.bucket1).add(FixidityLib.newFixed(amountIn));
    }

    uint256 estimatedAmountOut = numerator.unwrap().div(denominator.unwrap());

    FixidityLib.Fraction memory maxTolerance = FixidityLib.newFixedFraction(25, 10000);
    uint256 threshold = FixidityLib.newFixed(estimatedAmountOut).multiply(maxTolerance).fromFixed();
    assertApproxEqAbs(amountOut, estimatedAmountOut, threshold);

    doSwapIn(exchangeID, trader, tokenIn, tokenOut, amountIn, amountOut);
  }

  function testAndPerformConstantSumSwap(
    bytes32 exchangeID,
    address trader,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    address rateFeedID,
    bool isBridgedUsdcToStable
  ) internal {
    uint256 amountOut = Broker(broker).getAmountOut(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn);
    (uint256 numerator, uint256 denominator) = SortedOracles(sortedOraclesProxy).medianRate(rateFeedID);
    uint256 estimatedAmountOut;

    if (isBridgedUsdcToStable) {
      estimatedAmountOut = FixidityLib
        .newFixed(amountIn.mul(1e12))
        .multiply(FixidityLib.wrap(numerator).divide(FixidityLib.wrap(denominator)))
        .fromFixed();
    } else {
      estimatedAmountOut = FixidityLib
        .newFixed(amountIn)
        .multiply(FixidityLib.wrap(denominator).divide(FixidityLib.wrap(numerator)))
        .fromFixed();
      estimatedAmountOut = estimatedAmountOut.div(1e12);
    }

    FixidityLib.Fraction memory maxTolerance = FixidityLib.newFixedFraction(25, 1000);
    uint256 threshold = FixidityLib.newFixed(estimatedAmountOut).multiply(maxTolerance).fromFixed();
    assertApproxEqAbs(amountOut, estimatedAmountOut, threshold);

    doSwapIn(exchangeID, trader, tokenIn, tokenOut, amountIn, amountOut);
  }

  function doSwapIn(
    bytes32 exchangeID,
    address trader,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOut
  ) internal {
    uint256 beforeBuyingTokenOut = IERC20(tokenOut).balanceOf(trader);
    uint256 beforeSellingTokenIn = IERC20(tokenIn).balanceOf(trader);

    vm.startPrank(trader);
    IERC20(tokenIn).approve(address(broker), amountIn);
    Broker(broker).swapIn(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn, amountOut);
    assertEq(IERC20(tokenOut).balanceOf(trader), beforeBuyingTokenOut + amountOut);
    assertEq(IERC20(tokenIn).balanceOf(trader), beforeSellingTokenIn - amountIn);
    vm.stopPrank();
  }

  /**
   * @notice Helper function to get the exchange ID for a pool.
   */
  function getExchangeId(address asset0, address asset1, bool isConstantSum) internal view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          IERC20Metadata(asset0).symbol(),
          IERC20Metadata(asset1).symbol(),
          isConstantSum ? "ConstantSum" : "ConstantProduct"
        )
      );
  }
}
