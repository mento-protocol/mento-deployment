// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { Script, console2 } from "forge-std-next/Script.sol";
import { TempStable } from "mento-core-2.6.4/tokens/TempStable.sol";
import { IRegistry } from "../../../interfaces/IRegistry.sol";

/**
 yarn deploy -n <network> -u cGHS-rename -s cGHS-Rename-Deploy-Implementation.sol
 */

interface IOwnableLite {
  function transferOwnership(address newOwner) external;
}

contract cGHS_TempImplementation is Script {
  function run() public {
    address tempImplementation;

    IRegistry registry = IRegistry(0x000000000000000000000000000000000000ce10);
    address governance = registry.getAddressForStringOrDie("Governance");

    vm.startBroadcast(vm.envUint("MENTO_DEPLOYER_PK"));
    {
      tempImplementation = address(new TempStable());
      IOwnableLite(tempImplementation).transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("TempStable deployed at: ", tempImplementation);
    console2.log("TempStable(%s) ownership transferred to %s", tempImplementation, governance);
    console2.log("----------");
  }
}
