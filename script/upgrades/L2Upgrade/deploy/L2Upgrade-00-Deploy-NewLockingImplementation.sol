// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import { console2 } from "forge-std/Script.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Locking } from "mento-core-2.6.2/governance/locking/Locking.sol";

/**
 yarn deploy -n <network> -u L2Upgrade -s L2Upgrade-00-Deploy-NewLockingImplementation.sol
 */
contract DeployNewLockingImplementation is Script {
  function run() public {
    address lockingV2;
    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      lockingV2 = address(new Locking(true));
      console2.log("----------");
      console2.log("LockingV2 deployed at: ", lockingV2);
      console2.log("----------");
    }
    vm.stopBroadcast();
  }
}
