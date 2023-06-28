// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { BiPoolManager } from "2.1.0/contracts/BiPoolManager.sol";

/**
 * To run:
 * yarn deploy -n <network> -m MU02 -s <filename>
 */
contract MU02_CreateImplementations is Script {
  function run() public {
    address biPoolManager;
    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      // Updated implementation
      biPoolManager = address(new BiPoolManager(false));
      BiPoolManager(biPoolManager).transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("BiPoolManager deployed at: ", biPoolManager);
    console2.log("BiPoolManager(%s) ownership transferred to %s", biPoolManager, governance);
    console2.log("----------");
  }
}
