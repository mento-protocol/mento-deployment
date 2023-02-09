// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console2 } from "forge-std/Script.sol";
import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";

import { IBroker } from "mento-core/contracts/interfaces/IBroker.sol";
import { IStableToken } from "mento-core/contracts/interfaces/IStableToken.sol";
import { IExchangeProvider } from "mento-core/contracts/interfaces/IExchangeProvider.sol";
import { IERC20Metadata } from "mento-core/contracts/common/interfaces/IERC20Metadata.sol";
import { BiPoolManager } from "mento-core/contracts/BiPoolManager.sol";
import { IBiPoolManager } from "mento-core/contracts/interfaces/IBiPoolManager.sol";

interface IMockERC20 {
  // need to define this because we don't have a single interface with all this methods
  function approve(address, uint256) external returns (bool);

  function balanceOf(address) external view returns (uint256);

  function mint(address, uint256) external returns (bool);

  function owner() external returns (address);
}

contract SwapTest is Script {
  IBroker broker;
  BiPoolManager bpm;

  address celoToken;
  address cUSD;
  address cEUR;
  address USDcet;

  function setUp() public {
    // Load addresses from deployments
    contracts.load("MU01-00-Create-Proxies", "1674224277");
    contracts.load("MU01-01-Create-Nonupgradeable-Contracts", "1674224321");
    contracts.load("MU01-02-Create-Implementations", "1674225880");

    // Get proxy addresses of the deployed tokens
    cUSD = contracts.celoRegistry("StableToken");
    cEUR = contracts.celoRegistry("StableTokenEUR");
    USDcet = contracts.dependency("MockUSDCet");
    celoToken = contracts.celoRegistry("GoldToken");
    broker = IBroker(contracts.celoRegistry("Broker"));

    address[] memory exchangeProviders = broker.getExchangeProviders();
    verifyExchangeProviders(exchangeProviders);

    bpm = BiPoolManager(exchangeProviders[0]);
    verifyBiPoolManager(address(bpm));
  }

  function run() public {
    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      executeSwap();
    }
    vm.stopBroadcast();
  }

  function runInFork() public {
    setUp();
    vm.deal(address(this), 1e20);
    executeSwap();
    swapUSDcetForcUSD();
  }

  function executeSwap() public {
    bytes32 exchangeID = bpm.exchangeIds(0);
    verifyExchange(exchangeID);

    address tokenIn = celoToken;
    address tokenOut = cUSD;

    uint256 amountOut = broker.getAmountOut(address(bpm), exchangeID, tokenIn, tokenOut, 1e18);

    console2.log("CELO -> cUSD swap Expected amount out:", amountOut);

    IERC20Metadata(contracts.celoRegistry("GoldToken")).approve(address(broker), 1e18);
    broker.swapIn(address(bpm), exchangeID, tokenIn, tokenOut, 1e18, amountOut - 1e17);
  }

  function swapUSDcetForcUSD() public {
    address trader = address(this);
    bytes32 exchangeID = bpm.exchangeIds(3);

    address tokenIn = USDcet;
    address tokenOut = cUSD;
    uint256 amountIn = 100e18;
    uint256 amountOut = broker.getAmountOut(address(bpm), exchangeID, tokenIn, tokenOut, amountIn);

    IMockERC20 mockUSDcetContract = IMockERC20(USDcet);

    assert(mockUSDcetContract.balanceOf(trader) == 0);
    vm.prank(mockUSDcetContract.owner());
    assert(mockUSDcetContract.mint(trader, amountIn));
    assert(mockUSDcetContract.balanceOf(trader) == amountIn);

    uint256 beforecUSD = IMockERC20(cUSD).balanceOf(trader);
    mockUSDcetContract.approve(address(broker), amountIn);

    broker.swapIn(address(bpm), exchangeID, tokenIn, tokenOut, amountIn, amountOut);

    assert(mockUSDcetContract.balanceOf(trader) == 0);
    assert(IMockERC20(cUSD).balanceOf(trader) == beforecUSD + amountOut);

    console2.log("USDCet -> cUSD swap successful 🚀");
  }

  function verifyBiPoolManager(address biPoolManager) public view {
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
  }

  function verifyExchangeProviders(address[] memory exchangeProviders) public view {
    if (exchangeProviders.length != 1) {
      console2.log("Exchange provider count was %s but should have been 1", exchangeProviders.length);
      revert("Exchange provider count was not 1");
    }
  }

  function verifyExchange(bytes32 exchangeID) public view {
    // Get the exchane struct from the BiPoolManager
    IBiPoolManager.PoolExchange memory pool = bpm.getPoolExchange(exchangeID);

    // Verify asset0 is a stable asset, cEUR or cUSD.
    // This may not always be the case but pools were configured this way in the proposal.
    if (pool.asset0 != cEUR && pool.asset0 != cUSD) {
      console2.log("The asset0 of the exchange was not a stable asset.");
      console2.log("Expected asset0: cUSD(%s) OR cEUR(%s)", cUSD, cEUR);
      console2.log("Actual asset0:", pool.asset0);
      revert("Exchange was not configured as expected.");
    }
  }
}
