// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { BiPoolManager } from "mento-core-2.2.0/swap/BiPoolManager.sol";

/*
 yarn deploy -n <network> -u MU01 -s MU01-02-Create-Implementations.sol
*/
contract MU03_CreateImplementations is Script {
  function run() public {
    address biPoolManager;

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      // Updated implementations
      biPoolManager = address(new BiPoolManager(false));
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("BiPoolManager deployed at: ", biPoolManager);
    console2.log("----------");
  }
}