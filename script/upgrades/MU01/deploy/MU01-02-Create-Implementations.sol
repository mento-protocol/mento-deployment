// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { BreakerBox } from "mento-core/contracts/BreakerBox.sol";
import { BiPoolManager } from "mento-core/contracts/BiPoolManager.sol";
import { Broker } from "mento-core/contracts/Broker.sol";
import { Reserve } from "mento-core/contracts/Reserve.sol";
import { StableToken } from "mento-core/contracts/StableToken.sol";
import { StableTokenBRL } from "mento-core/contracts/StableTokenBRL.sol";
import { StableTokenEUR } from "mento-core/contracts/StableTokenEUR.sol";
import { SortedOracles } from "mento-core/contracts/SortedOracles.sol";

/*
 forge script MU01_CreateImplementations --rpc-url $RPC_URL
                             --broadcast --legacy 
                             --verify --verifier sourcify 
*/
contract MU01_CreateImplementations is Script {
  function run() public {
    // BreakerBox has changed and is no longer upgradable
    // address breakerBox;
    address biPoolManager;
    address broker;
    address reserve;
    address stableToken;
    address stableTokenBRL;
    address stableTokenEUR;
    address sortedOracles;

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      // New implementations
      // BreakerBox has changed and is no longer upgradable
      // breakerBox = address(new BreakerBox(false));
      biPoolManager = address(new BiPoolManager(false));
      broker = address(new Broker(false));

      // Updated implementations
      reserve = address(new Reserve(false));
      stableToken = address(new StableToken(false));
      stableTokenBRL = address(new StableTokenBRL(false));
      stableTokenEUR = address(new StableTokenEUR(false));
      sortedOracles = address(new SortedOracles(false));
    }
    vm.stopBroadcast();

    console2.log("----------");
    // BreakerBox has changed and is no longer upgradable
    // console2.log("BreakerBox deployed at: ", breakerBox);
    console2.log("BiPoolManager deployed at: ", biPoolManager);
    console2.log("Broker deployed at: ", broker);
    console2.log("Reserve deployed at: ", reserve);
    console2.log("StableToken deployed at: ", stableToken);
    console2.log("StableTokenEUR deployed at: ", stableTokenEUR);
    console2.log("StableTokenBRL deployed at: ", stableTokenBRL);
    console2.log("SortedOracles deployed at: ", sortedOracles);
    console2.log("----------");
  }
}
