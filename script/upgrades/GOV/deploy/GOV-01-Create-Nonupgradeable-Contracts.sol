// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { console2, Script } from "forge-std/Script.sol";
import { GovernanceFactory } from "mento-core-gov/governance/GovernanceFactory.sol";
import { IRegistry } from "script/interfaces/IRegistry.sol";

/*
 yarn deploy -n <network> -u GOV -s GOV-01-Create-Nonupgradeable-Contracts.sol
*/
contract GOV_CreateNonupgradeableContracts is Script {
  address constant REGISTRY_ADDRESS = 0x000000000000000000000000000000000000ce10;

  function run() public {
    IRegistry registry = IRegistry(REGISTRY_ADDRESS);
    address celoGovernance = registry.getAddressForStringOrDie("Governance");

    address governanceFactory;
    uint privateKey = vm.envUint("MENTO_DEPLOYER_PK");

    vm.startBroadcast(privateKey);
    // governanceFactory = address(new GovernanceFactory(celoGovernance));
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("GovernanceFactory deployed at: ", governanceFactory);
    console2.log("----------");
  }
}
