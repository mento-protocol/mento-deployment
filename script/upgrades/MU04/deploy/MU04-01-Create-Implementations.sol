// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { StableTokenXOF } from "mento-core-2.2.0/legacy/StableTokenXOF.sol";

/*
 yarn deploy -n <network> -u MU04 -s MU04-01-Create-Implementations.sol
*/
contract MU01_CreateImplementations is Script {
  function run() public {
    address stableTokenXOF;

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      // New implementations
      stableTokenXOF = address(new StableTokenXOF(false));
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenXOF deployed at: ", stableTokenXOF);
    console2.log("----------");
  }
}
