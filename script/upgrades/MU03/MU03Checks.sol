// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console2 } from "forge-std/Script.sol";
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

import { BiPoolManagerProxy } from "mento-core-2.2.0/proxies/BiPoolManagerProxy.sol";
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

import { MU03Config, Config } from "./Config.sol";

/**
 * @title IBrokerWithCasts
 * @notice Interface for Broker with tuple -> struct casting
 * @dev This is used to access the internal trading limits
 * config as a struct as opposed to a tuple.
 */
interface IBrokerWithCasts {
  function tradingLimitsConfig(bytes32 id) external view returns (TradingLimits.Config memory);
}

contract MU03Checks is Script, Test {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;
  using SafeMath for uint256;

  address public celoToken;
  address public cUSD;
  address public cEUR;
  address public cBRL;
  address public bridgedUSDC;
  address public bridgedEUROC;

  address public governance;
  address public medianDeltaBreaker;
  address public valueDeltaBreaker;
  address public biPoolManager;
  address public sortedOracles;
  address public constantSum;
  address public constantProduct;
  address public reserve;
  address public breakerBox;
  address public broker;

  address payable public brokerProxy;
  address payable public sortedOraclesProxy;
  address payable public biPoolManagerProxy;

  function setUp() public {
    new PrecompileHandler(); // needed for reserve CELO transfer checks

    // Load addresses from deployments
    contracts.load("MU01-00-Create-Proxies", "latest");
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.load("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.load("MU03-02-Create-Implementations", "latest");

    // Get proxy addresses
    cUSD = contracts.celoRegistry("StableToken");
    cEUR = contracts.celoRegistry("StableTokenEUR");
    cBRL = contracts.celoRegistry("StableTokenBRL");
    reserve = contracts.deployed("PartialReserveProxy");
    celoToken = contracts.celoRegistry("GoldToken");
    governance = contracts.celoRegistry("Governance");
    brokerProxy = address(uint160(contracts.celoRegistry("Broker")));
    sortedOraclesProxy = address(uint160(contracts.celoRegistry("SortedOracles")));

    // Get Deployment addresses
    bridgedUSDC = contracts.dependency("BridgedUSDC");
    bridgedEUROC = contracts.dependency("BridgedEUROC");
    breakerBox = contracts.deployed("BreakerBox");
    medianDeltaBreaker = contracts.deployed("MedianDeltaBreaker");
    valueDeltaBreaker = contracts.deployed("ValueDeltaBreaker");
    biPoolManager = contracts.deployed("BiPoolManager");
    broker = contracts.deployed("Broker");
    constantSum = contracts.deployed("ConstantSumPricingModule");
    constantProduct = contracts.deployed("ConstantProductPricingModule");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");
    sortedOracles = contracts.deployed("SortedOracles");
  }

  function run() public {
    setUp();

    verifyOwner();
    verifyEUROCSetUp();
    verifyBiPoolManager();
    verifySortedOracles();
    verifyBroker();
    verifyExchanges();
    verifyCircuitBreaker();

    doSwaps();
  }

  function verifyOwner() internal view {
    require(
      BiPoolManager(biPoolManager).owner() == governance,
      "BiPoolManager ownership not transferred to governance"
    );
    require(BreakerBox(breakerBox).owner() == governance, "BreakerBox ownership not transferred to governance");
    require(
      MedianDeltaBreaker(medianDeltaBreaker).owner() == governance,
      "MedianDeltaBreaker ownership not transferred to governance"
    );
    require(
      SortedOracles(sortedOracles).owner() == governance,
      "SortedOracles ownership not transferred to governance"
    );
    require(Broker(broker).owner() == governance, "Broker ownership not transferred to governance");
    console2.log("Contract ownerships transferred to governance 🤝");
  }

  function verifyEUROCSetUp() internal view {
    Reserve partialReserve = Reserve(address(uint160(contracts.deployed("PartialReserveProxy"))));
    if (partialReserve.checkIsCollateralAsset(bridgedEUROC)) {
      console2.log("EUROC is a collateral asset 🏦");
    } else {
      console2.log("EUROC is not a collateral asset 🏦");
      revert("EUROC is not a collateral asset");
    }
  }

  function verifyBiPoolManager() internal view {
    BiPoolManagerProxy bpmProxy = BiPoolManagerProxy(biPoolManagerProxy);
    address bpmProxyImplementation = bpmProxy._getImplementation();
    address expectedBiPoolManager = biPoolManager;
    if (bpmProxyImplementation != expectedBiPoolManager) {
      console2.log(
        "The address of BiPoolManager from BiPoolManagerProxy: %s does not match the deployed address: %s.",
        bpmProxyImplementation,
        expectedBiPoolManager
      );
      revert("Deployed BiPoolManager does not match what proxy points to. See logs.");
    }
    console2.log("\tBiPoolManagerProxy has a correct implementation address 🫡");
  }

  function verifySortedOracles() internal view {
    address sortedOraclesImplementation = Proxy(sortedOraclesProxy)._getImplementation();
    address expectedSortedOracles = sortedOracles;
    if (sortedOraclesImplementation != expectedSortedOracles) {
      console2.log(
        "The address of SortedOracles from SortedOraclesProxy: %s does not match the deployed address: %s.",
        sortedOraclesImplementation,
        expectedSortedOracles
      );
      revert("Deployed SortedOracles does not match what proxy points to. See logs.");
    }
    console2.log("\tSortedOraclesProxy has a correct implementation address 🫡");
  }

  function verifyBroker() internal view {
    address brokerImplementation = Proxy(brokerProxy)._getImplementation();
    address expectedBroker = broker;
    if (brokerImplementation != expectedBroker) {
      console2.log(
        "The address of Broker from BrokerProxy: %s does not match the deployed address: %s.",
        brokerImplementation,
        expectedBroker
      );
      revert("Deployed Broker does not match what proxy points to. See logs.");
    }
    console2.log("\tBrokerProxy has a correct implementation address 🫡");
  }

  /* ================================================================ */
  /* =========================== Exchanges ========================== */
  /* ================================================================ */

  function verifyExchanges() internal {
    MU03Config.MU03 memory config = MU03Config.get(contracts);

    console2.log("== Verifying exchanges... ==");

    verifyPoolExchange(config);
    verifyPoolConfig(config);
    verifyTradingLimits(config);
    verifyReserveFraction();
  }

  function verifyPoolExchange(MU03Config.MU03 memory config) internal view {
    bytes32[] memory exchanges = BiPoolManager(biPoolManagerProxy).getExchangeIds();

    // check configured pools against the config
    if (config.pools.length != exchanges.length) {
      console2.log(
        "The number of expected pools: %s does not match the number of deployed pools: %s.",
        config.pools.length,
        exchanges.length
      );
      revert("Number of expected pools does not match the number of deployed pools. See logs.");
    }

    for (uint256 i = 0; i < exchanges.length; i++) {
      bytes32 exchangeId = exchanges[i];
      IBiPoolManager.PoolExchange memory pool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
      Config.Pool memory poolConfig = config.pools[i];

      // verify asset0 of the deployed pool against the config
      if (pool.asset0 != poolConfig.asset0) {
        console2.log(
          "The asset0 of deployed pool: %s does not match the expected asset0: %s.",
          pool.asset0,
          poolConfig.asset0
        );
        revert("asset0 of pool does not match the expected asset0. See logs.");
      }

      // verify asset1 of the deployed pool against the config
      if (pool.asset1 != poolConfig.asset1) {
        console2.log(
          "The asset1 of deployed pool: %s does not match the expected asset1: %s.",
          pool.asset1,
          poolConfig.asset1
        );
        revert("asset1 of pool does not match the expected asset1. See logs.");
      }

      if (poolConfig.isConstantSum) {
        if (address(pool.pricingModule) != constantSum) {
          console2.log(
            "The pricing module of deployed pool: %s does not match the expected pricing module: %s.",
            address(pool.pricingModule),
            constantSum
          );
          revert("pricing module of pool does not match the expected pricing module. See logs.");
        }
      } else {
        if (address(pool.pricingModule) != constantProduct) {
          console2.log(
            "The pricing module of deployed pool: %s does not match the expected pricing module: %s.",
            address(pool.pricingModule),
            constantProduct
          );
          revert("pricing module of pool does not match the expected pricing module. See logs.");
        }
      }
      // verify asset0 is always a stable asset
      require(
        pool.asset0 == cUSD || pool.asset0 == cEUR || pool.asset0 == cBRL,
        "asset0 is not a stable asset in the exchange"
      );
      // verify asset1 is always a collateral asset
      require(
        pool.asset1 == celoToken || pool.asset1 == bridgedUSDC || pool.asset1 == bridgedEUROC,
        "asset1 is not CELO, bridgedUSDC or bridgedEUROC in the exchange"
      );
    }
    console2.log("\tPoolExchange correctly configured 🤘🏼");
  }

  function verifyPoolConfig(MU03Config.MU03 memory config) internal view {
    bytes32[] memory exchanges = BiPoolManager(biPoolManagerProxy).getExchangeIds();

    for (uint256 i = 0; i < exchanges.length; i++) {
      bytes32 exchangeId = exchanges[i];
      IBiPoolManager.PoolExchange memory pool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
      Config.Pool memory poolConfig = config.pools[i];

      if (pool.config.spread.unwrap() != poolConfig.spread.unwrap()) {
        console2.log(
          "The spread of deployed pool: %s does not match the expected spread: %s.",
          pool.config.spread.unwrap(),
          poolConfig.spread.unwrap()
        );
        revert("spread of pool does not match the expected spread. See logs.");
      }

      if (pool.config.referenceRateFeedID != poolConfig.referenceRateFeedID) {
        console2.log(
          "The referenceRateFeedID of deployed pool: %s does not match the expected referenceRateFeedID: %s.",
          pool.config.referenceRateFeedID,
          poolConfig.referenceRateFeedID
        );
        revert("referenceRateFeedID of pool does not match the expected referenceRateFeedID. See logs.");
      }

      if (pool.config.minimumReports != poolConfig.minimumReports) {
        console2.log(
          "The minimumReports of deployed pool: %s does not match the expected minimumReports: %s.",
          pool.config.minimumReports,
          poolConfig.minimumReports
        );
        revert("minimumReports of pool does not match the expected minimumReports. See logs.");
      }

      if (pool.config.referenceRateResetFrequency != poolConfig.referenceRateResetFrequency) {
        console2.log(
          "The referenceRateResetFrequency of deployed pool: %s does not match the expected: %s.",
          pool.config.referenceRateResetFrequency,
          poolConfig.referenceRateResetFrequency
        );
        revert(
          "referenceRateResetFrequency of pool does not match the expected referenceRateResetFrequency. See logs."
        );
      }

      if (pool.config.stablePoolResetSize != poolConfig.stablePoolResetSize) {
        console2.log(
          "The stablePoolResetSize of deployed pool: %s does not match the expected stablePoolResetSize: %s.",
          pool.config.stablePoolResetSize,
          poolConfig.stablePoolResetSize
        );
        revert("stablePoolResetSize of pool does not match the expected stablePoolResetSize. See logs.");
      }
    }
    console2.log("\tPool config is correctly configured 🤘🏼");
  }

  function verifyTradingLimits(MU03Config.MU03 memory config) internal view {
    IBrokerWithCasts _broker = IBrokerWithCasts(brokerProxy);
    bytes32[] memory exchanges = BiPoolManager(biPoolManagerProxy).getExchangeIds();

    for (uint256 i = 0; i < exchanges.length; i++) {
      bytes32 exchangeId = exchanges[i];
      IBiPoolManager.PoolExchange memory pool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeId);
      Config.Pool memory poolConfig = config.pools[i];
      bytes32 limitId = exchangeId ^ bytes32(uint256(uint160(pool.asset0)));
      TradingLimits.Config memory limits = _broker.tradingLimitsConfig(limitId);

      // verify configured trading limits for all pools
      if (poolConfig.asset0limits.limit0 != limits.limit0) {
        console2.log("limit0 for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (poolConfig.asset0limits.limit1 != limits.limit1) {
        console2.log("limit1 for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (poolConfig.asset0limits.limitGlobal != limits.limitGlobal) {
        console2.log("limitGlobal for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (poolConfig.asset0limits.timeStep0 != limits.timestep0) {
        console2.log("timestep0 for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (poolConfig.asset0limits.timeStep1 != limits.timestep1) {
        console2.log("timestep1 for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (Config.tradingLimitConfigToFlag(poolConfig.asset0limits) != limits.flags) {
        console2.log("flags for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
    }
    console2.log("\tTrading limits set for all exchanges 🔒");
  }

  function verifyReserveFraction() internal view {
    address[] memory exchangesV1 = Arrays.addresses(
      contracts.celoRegistry("Exchange"),
      contracts.celoRegistry("ExchangeBRL"),
      contracts.celoRegistry("ExchangeEUR")
    );
    uint256[] memory reserveFractions = Arrays.uints(2e22, 5e21, 5e21);
    for (uint256 i = 0; i < exchangesV1.length; i++) {
      if (Exchange(exchangesV1[i]).reserveFraction() != (reserveFractions[i] / 2)) {
        console2.log("Reserve fraction not scaled down to correct value for exchange %s", exchangesV1[i]);
        revert("Reserve fraction not scaled down correctly for all exchanges");
      }
    }
    console2.log("\tReserve fraction scaled down correctly for all exchanges 🧾");
  }

  /* ================================================================ */
  /* ======================== Circuit Breaker ======================= */
  /* ================================================================ */

  function verifyCircuitBreaker() internal {
    MU03Config.MU03 memory config = MU03Config.get(contracts);

    console2.log("\n== Checking circuit breaker... ==");

    verifyBreakerBox(config);
    verifyMedianDeltaBreaker(config);
    verifyValueDeltaBreaker(config);
  }

  function verifyBreakerBox(MU03Config.MU03 memory config) internal view {
    // verify that breakers were set with trading mode 3
    if (
      BreakerBox(breakerBox).breakerTradingMode(medianDeltaBreaker) != 3 ||
      BreakerBox(breakerBox).breakerTradingMode(valueDeltaBreaker) != 3
    ) {
      console2.log("Breakers were not set with trading halted ❌");
      revert("Breakers were not set with trading halted");
    }
    console2.log("\tBreakers set with trading mode 3");

    // verify that rate feed dependencies were configured correctly
    address USDCEURDependency0 = BreakerBox(breakerBox).rateFeedDependencies(config.USDCEUR.rateFeedID, 0);
    address USDCBRLDependency0 = BreakerBox(breakerBox).rateFeedDependencies(config.USDCBRL.rateFeedID, 0);
    require(
      USDCEURDependency0 == config.cUSDUSDC.referenceRateFeedID,
      "USDC/EUR rate feed dependency not set correctly"
    );
    require(USDCBRLDependency0 == config.cUSDUSDC.referenceRateFeedID, "USDC/BRL dependency not set correctly");
    console2.log("\tRate feed dependencies configured correctly 🗳️");

    // verify that MedianDeltaBreaker && ValueDeltaBreaker were enabled for rateFeeds
    for (uint256 i = 0; i < config.rateFeeds.length; i++) {
      Config.RateFeed memory rateFeed = config.rateFeeds[i];

      if (rateFeed.medianDeltaBreaker0.enabled) {
        bool medianDeltaEnabled = BreakerBox(breakerBox).isBreakerEnabled(medianDeltaBreaker, rateFeed.rateFeedID);
        if (!medianDeltaEnabled) {
          console2.log("MedianDeltaBreaker not enabled for rate feed %s", rateFeed.rateFeedID);
          revert("MedianDeltaBreaker not enabled for all rate feeds");
        }

        if (rateFeed.valueDeltaBreaker0.enabled) {
          bool valueDeltaEnabled = BreakerBox(breakerBox).isBreakerEnabled(valueDeltaBreaker, rateFeed.rateFeedID);
          if (!valueDeltaEnabled) {
            console2.log("ValueDeltaBreaker not enabled for rate feed %s", rateFeed.rateFeedID);
            revert("ValueDeltaBreaker not enabled for all rate feeds");
          }
        }
      }
    }
    console2.log("\tBreakers enabled for all rate feeds 🗳️");

    // verify that breakerBox address was updated in SortedOracles
    if (BreakerBox(breakerBox) != SortedOracles(sortedOraclesProxy).breakerBox()) {
      revert("BreakerBox address not updated in SortedOracles");
    }
    console2.log("\tBreakerBox address updated in SortedOracles 🗳️");
  }

  function verifyMedianDeltaBreaker(MU03Config.MU03 memory config) internal view {
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
          console2.log(
            "MedianDeltaBreaker smoothing factor not set correctly for the rate feed: %s",
            rateFeed.rateFeedID
          );
          revert("MedianDeltaBreaker smoothing factor not set correctly for all rate feeds");
        }
      }
    }
    console2.log(
      "\tMedianDeltaBreaker cooldown, rate change threshold and smoothing factor set correctly for cUSD/USDC 🔒"
    );
  }

  function verifyValueDeltaBreaker(MU03Config.MU03 memory config) internal view {
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
          console2.log(
            "ValueDeltaBreaker reference value not set correctly for the rate feed: %s",
            rateFeed.rateFeedID
          );
          revert("ValueDeltaBreaker reference values not set correctly for all rate feeds");
        }
      }
    }
    console2.log("\tValueDeltaBreaker cooldown, rate change threshold and reference value set correctly 🔒");
  }

  // /* ================================================================ */
  // /* ============================= Swaps ============================ */
  // /* ================================================================ */

  function doSwaps() internal {
    MU03Config.MU03 memory config = MU03Config.get(contracts);

    console2.log("\n== Doing some test swaps... ==");

    swapCeloTocUSD();
    swapcUSDtoCelo();
    swapCeloTocEUR();
    swapcEURtoCELO();
    swapCeloTocBRL();
    swapcBrlToCELO();
    swapBridgedUSDCTocUSD(config);
    swapcUSDtoBridgedUSDC(config);
    swapBridgedUSDCTocEUR(config);
    swapcEURtoBridgedUSDC(config);
    swapBridgedUSDCtocBRL(config);
    swapcBRLtoBridgedUSDC(config);
    swapBridgedEUROCTocEUR(config);
    swapcEURtoBridgedEUROC(config);
  }

  function swapCeloTocUSD() internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(0);

    address trader = vm.addr(5);
    address tokenIn = celoToken;
    address tokenOut = cUSD;
    uint256 amountIn = 10e18;

    // Give trader some celo
    vm.deal(trader, amountIn);

    testAndPerformConstantProductSwap(exchangeID, trader, tokenIn, tokenOut, amountIn);

    console2.log("\tCELO -> cUSD swap successful 🚀");
  }

  function swapcUSDtoCelo() internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(0);

    address trader = vm.addr(5);
    address tokenIn = cUSD;
    address tokenOut = celoToken;
    uint256 amountIn = 1e18;

    testAndPerformConstantProductSwap(exchangeID, trader, tokenIn, tokenOut, amountIn);

    console2.log("\tcUSD -> CELO swap successful 🚀");
  }

  function swapCeloTocEUR() internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(1);

    address trader = vm.addr(5);
    address tokenIn = celoToken;
    address tokenOut = cEUR;
    uint256 amountIn = 10e18;

    // Give trader some celo
    vm.deal(trader, amountIn);

    testAndPerformConstantProductSwap(exchangeID, trader, tokenIn, tokenOut, amountIn);

    console2.log("\tCELO -> cEUR swap successful 🚀");
  }

  function swapcEURtoCELO() internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(1);

    address trader = vm.addr(5);
    address tokenIn = cEUR;
    address tokenOut = celoToken;
    uint256 amountIn = 1e18;

    testAndPerformConstantProductSwap(exchangeID, trader, tokenIn, tokenOut, amountIn);

    console2.log("\tcEUR -> CELO swap successful 🚀");
  }

  function swapCeloTocBRL() internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(2);

    address trader = vm.addr(5);
    address tokenIn = celoToken;
    address tokenOut = cBRL;
    uint256 amountIn = 10e18;

    // Give trader some celo
    vm.deal(trader, amountIn);

    testAndPerformConstantProductSwap(exchangeID, trader, tokenIn, tokenOut, amountIn);

    console2.log("\tCELO -> cBRL swap successful 🚀");
  }

  function swapcBrlToCELO() internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(2);

    address trader = vm.addr(5);
    address tokenIn = cBRL;
    address tokenOut = celoToken;
    uint256 amountIn = 1e18;

    testAndPerformConstantProductSwap(exchangeID, trader, tokenIn, tokenOut, amountIn);

    console2.log("\tcBRL -> CELO swap successful 🚀");
  }

  function swapBridgedUSDCTocUSD(MU03Config.MU03 memory config) internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(3);

    address trader = vm.addr(1);
    address tokenIn = bridgedUSDC;
    address tokenOut = cUSD;
    uint256 amountIn = 100e6;

    // Mint some USDC to trader
    deal(bridgedUSDC, trader, amountIn, true);

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cUSDUSDC.referenceRateFeedID,
      true
    );

    console2.log("\tbridgedUSDC -> cUSD swap successful 🚀");
  }

  function swapcUSDtoBridgedUSDC(MU03Config.MU03 memory config) internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(3);

    address trader = vm.addr(1);
    address tokenIn = cUSD;
    address tokenOut = bridgedUSDC;
    uint256 amountIn = 10e18;

    // Mint some USDC to the reserve
    deal(bridgedUSDC, reserve, 1000e18, true);

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cUSDUSDC.referenceRateFeedID,
      false
    );

    console2.log("\tcUSD -> bridgedUSDC swap successful 🚀");
  }

  function swapBridgedUSDCTocEUR(MU03Config.MU03 memory config) internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(4);

    address trader = vm.addr(3);
    address tokenIn = bridgedUSDC;
    address tokenOut = cEUR;
    uint256 amountIn = 100e6;

    // Mint some USDC to trader
    deal(bridgedUSDC, trader, amountIn, true);

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cEURUSDC.referenceRateFeedID,
      true
    );

    console2.log("\tbridgedUSDC -> cEUR swap successful 🚀");
  }

  function swapcEURtoBridgedUSDC(MU03Config.MU03 memory config) internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(4);

    address trader = vm.addr(3);
    address tokenIn = cEUR;
    address tokenOut = bridgedUSDC;
    uint256 amountIn = 10e18;

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cEURUSDC.referenceRateFeedID,
      false
    );

    console2.log("\tcEUR -> bridgedUSDC swap successful 🚀");
  }

  function swapBridgedUSDCtocBRL(MU03Config.MU03 memory config) internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(5);

    address trader = vm.addr(4);
    address tokenIn = bridgedUSDC;
    address tokenOut = cBRL;
    uint256 amountIn = 100e6;

    // Mint some USDC to trader
    deal(bridgedUSDC, trader, amountIn, true);

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cBRLUSDC.referenceRateFeedID,
      true
    );

    console2.log("\tbridgedUSDC -> cBRL swap successful 🚀");
  }

  function swapcBRLtoBridgedUSDC(MU03Config.MU03 memory config) internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(5);

    address trader = vm.addr(4);
    address tokenIn = cBRL;
    address tokenOut = bridgedUSDC;
    uint256 amountIn = 10e18;

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cBRLUSDC.referenceRateFeedID,
      false
    );

    console2.log("\tcBRL -> bridgedUSDC swap successful 🚀");
  }

  function swapBridgedEUROCTocEUR(MU03Config.MU03 memory config) internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(6);

    address trader = vm.addr(1);
    address tokenIn = bridgedEUROC;
    address tokenOut = cEUR;
    uint256 amountIn = 100e6;

    // Mint some EUROC to trader
    deal(bridgedEUROC, trader, amountIn, true);

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cEUREUROC.referenceRateFeedID,
      true
    );

    console2.log("\tbridgedEUROC -> cEUR swap successful 🚀");
  }

  function swapcEURtoBridgedEUROC(MU03Config.MU03 memory config) internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(6);

    address trader = vm.addr(1);
    address tokenIn = cEUR;
    address tokenOut = bridgedEUROC;
    uint256 amountIn = 10e18;

    // Mint some USDC to the reserve
    deal(bridgedEUROC, reserve, 1000e18, true);

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      config.cEUREUROC.referenceRateFeedID,
      false
    );

    console2.log("\tcEUR -> bridgedEUROC swap successful 🚀");
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
        console2.log("ValueDeltaBreaker rate change threshold not set correctly for rate feed %s", rateFeedID);
        revert("ValueDeltaBreaker rate change threshold not set correctly for all rate feeds");
      }
      console2.log("MedianDeltaBreaker rate change threshold not set correctly for rate feed %s", rateFeedID);
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
        console2.log("ValueDeltaBreaker cooldown not set correctly for rate feed %s", rateFeedID);
        revert("ValueDeltaBreaker cooldown not set correctly for all rate feeds");
      }
      console2.log("MedianDeltaBreaker cooldown not set correctly for rate feed %s", rateFeedID);
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
    uint256 amountOut = Broker(brokerProxy).getAmountOut(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn);
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
    uint256 amountOut = Broker(brokerProxy).getAmountOut(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn);
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
    IERC20(tokenIn).approve(address(brokerProxy), amountIn);
    Broker(brokerProxy).swapIn(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn, amountOut);
    assertEq(IERC20(tokenOut).balanceOf(trader), beforeBuyingTokenOut + amountOut);
    assertEq(IERC20(tokenIn).balanceOf(trader), beforeSellingTokenIn - amountIn);
    vm.stopPrank();
  }
}
