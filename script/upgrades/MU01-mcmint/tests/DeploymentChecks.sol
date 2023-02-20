// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console2 } from "forge-std/Script.sol";
import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";

import { IBroker } from "mento-core/contracts/interfaces/IBroker.sol";
import { IStableToken } from "mento-core/contracts/interfaces/IStableToken.sol";
import { IExchangeProvider } from "mento-core/contracts/interfaces/IExchangeProvider.sol";
import { Reserve } from "mento-core/contracts/Reserve.sol";
import { IERC20Metadata } from "mento-core/contracts/common/interfaces/IERC20Metadata.sol";
import { IERC20 } from "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import { BiPoolManager } from "mento-core/contracts/BiPoolManager.sol";
import { IBiPoolManager } from "mento-core/contracts/interfaces/IBiPoolManager.sol";
import { MockERC20 } from "../../../../contracts/MockERC20.sol";
import { Arrays } from "script/utils/Arrays.sol";

import { IBreakerBox } from "mento-core/contracts/interfaces/IBreakerBox.sol";

import { Broker } from "mento-core/contracts/Broker.sol";
import { BreakerBox } from "mento-core/contracts/BreakerBox.sol";

import { TradingLimits } from "mento-core/contracts/common/TradingLimits.sol";

import { PrecompileHandler } from "celo-foundry/PrecompileHandler.sol";

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

