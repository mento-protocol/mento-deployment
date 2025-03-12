// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

/**
 yarn deploy -n <network> -u cGHS-rename -s cGHS-Rename-Deploy-Implementation.sol
 */

interface IOwnableLite {
  function transferOwnership(address newOwner) external;
}

contract cGHS_TempImplementation is Script {
  function run() public {
    address tempImplementation;
    address governance = contracts.celoRegistry("Governance");

    string memory path = string(abi.encodePacked("out/TempStable.sol/TempStable.json"));
    bytes memory bytecode = abi.encodePacked(vm.getCode(path), abi.encode(true));

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      assembly {
        tempImplementation := create(0, add(bytecode, 0x20), mload(bytecode))
      }
      IOwnableLite(tempImplementation).transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("TempStable deployed at: ", tempImplementation);
    console2.log("TempStable(%s) ownership transferred to %s", tempImplementation, governance);
    console2.log("----------");
  }
}
