// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain as ChainLib } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { BiPoolManager } from "mento-core-2.6.5/swap/BiPoolManager.sol";
import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

interface IInitializable {
  function initialized() external view returns (bool);
}

/*
 yarn deploy -n <network> -u MGP13 -s MGP13-00-Deploy-BiPoolManager-Implementation.sol
*/
contract MGP13_DeployBiPoolManagerImplementation is Script {
  function run() public {
    address biPoolManager;
    address governance = timelockProxyAddress();

    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      biPoolManager = address(new BiPoolManager(false));
      BiPoolManager(biPoolManager).transferOwnership(governance);
    }
    vm.stopBroadcast();

    require(IInitializable(biPoolManager).initialized(), "BiPoolManager can still be initialized");

    console2.log("----------");
    console2.log("BiPoolManager deployed at: ", biPoolManager);
    console2.log("BiPoolManager(%s) ownership transferred to %s", biPoolManager, governance);
    console2.log("----------");
  }

  function timelockProxyAddress() public returns (address) {
    if (ChainLib.isSepolia()) {
      return contracts.dependency("TimelockProxy");
    }

    if (ChainLib.isCelo()) {
      contracts.loadSilent("MUGOV-00-Create-Factory", "latest");
      address governanceFactory = contracts.deployed("GovernanceFactory");
      return IGovernanceFactory(governanceFactory).governanceTimelock();
    }

    revert("Unexpected network for MGP13");
  }
}
