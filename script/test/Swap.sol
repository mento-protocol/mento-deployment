// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Script } from "script/utils/Script.sol";
import { console2 } from "forge-std/Script.sol";
import { IBroker } from "mento-core/contracts/interfaces/IBroker.sol";
import { IExchangeProvider } from "mento-core/contracts/interfaces/IExchangeProvider.sol";
import { IERC20Metadata } from "mento-core/contracts/common/interfaces/IERC20Metadata.sol";
import { BiPoolManager } from "mento-core/contracts/BiPoolManager.sol";
import { IBiPoolManager } from "mento-core/contracts/interfaces/IBiPoolManager.sol";

contract SwapTest is Script {
  BiPoolManager bpm;

  address celoToken;
  address cUSD;
  address cEUR;

  function setup() public {
    // Load addresses from deployments
    contracts.load("00-CircuitBreaker", "1673898407");
    contracts.load("01-Broker", "1673898735");

    // Get proxy addresses of the deployed tokens
    cUSD = contracts.celoRegistry("StableToken");
    cEUR = contracts.celoRegistry("StableTokenEUR");
    celoToken = contracts.celoRegistry("GoldToken");
  }

  function run() public {
    setup();

    IBroker broker = IBroker(contracts.celoRegistry("Broker"));

    address[] memory exchangeProviders = broker.getExchangeProviders();
    verifyExchangeProviders(exchangeProviders);

    bpm = BiPoolManager(exchangeProviders[0]);
    verifyBiPoolManager(address(bpm));

    vm.startBroadcast();
    {
      bytes32 exchangeID = bpm.exchangeIds(0);
      verifyExchange(exchangeID);

      address tokenIn = celoToken;
      address tokenOut = cUSD;

      uint256 amountOut = broker.getAmountOut(exchangeProviders[0], exchangeID, tokenIn, tokenOut, 1e20);

      console2.log("Expected amount out:", amountOut);

      IERC20Metadata(contracts.celoRegistry("GoldToken")).approve(address(broker), 1e20);
      broker.swapIn(exchangeProviders[0], exchangeID, tokenIn, tokenOut, 1e20, amountOut - 1e18);
    }
    vm.stopBroadcast();
  }

  function verifyBiPoolManager(address biPoolManager) public {
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

  function verifyExchangeProviders(address[] memory exchangeProviders) public {
    if (exchangeProviders.length != 1) {
      console2.log("Exchange provider count was %s but should have been 1", exchangeProviders.length);
      revert("Exchange provider count was not 1");
    }
  }

  function verifyExchange(bytes32 exchangeID) public {
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
