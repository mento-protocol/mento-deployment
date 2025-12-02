// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { Script } from "script/utils/mento/Script.sol";
import { console2 } from "forge-std/Script.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { StableTokenV2Renamer } from "contracts/StableTokenV2Renamer.sol";
import { IGovernanceFactory } from "../../../interfaces/IGovernanceFactory.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";

/**
 yarn deploy -n <network> -u MGP12 -s MGP12-00-Rename-Implementation.sol
 */

interface IOwnableLite {
  function transferOwnership(address newOwner) external;
}

contract MGP12_RenameImplementation is Script {
  using Contracts for Contracts.Cache;

  function run() public {
    address renamerImplementation;

    address governance = timelockProxyAddress();

    vm.startBroadcast(vm.envUint("MENTO_DEPLOYER_PK"));
    {
      renamerImplementation = address(new StableTokenV2Renamer());
      IOwnableLite(renamerImplementation).transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenV2Renamer deployed at: ", renamerImplementation);
    console2.log("Ownership transferred to %s", governance);
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

    revert("Unexpected network for MGP12");
  }
}
