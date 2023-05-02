// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { BiPoolManager } from "mento-core/contracts/BiPoolManager.sol";

/*
 forge script MU01_DeployBiPoolManager --rpc-url $RPC_URL
                             --broadcast --legacy 
                             --verify --verifier sourcify 
*/
contract MU01_DeployBiPoolManager is Script {
  function run() public {
    address biPoolManager;

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      // Updated implementation
      biPoolManager = address(new BiPoolManager(false));
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("BiPoolManager deployed at: ", biPoolManager);
    console2.log("----------");
  }
}
