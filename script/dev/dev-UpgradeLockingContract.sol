// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import { console2 } from "forge-std/Script.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { Locking } from "mento-core-2.6.1/governance/locking/Locking.sol";
import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";
import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

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
    address mentoToken = IGovernanceFactory(contracts.deployed("GovernanceFactory")).mentoToken();
    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      lockingV2 = address(new Locking()); // TODO: Update once V2.6.2 is out
      console2.log("----------");
      console2.log("LockingV2 deployed at: ", lockingV2);
      console2.log("----------");

      // These values are taken from mainnet and initialized the proxy initially
      uint32 startingPointWeek = 212;
      uint32 minCliffPeriod = 0;
      uint32 minSlopePeriod = 1;

      Locking(lockingV2).__Locking_init(
        IERC20Upgradeable(mentoToken),
        startingPointWeek,
        minCliffPeriod,
        minSlopePeriod
      );

      console2.log("LockingV2 initialized");
      console2.log("----------");
    }
    vm.stopBroadcast();
  }
}
