// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

// Latest deployed version of BiPoolManager and Broker
import { BiPoolManager } from "mento-core-2.2.0/swap/BiPoolManager.sol";
import { Broker } from "mento-core-2.2.0/swap/Broker.sol";
import { Reserve } from "mento-core-2.2.0/swap/Reserve.sol";

/*
 yarn deploy -n <network> -u MU09 -s MU09-00-Create-Implementations.sol
*/

interface IOwnableLite {
  function transferOwnership(address newOwner) external;
}

contract MU09_CreateImplementations is Script {
  function run() public {
    address stableTokenV2;
    address biPoolManager;
    address broker;
    address payable reserve;

    // TODO: Update this to be Mento Governance, after running MU08 on Alfajores
    address governance = contracts.celoRegistry("Governance");

    string memory path = string(abi.encodePacked("out/StableTokenV2.sol/StableTokenV2.json"));
    bytes memory bytecode = abi.encodePacked(vm.getCode(path), abi.encode(true));

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      assembly {
        stableTokenV2 := create(0, add(bytecode, 0x20), mload(bytecode))
      }
      IOwnableLite(stableTokenV2).transferOwnership(governance);

      // Deploy BiPoolManager implementation
      biPoolManager = address(new BiPoolManager(false));
      BiPoolManager(biPoolManager).transferOwnership(governance);

      // Deploy Broker implementation
      broker = address(new Broker(false));
      Broker(broker).transferOwnership(governance);

      // Deploy Reserve implementation
      reserve = address(new Reserve(false));
      Reserve(reserve).transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenV2 deployed at: ", stableTokenV2);
    console2.log("StableTokenV2(%s) ownership transferred to %s", stableTokenV2, governance);
    console2.log("");
    console2.log("BiPoolManager deployed at: ", biPoolManager);
    console2.log("BiPoolManager(%s) ownership transferred to %s", biPoolManager, governance);
    console2.log("");
    console2.log("Broker deployed at: ", broker);
    console2.log("Broker(%s) ownership transferred to %s", broker, governance);
    console2.log("");
    console2.log("Reserve deployed at: ", reserve);
    console2.log("Reserve(%s) ownership transferred to %s", reserve, governance);

    console2.log("----------");
  }
}
