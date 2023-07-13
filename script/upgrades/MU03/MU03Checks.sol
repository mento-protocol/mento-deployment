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
import { MockERC20 } from "contracts/MockERC20.sol";

import { FixidityLib } from "mento-core-2.2.0/common/FixidityLib.sol";
import { IBiPoolManager } from "mento-core-2.2.0/interfaces/IBiPoolManager.sol";
import { IBroker } from "mento-core-2.2.0/interfaces/IBroker.sol";
import { IERC20Metadata } from "mento-core-2.2.0/common/interfaces/IERC20Metadata.sol";

import { BiPoolManagerProxy } from "mento-core-2.2.0/proxies/BiPoolManagerProxy.sol";
import { BrokerProxy } from "mento-core-2.2.0/proxies/BrokerProxy.sol";
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

import { SortedOracles } from "mento-core-2.2.0/oracles/SortedOracles.sol";

import { MU03Config, Config } from "./Config.sol";

/**
 * @title IBrokerWithCasts
 * @notice Interface for Broker with tuple -> struct casting
 * @dev This is used to access the internal trading limits state and
 * config as structs as opposed to tuples.
 */
interface IBrokerWithCasts {
  function tradingLimitsConfig(bytes32 id) external view returns (TradingLimits.Config memory);
}

contract MU03Checks is Script, Test {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;
  using SafeMath for uint256;

  BreakerBox private breakerBox;
  Reserve private reserve;
  IBroker private broker;

  address public celoToken;
  address public cUSD;
  address public cEUR;
  address public cBRL;
  address public bridgedUSDC;
  address public governance;
  address public medianDeltaBreaker;
  address public valueDeltaBreaker;
  address public biPoolManager;
  address public sortedOracles;
  address public constantSum;
  address public constantProduct;
  address public biPoolManagerProxy;

  // Pool Configs
  Config.PoolConfiguration private cUSDCeloConfig;
  Config.PoolConfiguration private cEURCeloConfig;
  Config.PoolConfiguration private cBRLCeloConfig;
  Config.PoolConfiguration private cUSDUSDCConfig;
  Config.PoolConfiguration private cEURUSDCConfig;
  Config.PoolConfiguration private cBRLUSDCConfig;
  Config.PoolConfiguration[] private poolConfigs;

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
    reserve = Reserve(contracts.deployed("PartialReserveProxy"));
    celoToken = contracts.celoRegistry("GoldToken");
    broker = IBroker(contracts.celoRegistry("Broker"));
    governance = contracts.celoRegistry("Governance");
    sortedOracles = contracts.celoRegistry("SortedOracles");

    // Get Deployment addresses
    bridgedUSDC = contracts.dependency("BridgedUSDC");
    breakerBox = BreakerBox(contracts.deployed("BreakerBox"));
    medianDeltaBreaker = contracts.deployed("MedianDeltaBreaker");
    valueDeltaBreaker = contracts.deployed("ValueDeltaBreaker");
    biPoolManager = contracts.deployed("BiPoolManager");
    constantSum = contracts.deployed("ConstantSumPricingModule");
    constantProduct = contracts.deployed("ConstantProductPricingModule");
    biPoolManagerProxy = contracts.deployed("BiPoolManagerProxy");

    setUpConfigs();
  }

  function run() public {
    setUp();

    verifyOwner();
    verifyBiPoolManager();
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
    console2.log("Contract ownerships transferred to governance 🤝");
  }

  function verifyBiPoolManager() internal view {
    BiPoolManagerProxy bpmProxy = BiPoolManagerProxy(contracts.deployed("BiPoolManagerProxy"));
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

  /* ================================================================ */
  /* =========================== Exchanges ========================== */
  /* ================================================================ */

  function verifyExchanges() internal view {
    console2.log("== Verifying exchanges... ==");
    verifyPoolExchange();
    verifyPoolConfig();
    verifyTradingLimits();
    verifyReserveFraction();
  }

  function verifyPoolExchange() internal view {
    BiPoolManager bpm = getBiPoolManager();
    bytes32[] memory exchanges = bpm.getExchangeIds();

    // check configured pools against the config
    if (poolConfigs.length != exchanges.length) {
      console2.log(
        "The number of expected pools: %s does not match the number of deployed pools: %s.",
        poolConfigs.length,
        exchanges.length
      );
      revert("Number of expected pools does not match the number of deployed pools. See logs.");
    }

    for (uint256 i = 0; i < exchanges.length; i++) {
      bytes32 exchangeId = exchanges[i];
      IBiPoolManager.PoolExchange memory pool = bpm.getPoolExchange(exchangeId);

      // verify asset0 of the deployed pool against the config
      if (pool.asset0 != poolConfigs[i].asset0) {
        console2.log(
          "The asset0 of deployed pool: %s does not match the expected asset0: %s.",
          pool.asset0,
          poolConfigs[i].asset0
        );
        revert("asset0 of pool does not match the expected asset0. See logs.");
      }

      // verify asset1 of the deployed pool against the config
      if (pool.asset1 != poolConfigs[i].asset1) {
        console2.log(
          "The asset1 of deployed pool: %s does not match the expected asset1: %s.",
          pool.asset1,
          poolConfigs[i].asset1
        );
        revert("asset1 of pool does not match the expected asset1. See logs.");
      }

      if (poolConfigs[i].isConstantSum) {
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
        pool.asset1 == celoToken || pool.asset1 == bridgedUSDC,
        "asset1 is not CELO or bridgedUSDC in the exchange"
      );
    }
    console2.log("\tPoolExchange correctly configured 🤘🏼");
  }

  function verifyPoolConfig() internal view {
    BiPoolManager bpm = getBiPoolManager();
    bytes32[] memory exchanges = bpm.getExchangeIds();

    for (uint256 i = 0; i < exchanges.length; i++) {
      bytes32 exchangeId = exchanges[i];
      IBiPoolManager.PoolExchange memory pool = bpm.getPoolExchange(exchangeId);

      if (pool.config.spread.unwrap() != poolConfigs[i].spread.unwrap()) {
        console2.log(
          "The spread of deployed pool: %s does not match the expected spread: %s.",
          pool.config.spread.unwrap(),
          poolConfigs[i].spread.unwrap()
        );
        revert("spread of pool does not match the expected spread. See logs.");
      }

      if (pool.config.referenceRateFeedID != poolConfigs[i].referenceRateFeedID) {
        console2.log(
          "The referenceRateFeedID of deployed pool: %s does not match the expected referenceRateFeedID: %s.",
          pool.config.referenceRateFeedID,
          poolConfigs[i].referenceRateFeedID
        );
        revert("referenceRateFeedID of pool does not match the expected referenceRateFeedID. See logs.");
      }

      if (pool.config.minimumReports != poolConfigs[i].minimumReports) {
        console2.log(
          "The minimumReports of deployed pool: %s does not match the expected minimumReports: %s.",
          pool.config.minimumReports,
          poolConfigs[i].minimumReports
        );
        revert("minimumReports of pool does not match the expected minimumReports. See logs.");
      }

      if (pool.config.referenceRateResetFrequency != poolConfigs[i].referenceRateResetFrequency) {
        console2.log(
          "The referenceRateResetFrequency of deployed pool: %s does not match the expected: %s.",
          pool.config.referenceRateResetFrequency,
          poolConfigs[i].referenceRateResetFrequency
        );
        revert(
          "referenceRateResetFrequency of pool does not match the expected referenceRateResetFrequency. See logs."
        );
      }

      if (pool.config.stablePoolResetSize != poolConfigs[i].stablePoolResetSize) {
        console2.log(
          "The stablePoolResetSize of deployed pool: %s does not match the expected stablePoolResetSize: %s.",
          pool.config.stablePoolResetSize,
          poolConfigs[i].stablePoolResetSize
        );
        revert("stablePoolResetSize of pool does not match the expected stablePoolResetSize. See logs.");
      }
    }
    console2.log("\tPool config is correctly configured 🤘🏼");
  }

  function verifyTradingLimits() internal view {
    IBrokerWithCasts _broker = IBrokerWithCasts(address(broker));
    BiPoolManager bpm = getBiPoolManager();
    bytes32[] memory exchanges = bpm.getExchangeIds();

    for (uint256 i = 0; i < exchanges.length; i++) {
      bytes32 exchangeId = exchanges[i];
      IBiPoolManager.PoolExchange memory pool = bpm.getPoolExchange(exchangeId);
      bytes32 limitId = exchangeId ^ bytes32(uint256(uint160(pool.asset0)));
      TradingLimits.Config memory limits = _broker.tradingLimitsConfig(limitId);

      // verify configured trading limits for all pools
      if (poolConfigs[i].asset0_limit0 != limits.limit0) {
        console2.log("limit0 for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (poolConfigs[i].asset0_limit1 != limits.limit1) {
        console2.log("limit1 for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (poolConfigs[i].asset0_limitGlobal != limits.limitGlobal) {
        console2.log("limitGlobal for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (poolConfigs[i].asset0_timeStep0 != limits.timestep0) {
        console2.log("timestep0 for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (poolConfigs[i].asset0_timeStep1 != limits.timestep1) {
        console2.log("timestep1 for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were configured correctly.");
      }
      if (poolConfigs[i].asset0_flags != limits.flags) {
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

  function verifyCircuitBreaker() internal view {
    console2.log("\n== Checking circuit breaker... ==");
    verifyBreakerBox();
    verifyMedianDeltaBreaker();
    verifyValueDeltaBreaker();
  }

  function verifyBreakerBox() internal view {
    // verify that breakers were set with trading mode 3
    if (
      breakerBox.breakerTradingMode(medianDeltaBreaker) != 3 || breakerBox.breakerTradingMode(valueDeltaBreaker) != 3
    ) {
      console2.log("Breakers were not set with trading halted ❌");
      revert("Breakers were not set with trading halted");
    }
    console2.log("\tBreakers set with trading mode 3");

    // verify that rate feed dependencies were configured correctly
    address cEurDependency = breakerBox.rateFeedDependencies(cEURUSDCConfig.referenceRateFeedID, 0);
    address cBrlDependency = breakerBox.rateFeedDependencies(cBRLUSDCConfig.referenceRateFeedID, 0);
    require(cEurDependency == cUSDUSDCConfig.referenceRateFeedID, "cEUR/USDC dependency not set correctly");
    require(cBrlDependency == cUSDUSDCConfig.referenceRateFeedID, "cBRL/USDC dependency not set correctly");
    console2.log("\tRate feed dependencies configured correctly 🗳️");

    // verify that MedianDeltaBreaker && ValueDeltaBreaker were enabled for rateFeeds
    for (uint256 i = 0; i < poolConfigs.length; i++) {
      if (poolConfigs[i].isMedianDeltaBreakerEnabled) {
        bool medianDeltaEnabled = breakerBox.isBreakerEnabled(medianDeltaBreaker, poolConfigs[i].referenceRateFeedID);
        if (!medianDeltaEnabled) {
          console2.log("MedianDeltaBreaker not enabled for rate feed %s", poolConfigs[i].referenceRateFeedID);
          revert("MedianDeltaBreaker not enabled for all rate feeds");
        }

        if (poolConfigs[i].isValueDeltaBreakerEnabled) {
          bool valueDeltaEnabled = breakerBox.isBreakerEnabled(valueDeltaBreaker, poolConfigs[i].referenceRateFeedID);
          if (!valueDeltaEnabled) {
            console2.log("ValueDeltaBreaker not enabled for rate feed %s", poolConfigs[i].referenceRateFeedID);
            revert("ValueDeltaBreaker not enabled for all rate feeds");
          }
        }
      }
    }
    console2.log("\tBreakers enabled for all rate feeds 🗳️");

    // verify that breakerBox address was updated in SortedOracles
    if (breakerBox != SortedOracles(sortedOracles).breakerBox()) {
      revert("BreakerBox address not updated in SortedOracles");
    }
    console2.log("\tBreakerBox address updated in SortedOracles 🗳️");
  }

  function verifyMedianDeltaBreaker() internal view {
    // verify that cooldown period, rate change threshold and smoothing factor were set correctly
    for (uint256 i = 0; i < poolConfigs.length; i++) {
      if (poolConfigs[i].isMedianDeltaBreakerEnabled) {
        uint256 cooldown = MedianDeltaBreaker(medianDeltaBreaker).rateFeedCooldownTime(
          poolConfigs[i].referenceRateFeedID
        );
        uint256 rateChangeThreshold = MedianDeltaBreaker(medianDeltaBreaker).rateChangeThreshold(
          poolConfigs[i].referenceRateFeedID
        );
        uint256 smoothingFactor = MedianDeltaBreaker(medianDeltaBreaker).smoothingFactors(
          poolConfigs[i].referenceRateFeedID
        );

        // verify cooldown period
        verifyCooldownTime(
          cooldown,
          poolConfigs[i].medianDeltaBreakerCooldown,
          poolConfigs[i].referenceRateFeedID,
          false
        );

        // verify rate change threshold
        verifyRateChangeTheshold(
          rateChangeThreshold,
          poolConfigs[i].medianDeltaBreakerThreshold.unwrap(),
          poolConfigs[i].referenceRateFeedID,
          false
        );

        // verify smoothing factor
        if (smoothingFactor != poolConfigs[i].smoothingFactor) {
          console2.log(
            "MedianDeltaBreaker smoothing factor not set correctly for rate feed %s",
            poolConfigs[i].referenceRateFeedID
          );
          revert("MedianDeltaBreaker smoothing factor not set correctly for all rate feeds");
        }
      }
    }
    console2.log("\tMedianDeltaBreaker cooldown, rate change threshold and smoothing factor set correctly 🔒");
  }

  function verifyValueDeltaBreaker() internal view {
    // verify that cooldown period, rate change threshold and reference value were set correctly
    for (uint256 i = 0; i < poolConfigs.length; i++) {
      if (poolConfigs[i].isValueDeltaBreakerEnabled) {
        uint256 cooldown = ValueDeltaBreaker(valueDeltaBreaker).rateFeedCooldownTime(
          poolConfigs[i].referenceRateFeedID
        );
        uint256 rateChangeThreshold = ValueDeltaBreaker(valueDeltaBreaker).rateChangeThreshold(
          poolConfigs[i].referenceRateFeedID
        );
        uint256 referenceValue = ValueDeltaBreaker(valueDeltaBreaker).referenceValues(
          poolConfigs[i].referenceRateFeedID
        );

        // verify coodown
        verifyCooldownTime(
          cooldown,
          poolConfigs[i].valueDeltaBreakerCooldown,
          poolConfigs[i].referenceRateFeedID,
          true
        );

        // verify rate change threshold
        verifyRateChangeTheshold(
          rateChangeThreshold,
          poolConfigs[i].valueDeltaBreakerThreshold.unwrap(),
          poolConfigs[i].referenceRateFeedID,
          true
        );

        // verify reference value
        if (referenceValue != poolConfigs[i].valueDeltaBreakerReferenceValue) {
          console2.log(
            "ValueDeltaBreaker reference value not set correctly for rate feed %s",
            poolConfigs[i].referenceRateFeedID
          );
          revert("ValueDeltaBreaker reference value not set correctly for all rate feeds");
        }
      }
    }
    console2.log("\tValueDeltaBreaker cooldown, rate change threshold and reference value set correctly 🔒");
  }

  /* ================================================================ */
  /* ============================= Swaps ============================ */
  /* ================================================================ */

  function doSwaps() internal {
    console2.log("\n== Doing some test swaps... ==");
    swapCeloTocUSD();
    swapcUSDtoCelo();
    swapCeloTocEUR();
    swapcEURtoCELO();
    swapCeloTocBRL();
    swapcBrlToCELO();
    swapBridgedUSDCTocUSD();
    swapcUSDtoBridgedUSDC();
    swapBridgedUSDCTocEUR();
    swapcEURtoBridgedUSDC();
    swapBridgedUSDCtocBRL();
    swapcBRLtoBridgedUSDC();
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

  function swapBridgedUSDCTocUSD() internal {
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
      cUSDUSDCConfig.referenceRateFeedID,
      true
    );

    console2.log("\tbridgedUSDC -> cUSD swap successful 🚀");
  }

  function swapcUSDtoBridgedUSDC() internal {
    bytes32 exchangeID = BiPoolManager(biPoolManagerProxy).exchangeIds(3);

    address trader = vm.addr(1);
    address tokenIn = cUSD;
    address tokenOut = bridgedUSDC;
    uint256 amountIn = 10e18;

    // Mint some USDC to the reserve
    deal(bridgedUSDC, address(reserve), 1000e18, true);

    testAndPerformConstantSumSwap(
      exchangeID,
      trader,
      tokenIn,
      tokenOut,
      amountIn,
      cUSDUSDCConfig.referenceRateFeedID,
      false
    );

    console2.log("\tcUSD -> bridgedUSDC swap successful 🚀");
  }

  function swapBridgedUSDCTocEUR() internal {
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
      cEURUSDCConfig.referenceRateFeedID,
      true
    );

    console2.log("\tbridgedUSDC -> cEUR swap successful 🚀");
  }

  function swapcEURtoBridgedUSDC() internal {
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
      cEURUSDCConfig.referenceRateFeedID,
      false
    );

    console2.log("\tcEUR -> bridgedUSDC swap successful 🚀");
  }

  function swapBridgedUSDCtocBRL() internal {
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
      cBRLUSDCConfig.referenceRateFeedID,
      true
    );

    console2.log("\tbridgedUSDC -> cBRL swap successful 🚀");
  }

  function swapcBRLtoBridgedUSDC() internal {
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
      cBRLUSDCConfig.referenceRateFeedID,
      false
    );

    // swapStableToBridgedUsdc(exchangeID, trader, tokenIn, tokenOut, amountIn, cBRLUSDCConfig.referenceRateFeedID);

    console2.log("\tcBRL -> bridgedUSDC swap successful 🚀");
  }

  /* ================================================================ */
  /* ============================ Helpers =========================== */
  /* ================================================================ */

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
    uint256 amountOut = broker.getAmountOut(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn);
    IBiPoolManager.PoolExchange memory pool = BiPoolManager(biPoolManagerProxy).getPoolExchange(exchangeID);
    FixidityLib.Fraction memory spreadFraction = FixidityLib.newFixedFraction(3, 100);

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
    uint256 spreadValue = FixidityLib.newFixed(estimatedAmountOut).multiply(spreadFraction).fromFixed();
    assertApproxEqAbs(amountOut, estimatedAmountOut, spreadValue);

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
    uint256 amountOut = broker.getAmountOut(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn);
    (uint256 numerator, uint256 denominator) = SortedOracles(sortedOracles).medianRate(rateFeedID);
    FixidityLib.Fraction memory spreadFraction = FixidityLib.newFixedFraction(25, 1000);
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

    uint256 spreadValue = FixidityLib.newFixed(estimatedAmountOut).multiply(spreadFraction).fromFixed();
    assertApproxEqAbs(amountOut, estimatedAmountOut, spreadValue);

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
    uint256 beforeBuyingTokenOut = MockERC20(tokenOut).balanceOf(trader);
    uint256 beforeSellingTokenIn = MockERC20(tokenIn).balanceOf(trader);

    vm.startPrank(trader);
    MockERC20(tokenIn).approve(address(broker), amountIn);
    broker.swapIn(biPoolManagerProxy, exchangeID, tokenIn, tokenOut, amountIn, amountOut);
    assertEq(MockERC20(tokenOut).balanceOf(trader), beforeBuyingTokenOut + amountOut);
    assertEq(MockERC20(tokenIn).balanceOf(trader), beforeSellingTokenIn - amountIn);
    vm.stopPrank();
  }

  function setUpConfigs() internal {
    // Create pool configurations
    cUSDCeloConfig = MU03Config.cUSDCeloConfig(contracts);
    cEURCeloConfig = MU03Config.cEURCeloConfig(contracts);
    cBRLCeloConfig = MU03Config.cBRLCeloConfig(contracts);
    cUSDUSDCConfig = MU03Config.cUSDUSDCConfig(contracts);
    cEURUSDCConfig = MU03Config.cEURUSDCConfig(contracts);
    cBRLUSDCConfig = MU03Config.cBRLUSDCConfig(contracts);

    // Push them to the array
    poolConfigs.push(cUSDCeloConfig);
    poolConfigs.push(cEURCeloConfig);
    poolConfigs.push(cBRLCeloConfig);
    poolConfigs.push(cUSDUSDCConfig);
    poolConfigs.push(cEURUSDCConfig);
    poolConfigs.push(cBRLUSDCConfig);
  }

  function getBiPoolManager() internal view returns (BiPoolManager) {
    return BiPoolManager(broker.getExchangeProviders()[0]);
  }
}
