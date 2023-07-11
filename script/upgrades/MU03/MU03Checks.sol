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

import { MU03Config, Config } from "./Config.sol";

// import { SortedOracles } from "mento-core-2.2.0/oracles/SortedOracles.sol";

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

  BreakerBox private breakerBox;
  Reserve private reserve;
  IBroker private broker;
  MockERC20 mockBridgedUSDCContract;

  address public celoToken;
  address public cUSD;
  address public cEUR;
  address public cBRL;
  address public bridgedUSDC;
  address public governance;
  address public medianDeltaBreaker;
  address public valueDeltaBreaker;
  address public breakerBoxAddress;
  address public biPoolManager;
  address public sortedOracles;

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
    breakerBoxAddress = contracts.deployed("BreakerBox");
    biPoolManager = contracts.deployed("BiPoolManager");

    mockBridgedUSDCContract = MockERC20(bridgedUSDC);

    setUpConfigs();
  }

  function run() public {
    setUp();
    vm.deal(address(this), 1e20);

    // verifyOwner();
    // verifyBiPoolManager();
    // verifyExchanges();
    // verifyTradingLimits();
    // verifyCircuitBreaker();
    // verifyReserveFraction();

    doSwaps();
  }

  function verifyOwner() public view {
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

  /* ================================================================ */
  /* =========================== Exchanges ========================== */
  /* ================================================================ */

  function verifyBiPoolManager() public view {
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
    console2.log("\tchecked biPoolManager address 🫡");
  }

  function verifyExchanges() public view {
    BiPoolManager bpm = getBiPoolManager();
    bytes32[] memory exchanges = bpm.getExchangeIds();

    // check configured pools against the config
    require(exchanges.length == poolConfigs.length, "not all pools were created");

    for (uint256 i = 0; i < exchanges.length; i++) {
      bytes32 exchangeId = exchanges[i];
      IBiPoolManager.PoolExchange memory pool = bpm.getPoolExchange(exchangeId);

      require(pool.asset0 == poolConfigs[i].asset0, "asset0 does not match the MU03 config");
      require(pool.asset1 == poolConfigs[i].asset1, "asset1 does not match the MU03 config");

      require(
        pool.asset0 == cUSD || pool.asset0 == cEUR || pool.asset0 == cBRL,
        "asset0 is not a stable asset in the exchange"
      );
      require(
        pool.asset1 == celoToken || pool.asset1 == bridgedUSDC,
        "asset1 is not CELO or bridgedUSDC in the exchange"
      );
      console2.log("asset0: %s, asset1: %s", pool.asset0, pool.asset1);
    }
    console2.log("\texchanges correctly configured 🤘🏼");
  }

  function verifyTradingLimits() public view {
    IBrokerWithCasts _broker = IBrokerWithCasts(address(broker));
    BiPoolManager bpm = getBiPoolManager();
    bytes32[] memory exchanges = bpm.getExchangeIds();

    for (uint256 i = 0; i < exchanges.length; i++) {
      bytes32 exchangeId = exchanges[i];
      IBiPoolManager.PoolExchange memory pool = bpm.getPoolExchange(exchangeId);
      bytes32 limitId = exchangeId ^ bytes32(uint256(uint160(pool.asset0)));
      TradingLimits.Config memory limits = _broker.tradingLimitsConfig(limitId);

      if (limits.timestep0 == 0 || limits.timestep1 == 0 || limits.limit0 == 0 || limits.limit1 == 0) {
        console2.log("The trading limit for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were set.");
      }
      require(
        poolConfigs[i].asset0_limit0 == limits.limit0,
        "configured limit0 does not match the one from MU03 config for the exchange"
      );
      require(
        poolConfigs[i].asset0_limit1 == limits.limit1,
        "configured limit1 does not match the one from MU03 config for the exchange"
      );
      require(
        poolConfigs[i].asset0_limitGlobal == limits.limitGlobal,
        "configured limitGlobal does not match the MU03 config"
      );
      require(
        poolConfigs[i].asset0_timeStep0 == limits.timestep0,
        "configured timestep0 does not match the MU03 config"
      );
      require(
        poolConfigs[i].asset0_timeStep1 == limits.timestep1,
        "configured timestep1 does not match the MU03 config"
      );
    }
    console2.log("\tTrading limits set for all exchanges 🔒");
  }

  function verifyReserveFraction() public view {
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

  function verifyCircuitBreaker() public view {
    console2.log("\n== Checking circuit breaker... ==");
    verifyBreakerBox();
    verifyMedianDeltaBreaker();
    verifyValueDeltaBreaker();
  }

  function verifyBreakerBox() public view {
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
        (, , bool medianDeltaStatus) = breakerBox.rateFeedBreakerStatus(
          poolConfigs[i].referenceRateFeedID,
          medianDeltaBreaker
        );
        if (!medianDeltaStatus) {
          console2.log("MedianDeltaBreaker not enabled for rate feed %s", poolConfigs[i].referenceRateFeedID);
          revert("MedianDeltaBreaker not enabled for all rate feeds");
        }

        if (poolConfigs[i].isValueDeltaBreakerEnabled) {
          (, , bool valueDeltaStatus) = breakerBox.rateFeedBreakerStatus(
            poolConfigs[i].referenceRateFeedID,
            valueDeltaBreaker
          );
          if (!valueDeltaStatus) {
            console2.log("ValueDeltaBreaker not enabled for rate feed %s", poolConfigs[i].referenceRateFeedID);
            revert("ValueDeltaBreaker not enabled for all rate feeds");
          }
        }
      }
    }
    console2.log("\tBreakers enabled for all rate feeds 🗳️");

    // verify that breakerBox address was updated in SortedOracles
    if (breakerBox != SortedOracles(sortedOracles).breakerBox()) {
      console2.log("BreakerBox address not updated in SortedOracles");
      revert("BreakerBox address not updated in SortedOracles");
    }
    console2.log("\tBreakerBox address updated in SortedOracles 🗳️");
  }

  function verifyMedianDeltaBreaker() public view {
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

        // verify coodown
        if (cooldown != poolConfigs[i].medianDeltaBreakerCooldown) {
          console2.log(
            "MedianDeltaBreaker cooldown not set correctly for rate feed %s",
            poolConfigs[i].referenceRateFeedID
          );
          revert("MedianDeltaBreaker cooldown not set correctly for all rate feeds");
        }

        // verify rate change threshold
        if (rateChangeThreshold != poolConfigs[i].medianDeltaBreakerThreshold.unwrap()) {
          console2.log(
            "MedianDeltaBreaker rate change threshold not set correctly for rate feed %s",
            poolConfigs[i].referenceRateFeedID
          );
          revert("MedianDeltaBreaker rate change threshold not set correctly for all rate feeds");
        }

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

  function verifyValueDeltaBreaker() public view {
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
        if (cooldown != poolConfigs[i].valueDeltaBreakerCooldown) {
          console2.log(
            "ValueDeltaBreaker cooldown not set correctly for rate feed %s",
            poolConfigs[i].referenceRateFeedID
          );
          revert("ValueDeltaBreaker cooldown not set correctly for all rate feeds");
        }

        // verify rate change threshold
        if (rateChangeThreshold != poolConfigs[i].valueDeltaBreakerThreshold.unwrap()) {
          console2.log(
            "ValueDeltaBreaker rate change threshold not set correctly for rate feed %s",
            poolConfigs[i].referenceRateFeedID
          );
          revert("ValueDeltaBreaker rate change threshold not set correctly for all rate feeds");
        }

        // verify smoothing factor
        if (referenceValue != poolConfigs[i].valueDeltaBreakerReferenceValue) {
          console2.log(
            "ValueDeltaBrealer reference value not set correctly for rate feed %s",
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

  function doSwaps() public {
    console2.log("\n== Doing some test swaps... ==");
    swapCeloTocUSD();
    swapBridgedUSDCTocUSD();
    swapcUSDtoBridgedUSDC();
    swapBridgedUSDCTocEUR();
    swapcEURtoBridgedUSDC();
    swapBridgedUSDCtocBRL();
    swapcBRLtoBridgedUSDC();
  }

  function swapCeloTocUSD() public {
    BiPoolManager bpm = getBiPoolManager();
    bytes32 exchangeID = bpm.exchangeIds(0);

    address tokenIn = celoToken;
    address tokenOut = cUSD;

    uint256 amountOut = broker.getAmountOut(address(bpm), exchangeID, tokenIn, tokenOut, 1e18);

    IERC20Metadata(contracts.celoRegistry("GoldToken")).approve(address(broker), 1e18);
    broker.swapIn(address(bpm), exchangeID, tokenIn, tokenOut, 1e18, amountOut - 1e17);

    console2.log("\tCELO -> cUSD swap successful 🚀");
  }

  function swapBridgedUSDCTocUSD() public {
    BiPoolManager bpm = getBiPoolManager();
    bytes32 exchangeID = bpm.exchangeIds(3);

    address trader = vm.addr(1);
    address tokenIn = bridgedUSDC;
    address tokenOut = cUSD;
    uint256 amountIn = 100e6;

    // Mint some USDC to trader
    deal(bridgedUSDC, trader, amountIn, true);

    doSwapIn(exchangeID, trader, tokenIn, tokenOut, amountIn);

    console2.log("\tbridgedUSDC -> cUSD swap successful 🚀");
  }

  function swapcUSDtoBridgedUSDC() public {
    BiPoolManager bpm = getBiPoolManager();
    bytes32 exchangeID = bpm.exchangeIds(3);

    address trader = vm.addr(1);
    address tokenIn = cUSD;
    address tokenOut = bridgedUSDC;
    uint256 amountIn = 10e18;

    // Fund reserve with USDC
    deal(bridgedUSDC, address(reserve), 1000e18, true);

    doSwapIn(exchangeID, trader, tokenIn, tokenOut, amountIn);

    console2.log("\tcUSD -> bridgedUSDC swap successful 🚀");
  }

  function swapBridgedUSDCTocEUR() public {
    BiPoolManager bpm = getBiPoolManager();
    bytes32 exchangeID = bpm.exchangeIds(4);

    address trader = vm.addr(3);
    address tokenIn = bridgedUSDC;
    address tokenOut = cEUR;
    uint256 amountIn = 100e6;

    // Mint some USDC to trader
    deal(bridgedUSDC, trader, amountIn, true);

    doSwapIn(exchangeID, trader, tokenIn, tokenOut, amountIn);

    console2.log("\tbridgedUSDC -> cEUR swap successful 🚀");
  }

  function swapcEURtoBridgedUSDC() public {
    BiPoolManager bpm = getBiPoolManager();
    bytes32 exchangeID = bpm.exchangeIds(4);

    address trader = vm.addr(3);
    address tokenIn = cEUR;
    address tokenOut = bridgedUSDC;
    uint256 amountIn = 10e18;

    doSwapIn(exchangeID, trader, tokenIn, tokenOut, amountIn);

    console2.log("\tcEUR -> bridgedUSDC swap successful 🚀");
  }

  function swapBridgedUSDCtocBRL() public {
    BiPoolManager bpm = getBiPoolManager();
    bytes32 exchangeID = bpm.exchangeIds(5);

    address trader = vm.addr(4);
    address tokenIn = bridgedUSDC;
    address tokenOut = cBRL;
    uint256 amountIn = 100e6;

    // Mint some USDC to trader
    deal(bridgedUSDC, trader, amountIn, true);

    doSwapIn(exchangeID, trader, tokenIn, tokenOut, amountIn);

    console2.log("\tbridgedUSDC -> cBRL swap successful 🚀");
  }

  function swapcBRLtoBridgedUSDC() public {
    BiPoolManager bpm = getBiPoolManager();
    bytes32 exchangeID = bpm.exchangeIds(5);

    address trader = vm.addr(4);
    address tokenIn = cBRL;
    address tokenOut = bridgedUSDC;
    uint256 amountIn = 10e18;

    doSwapIn(exchangeID, trader, tokenIn, tokenOut, amountIn);

    console2.log("\tcBRL -> bridgedUSDC swap successful 🚀");
  }

  function doSwapIn(bytes32 exchangeID, address trader, address tokenIn, address tokenOut, uint256 amountIn) public {
    BiPoolManager bpm = getBiPoolManager();

    uint256 amountOut = broker.getAmountOut(address(bpm), exchangeID, tokenIn, tokenOut, amountIn);
    uint256 beforeBuyingTokenOut = MockERC20(tokenOut).balanceOf(trader);
    uint256 beforeSellingTokenIn = MockERC20(tokenIn).balanceOf(trader);
    vm.startPrank(trader);
    MockERC20(tokenIn).approve(address(broker), amountIn);
    broker.swapIn(address(bpm), exchangeID, tokenIn, tokenOut, amountIn, amountOut);
    assertEq(MockERC20(tokenOut).balanceOf(trader), beforeBuyingTokenOut + amountOut);
    assertEq(MockERC20(tokenIn).balanceOf(trader), beforeSellingTokenIn - amountIn);
    vm.stopPrank();
  }

  /* ================================================================ */
  /* ============================ Helpers =========================== */
  /* ================================================================ */

  function setUpConfigs() public {
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

  function getBiPoolManager() public view returns (BiPoolManager) {
    return BiPoolManager(broker.getExchangeProviders()[0]);
  }
}
