// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { TempStable } from "mento-core-2.6.4/tokens/TempStable.sol";

/**
 yarn deploy -n <network> -u cGHS-rename -s cGHS-Rename-Deploy-Implementation.sol
 */
contract cGHS_RenameDeployImplementation is Script {
  function run() public {
    address tempImplementation;
    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      // Temp implementation
      tempImplementation = address(new TempStable());
      TempStable(tempImplementation).transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("TempStable deployed at: ", tempImplementation);
    console2.log("TempStable(%s) ownership transferred to %s", tempImplementation, governance);
    console2.log("----------");
  }
}
