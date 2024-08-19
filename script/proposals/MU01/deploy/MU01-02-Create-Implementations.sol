// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/v1/Script.sol";
import { Chain } from "script/utils/v1/Chain.sol";
import { console } from "forge-std/console.sol";

import { BreakerBox } from "mento-core-2.0.0/BreakerBox.sol";
import { BiPoolManager } from "mento-core-2.0.0/BiPoolManager.sol";
import { Broker } from "mento-core-2.0.0/Broker.sol";
import { Reserve } from "mento-core-2.0.0/Reserve.sol";
import { StableToken } from "mento-core-2.0.0/StableToken.sol";
import { StableTokenBRL } from "mento-core-2.0.0/StableTokenBRL.sol";
import { StableTokenEUR } from "mento-core-2.0.0/StableTokenEUR.sol";
import { SortedOracles } from "mento-core-2.0.0/SortedOracles.sol";

/*
 yarn deploy -n <network> -u MU01 -s MU01-02-Create-Implementations.sol
*/
contract MU01_CreateImplementations is Script {
  function run() public {
    address breakerBox;
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
      breakerBox = address(new BreakerBox(false));
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

    console.log("----------");
    console.log("BreakerBox deployed at: ", breakerBox);
    console.log("BiPoolManager deployed at: ", biPoolManager);
    console.log("Broker deployed at: ", broker);
    console.log("Reserve deployed at: ", reserve);
    console.log("StableToken deployed at: ", stableToken);
    console.log("StableTokenEUR deployed at: ", stableTokenEUR);
    console.log("StableTokenBRL deployed at: ", stableTokenBRL);
    console.log("SortedOracles deployed at: ", sortedOracles);
    console.log("----------");
  }
}