contract DeploymentChecks is Script {
  using TradingLimits for TradingLimits.Config;

  IBroker private broker;
  BreakerBox private breakerBox;
  Reserve public reserve;

  address public celoToken;
  address public cUSD;
  address public cEUR;
  address public cBRL;
  address public usdCet;

  function setUp() public {
    PrecompileHandler handler = new PrecompileHandler(); // needed for reserve CELO transfer checks

    // Load addresses from deployments
    contracts.load("MU01-00-Create-Proxies", "1676642018");
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "1676642105");
    contracts.load("MU01-02-Create-Implementations", "1676642427");

    // Get proxy addresses of the deployed tokens
    cUSD = contracts.celoRegistry("StableToken");
    cEUR = contracts.celoRegistry("StableTokenEUR");
    cBRL = contracts.celoRegistry("StableTokenBRL");

    usdCet = contracts.dependency("USDCet");
    celoToken = contracts.celoRegistry("GoldToken");
    broker = IBroker(contracts.celoRegistry("Broker"));
    breakerBox = BreakerBox(contracts.deployed("BreakerBox"));
    reserve = Reserve(contracts.deployed("PartialReserveProxy"));
  }

  function run() public {
    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      swapCeloTocUSD();
    }
    vm.stopBroadcast();
  }

  function runInFork() public {
    setUp();
    vm.deal(address(this), 1e20);

    verifyPartialReserve();
    verifyBroker();

    doSwaps();
  }

  /* ================================================================ */
  /* =================== Partial Reserve checks ===================== */
  /* ================================================================ */

  function verifyPartialReserve() public {
    console2.log("\n== Verifying partial reserve... ==");

    checkReserveCollateralAssets();
    checkReserveStableAssets();
    checkReserveSpenders();
    checkReserveMultisigCanSpend();
  }

  function checkReserveCollateralAssets() public {
    require(reserve.checkIsCollateralAsset(celoToken), "CELO is not collateral asset");
    require(reserve.checkIsCollateralAsset(usdCet), "USDCet is not collateral asset");

    console2.log("\t collateral assets are added 🎉");
  }

  function checkReserveStableAssets() public {
    require(reserve.isStableAsset(cUSD), "cUSD is not a stable asset");
    require(reserve.isStableAsset(cEUR), "cEUR is not a stable asset");
    require(reserve.isStableAsset(cBRL), "cBRL is not a stable asset!!");

    console2.log("\t stable assets are added 🥹");
  }

  function checkReserveSpenders() public {
    require(reserve.isExchangeSpender(address(broker)), "Broker is not an exchange spender");

    address spenderMultiSig = contracts.dependency("PartialReserveMultisig");
    require(reserve.isSpender(spenderMultiSig), "Mento multisig is not a spender");

    console2.log("\t spender addresses are added 😮");
  }

  function checkReserveMultisigCanSpend() public {
    uint256 oneMillion = 1_000_000 * 1e18;

    assert (address(reserve).balance == 0);
    assert (MockERC20(usdCet).balanceOf(address(reserve)) == 0);

    vm.deal(address(reserve), oneMillion);
    vm.prank(MockERC20(usdCet).owner());
    MockERC20(usdCet).mint(address(reserve), oneMillion);

    address payable mainReserve = address(uint160(contracts.celoRegistry("Reserve")));
    uint256 prevMainReserveCeloBalance = address(mainReserve).balance;

    address multiSigAddr = contracts.dependency("PartialReserveMultisig");
    vm.startPrank(multiSigAddr);
    reserve.transferCollateralAsset(celoToken, mainReserve, oneMillion);
    reserve.transferCollateralAsset(usdCet, mainReserve, oneMillion);
    vm.stopPrank();

    assert (address(reserve).balance == 0);
    assert (address(mainReserve).balance == prevMainReserveCeloBalance + oneMillion);

    assert (MockERC20(usdCet).balanceOf(address(reserve)) == 0);
    assert (MockERC20(usdCet).balanceOf(address(mainReserve)) == oneMillion);

    console2.log("\t multiSig spender can spend collateral assets 🤑");
  } 

  /* ================================================================ */
  /* ========================= Broker checks ======================== */
  /* ================================================================ */

  function verifyBroker() public {
    console2.log("\n== Verifying broker... ==");

    verifyExchangeProviders();
    verifyBiPoolManager();
    verifyExchanges();
    verifyTradingLimits();
  }

  function verifyExchangeProviders() public view {
    address[] memory exchangeProviders = broker.getExchangeProviders();
    if (exchangeProviders.length != 1) {
      console2.log("Exchange provider count was %s but should have been 1", exchangeProviders.length);
      revert("Exchange provider count was not 1");
    }
    console2.log("\tchecked exchange providers ✅");
  }

  function verifyBiPoolManager() public view {
    address[] memory exchangeProviders = broker.getExchangeProviders();
    address biPoolManager = exchangeProviders[0];

    // Get the address of the deployed BiPoolManagerProxy from the deployment json.
    address expectedBiPoolManager = contracts.deployed("BiPoolManagerProxy");
    if (biPoolManager != expectedBiPoolManager) {
      console2.log(
        "The address of the BiPool manager retrieved from the Broker was not the address found in the deployment json."
      );
      console2.log("Expected address:", expectedBiPoolManager);
      console2.log("Actual address:", biPoolManager);

      revert("BiPoolManager address found was not expected. See logs.");
    }
    console2.log("\tchecked biPoolManager address 🫡");
  }

  function verifyExchanges() public view {
    BiPoolManager bpm = getBiPoolManager();
    bytes32[] memory exchanges = bpm.getExchangeIds();

    for (uint256 i = 0; i < exchanges.length; i++) {
      bytes32 exchangeId = exchanges[i];
      IBiPoolManager.PoolExchange memory pool = bpm.getPoolExchange(exchangeId);

      require (
        pool.asset0 == cUSD || pool.asset0 == cEUR || pool.asset0 == cBRL,
        "asset0 is not a stable asset in the exchange"
      );
      require(
        pool.asset1 == celoToken || pool.asset1 == usdCet,
        "asset1 is not celo or usdcet in the exchange"
      );
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

      if (
        limits.timestep0 == 0 ||
        limits.timestep1 == 0 ||
        limits.limit0 == 0 ||
        limits.limit1 == 0
      ) {
        console2.log("The trading limit for %s, %s was not set ❌", pool.asset0, pool.asset1);
        revert("Not all trading limits were set.");
      }
    }

    console2.log("\tTrading limits set for all exchanges 🔒");
  }

  function verifyCircuitBreaker() public view {
    address[] memory configuredBreakers = Arrays.addresses(
      cUSD, cEUR, cBRL, usdCet
    );

    for (uint256 i = 0; i < configuredBreakers.length; i++) {
      address token = configuredBreakers[i];
      (, uint64 lastUpdatedTime, ) = breakerBox.rateFeedTradingModes(token);

      // if configured, TradingModeInfo.lastUpdatedTime is greater than zero
      if (lastUpdatedTime == 0) {
        console2.log("Circuit breaker for %s was not set ❌", token);
        revert("Not all breakers were set.");
      }
    }

    console2.log("\tCircuit breakers set for all tokens 😬");
  }

  /* ================================================================ */
  /* ============================= Swaps =========================== */
  /* ================================================================ */

  function doSwaps() public {
    console2.log("\n== Doing some test swaps... ==");
    swapCeloTocUSD();
    swapUSDcetTocUSD();
    swapcUSDtoUSDcet();
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

  function swapUSDcetTocUSD() public {
    BiPoolManager bpm = getBiPoolManager();
    bytes32 exchangeID = bpm.exchangeIds(3);

    address trader = vm.addr(1);
    address tokenIn = usdCet;
    address tokenOut = cUSD;
    uint256 amountIn = 100e18;
    uint256 amountOut = broker.getAmountOut(address(bpm), exchangeID, tokenIn, tokenOut, amountIn);

    MockERC20 mockUSDcetContract = MockERC20(usdCet);

    assert(mockUSDcetContract.balanceOf(trader) == 0);
    vm.prank(mockUSDcetContract.owner());
    assert(mockUSDcetContract.mint(trader, amountIn));
    assert(mockUSDcetContract.balanceOf(trader) == amountIn);

    vm.startPrank(trader);
    uint256 beforecUSD = MockERC20(cUSD).balanceOf(trader);
    mockUSDcetContract.approve(address(broker), amountIn);

    broker.swapIn(address(bpm), exchangeID, tokenIn, tokenOut, amountIn, amountOut);

    assert(mockUSDcetContract.balanceOf(trader) == 0);
    assert(MockERC20(cUSD).balanceOf(trader) == beforecUSD + amountOut);
    vm.stopPrank();

    console2.log("\tUSDCet -> cUSD swap successful 🚀");
  }

  function swapcUSDtoUSDcet() public {
    BiPoolManager bpm = getBiPoolManager();
    bytes32 exchangeID = bpm.exchangeIds(3);

    address trader = vm.addr(1);
    address tokenIn = cUSD;
    address tokenOut = usdCet;
    uint256 amountIn = 10e18;
    uint256 amountOut = broker.getAmountOut(address(bpm), exchangeID, tokenIn, tokenOut, amountIn);

    // fund reserve with usdc
    MockERC20 mockUSDcetContract = MockERC20(usdCet);
    vm.prank(mockUSDcetContract.owner());
    assert(mockUSDcetContract.mint(address(reserve), 1000e18));

    vm.startPrank(trader);
    MockERC20(cUSD).approve(address(broker), amountIn);
    broker.swapIn(address(bpm), exchangeID, tokenIn, tokenOut, amountIn, amountOut);
    vm.stopPrank();

    console2.log("\tcUSD -> USDCet swap successful 🚀");
  }

  /* ================================================================ */
  /* ============================ Helpers =========================== */
  /* ================================================================ */

  function getBiPoolManager() public view returns (BiPoolManager) {
    return BiPoolManager(broker.getExchangeProviders()[0]);
  }
}
