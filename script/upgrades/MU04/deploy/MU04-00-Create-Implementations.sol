// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/v1/Script.sol";
import { Chain } from "script/utils/v1/Chain.sol";
import { console } from "forge-std/console.sol";

/*
 yarn deploy -n <network> -u MU04 -s MU04-00-Create-Implementations.sol
*/

interface IOwnableLite {
  function transferOwnership(address newOwner) external;
}

contract MU04_CreateImplementations is Script {
  function run() public {
    address stableTokenV2;
    address governance = contracts.celoRegistry("Governance");

    string memory path = string(abi.encodePacked("out/StableTokenV2.sol/StableTokenV2.json"));
    bytes memory bytecode = abi.encodePacked(vm.getCode(path), abi.encode(true));

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      assembly {
        stableTokenV2 := create(0, add(bytecode, 0x20), mload(bytecode))
      }
      IOwnableLite(stableTokenV2).transferOwnership(governance);
    }
    vm.stopBroadcast();

    console.log("----------");
    console.log("StableTokenV2 deployed at: ", stableTokenV2);
    console.log("StableTokenV2(%s) ownership transferred to %s", stableTokenV2, governance);
    console.log("----------");
  }
}
