// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { StableTokenXOF } from "mento-core-2.2.0/legacy/StableTokenXOF.sol";

/*
 yarn deploy -n <network> -u eXOF -s eXOF-01-Create-Implementations.sol
*/
contract eXOF_CreateImplementations is Script {
  function run() public {
    address stableTokenXOF;
    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenXOF = address(new StableTokenXOF(false));
      StableTokenXOF(stableTokenXOF).transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenXOF deployed at: ", stableTokenXOF);
    console2.log("StableTokenXOF(%s) ownership transferred to %s", stableTokenXOF, governance);
    console2.log("----------");
  }
}
