// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import { console2 } from "forge-std/Script.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { IRegistry } from "script/interfaces/IRegistry.sol";
import { LockingContract } from "src/contracts/LockingContract.sol";
import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

/**
 * Usage: yarn script:dev -n alfajores -s DeployUpgradeLockingContract -r "run()"
 * Used to deploy the Locking V2 implementation
 * ===========================================================
 */
contract DeployUpgradeLockingContract is Script {
  function run() public {
    address lockingV2;
    IRegistry registry = IRegistry(0x000000000000000000000000000000000000ce10);
    address mentoToken = IGovernanceFactory(contracts.deployed("GovernanceFactory")).mentoToken();
    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      lockingV2 = address(new LockingContract());
      console2.log("----------");
      console2.log("LockingV2 deployed at: ", lockingV2);
      console2.log("----------");
      lockingV2.__Locking_init(mentoToken, 212, 0, 1);
      console2.log("LockingV2 initialized");
      console2.log("----------");
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("LockingV2 deployed at: ", LockingV2);
    console2.log("----------");
  }
}
