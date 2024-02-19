// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { Script, console2 } from "forge-std-next/Script.sol";
import { GovernanceFactory } from "mento-core-2.3.0/governance/GovernanceFactory.sol";
import { IRegistry } from "../../../interfaces/IRegistry.sol";

contract MUGOV_CreateImplementations is Script {
  function run() public {
    IRegistry registry = IRegistry(0x000000000000000000000000000000000000ce10);
    address owner = registry.getAddressForStringOrDie("Governance");
    address governanceFactory;

    vm.startBroadcast(vm.envUint("MENTO_DEPLOYER_PK"));
    {
      governanceFactory = address(new GovernanceFactory(owner));
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("GovernanceFactory: ", governanceFactory);
    console2.log("----------");
  }
}
