// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import { console2 } from "forge-std/Script.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { Locking } from "mento-core-2.6.2/governance/locking/Locking.sol";

/**
 * Usage: yarn script:dev -n alfajores -s UpgradeLockingContract -r "run()"
 * Used to deploy the Locking V2 implementation
 * ===========================================================
 */
contract UpgradeLockingContract is Script {
  using Contracts for Contracts.Cache;

  function run() public {
    contracts.load("MUGOV-00-Create-Factory", "latest");
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
