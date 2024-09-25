// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { Script } from "./Script.sol";
import { IGovernanceFactory } from "../../interfaces/IGovernanceFactory.sol";
import { IGovernor } from "../../interfaces/IGovernor.sol";
import { console2 } from "forge-std/Script.sol";
import { Chain } from "./Chain.sol";

contract QueueProposal is Script {
  function run(uint256 proposalId) public {
    IGovernor governance = IGovernor(IGovernanceFactory(Chain.governanceFactory()).mentoGovernor());

    if (governance.state(proposalId) != 4) {
      revert(unicode"❌ Proposal is not successful, cannot be queued");
    }

    vm.startBroadcast(vm.envUint("MENTO_DEPLOYER_PK"));
    {
      governance.queue(proposalId);
    }
    vm.stopBroadcast();

    console2.log(unicode"✅ Proposal has been queued");
  }
}
