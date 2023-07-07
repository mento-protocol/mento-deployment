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

import { IBiPoolManager } from "mento-core-2.2.0/interfaces/IBiPoolManager.sol";
import { IBroker } from "mento-core-2.2.0/interfaces/IBroker.sol";

import { BiPoolManagerProxy } from "mento-core-2.2.0/proxies/BiPoolManagerProxy.sol";
import { BrokerProxy } from "mento-core-2.2.0/proxies/BrokerProxy.sol";
import { Broker } from "mento-core-2.2.0/swap/Broker.sol";
import { BiPoolManager } from "mento-core-2.2.0/swap/BiPoolManager.sol";
import { Exchange } from "mento-core-2.2.0/legacy/Exchange.sol";
import { TradingLimits } from "mento-core-2.2.0/libraries/TradingLimits.sol";
import { BreakerBox } from "mento-core-2.2.0/oracles/BreakerBox.sol";
import { MedianDeltaBreaker } from "mento-core-2.2.0/oracles/breakers/MedianDeltaBreaker.sol";
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
  function tradingLimitsState(bytes32 id) external view returns (TradingLimits.State memory);

  function tradingLimitsConfig(bytes32 id) external view returns (TradingLimits.Config memory);
}

contract MU03Checks is Script, Test {
  using TradingLimits for TradingLimits.Config;

  BreakerBox private breakerBox;
  IBroker private broker;

  address public celoToken;
  address public cUSD;
  address public cEUR;
  address public cBRL;
  address public bridgedUSDC;
  address public governance;

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
    contracts.load("MU03-01-Create-Nonupgradeable-Contracts", "latest");
    contracts.load("MU03-02-Create-Implementations", "latest");

    // Get proxy addresses of the deployed tokens
    cUSD = contracts.celoRegistry("StableToken");
    cEUR = contracts.celoRegistry("StableTokenEUR");
    cBRL = contracts.celoRegistry("StableTokenBRL");

    bridgedUSDC = contracts.dependency("BridgedUSDC");
    celoToken = contracts.celoRegistry("GoldToken");
    broker = IBroker(contracts.celoRegistry("Broker"));
    breakerBox = BreakerBox(contracts.deployed("BreakerBox"));
    governance = contracts.celoRegistry("Governance");
    // reserve = Reserve(contracts.deployed("PartialReserveProxy"));

    setUpConfigs();
  }

  function run() public {
    setUp();
    vm.deal(address(this), 1e20);

    verifyOwner();
    verifyBiPoolManager();
    verifyExchanges();
    verifyTradingLimits();

    // doSwaps();
  }

  function verifyOwner() public view {
    require(
      BiPoolManager(contracts.deployed("BiPoolManager")).owner() == governance,
      "BiPoolManager ownership not transferred to governance"
    );
    require(
      BreakerBox(contracts.deployed("BreakerBox")).owner() == governance,
      "BreakerBox ownership not transferred to governance"
    );
    require(
      MedianDeltaBreaker(contracts.deployed("MedianDeltaBreaker")).owner() == governance,
      "MedianDeltaBreaker ownership not transferred to governance"
    );
    console2.log("Contract ownerships transferred to governance 🤝");
  }

  function verifyBiPoolManager() public view {
    BiPoolManagerProxy bpmProxy = BiPoolManagerProxy(contracts.deployed("BiPoolManagerProxy"));
    address bpmProxyImplementation = bpmProxy._getImplementation();
    console2.log("proxy points to this: %s", bpmProxyImplementation);
    console2.log("bipool manager loaded from broadcasr: %s", contracts.deployed("BiPoolManager"));
    address expectedBiPoolManager = contracts.deployed("BiPoolManager");
    if (bpmProxyImplementation != expectedBiPoolManager) {
      console2.log(
        "The address of the BiPool manager retrieved from the BiPoolManagerProxy was not the address found in the deployment json."
      );
      console2.log("Expected address:", expectedBiPoolManager);
      console2.log("Actual address:", bpmProxyImplementation);

      revert("BiPoolManager address found was not expected. See logs.");
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

      require(pool.asset0 == poolConfigs[i].asset0, "asset0 does not match config");
      require(pool.asset1 == poolConfigs[i].asset1, "asset1 does not match config");

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
        require(poolConfigs[i].asset0_limit0 == limits.limit0, "limit0 does not match config");
        require(poolConfigs[i].asset0_limit1 == limits.limit1, "limit1 does not match config");
        require(poolConfigs[i].asset0_limitGlobal == limits.limitGlobal, "limitGlobal does not match config");
        require(poolConfigs[i].asset0_timeStep0 == limits.timestep0, "timestep0 does not match config");
        require(poolConfigs[i].asset0_timeStep1 == limits.timestep1, "timestep1 does not match config");
      }
      console2.log("\tTrading limits set for all exchanges 🔒");
    }

  //   function verifyCircuitBreaker() public view {
  //     address[] memory configuredBreakers = Arrays.addresses(cUSD, cEUR, cBRL, bridgedUSDC);

  //     for (uint256 i = 0; i < configuredBreakers.length; i++) {
  //       address token = configuredBreakers[i];
  //       (, uint64 lastUpdatedTime, ) = breakerBox.rateFeedTradingModes(token);

  //       // if configured, TradingModeInfo.lastUpdatedTime is greater than zero
  //       if (lastUpdatedTime == 0) {
  //         console2.log("Circuit breaker for %s was not set ❌", token);
  //         revert("Not all breakers were set.");
  //       }
  //     }

  //     console2.log("\tCircuit breakers set for all tokens 😬");
  //   }

  /* ================================================================ */
  /* ============================= Swaps =========================== */
  /* ================================================================ */

  //   function doSwaps() public {
  //     console2.log("\n== Doing some test swaps... ==");
  //     swapCeloTocUSD();
  //     swapBridgedUSDCTocUSD();
  //     swapcUSDtoBridgedUSDC();
  //   }

  //   function swapCeloTocUSD() public {
  //     BiPoolManager bpm = getBiPoolManager();
  //     bytes32 exchangeID = bpm.exchangeIds(0);

  //     address tokenIn = celoToken;
  //     address tokenOut = cUSD;

  //     uint256 amountOut = broker.getAmountOut(address(bpm), exchangeID, tokenIn, tokenOut, 1e18);

  //     IERC20Metadata(contracts.celoRegistry("GoldToken")).approve(address(broker), 1e18);
  //     broker.swapIn(address(bpm), exchangeID, tokenIn, tokenOut, 1e18, amountOut - 1e17);

  //     console2.log("\tCELO -> cUSD swap successful 🚀");
  //   }

  //   function swapBridgedUSDCTocUSD() public {
  //     BiPoolManager bpm = getBiPoolManager();
  //     bytes32 exchangeID = bpm.exchangeIds(3);

  //     address trader = vm.addr(1);
  //     address tokenIn = bridgedUSDC;
  //     address tokenOut = cUSD;
  //     uint256 amountIn = 100e6;
  //     uint256 amountOut = broker.getAmountOut(address(bpm), exchangeID, tokenIn, tokenOut, amountIn);

  //     MockERC20 mockBridgedUSDCContract = MockERC20(bridgedUSDC);

  //     assert(mockBridgedUSDCContract.balanceOf(trader) == 0);
  //     deal(bridgedUSDC, trader, amountIn, true);
  //     assert(mockBridgedUSDCContract.balanceOf(trader) == amountIn);

  //     vm.startPrank(trader);
  //     uint256 beforecUSD = MockERC20(cUSD).balanceOf(trader);
  //     mockBridgedUSDCContract.approve(address(broker), amountIn);

  //     broker.swapIn(address(bpm), exchangeID, tokenIn, tokenOut, amountIn, amountOut);

  //     assert(mockBridgedUSDCContract.balanceOf(trader) == 0);
  //     assert(MockERC20(cUSD).balanceOf(trader) == beforecUSD + amountOut);
  //     vm.stopPrank();

  //     console2.log("\tbridgedUSDC -> cUSD swap successful 🚀");
  //   }

  //   function swapcUSDtoBridgedUSDC() public {
  //     BiPoolManager bpm = getBiPoolManager();
  //     bytes32 exchangeID = bpm.exchangeIds(3);

  //     address trader = vm.addr(1);
  //     address tokenIn = cUSD;
  //     address tokenOut = bridgedUSDC;
  //     uint256 amountIn = 10e18;
  //     uint256 amountOut = broker.getAmountOut(address(bpm), exchangeID, tokenIn, tokenOut, amountIn);

  //     // fund reserve with usdc
  //     MockERC20 mockBridgedUSDCContract = MockERC20(bridgedUSDC);
  //     deal(bridgedUSDC, address(reserve), 1000e18, true);

  //     vm.startPrank(trader);
  //     MockERC20(cUSD).approve(address(broker), amountIn);
  //     broker.swapIn(address(bpm), exchangeID, tokenIn, tokenOut, amountIn, amountOut);
  //     vm.stopPrank();

  //     console2.log("\tcUSD -> bridgedUSDC swap successful 🚀");
  //   }

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

    // Set the exchange ID for the reference rate feed
    // for (uint i = 0; i < poolConfigs.length; i++) {
    //   referenceRateFeedIDToExchangeId[poolConfigs[i].referenceRateFeedID] = getExchangeId(
    //     poolConfigs[i].asset0,
    //     poolConfigs[i].asset1,
    //     poolConfigs[i].isConstantSum
    //   );
    // }
  }

  function getBiPoolManager() public view returns (BiPoolManager) {
    return BiPoolManager(broker.getExchangeProviders()[0]);
  }
}
