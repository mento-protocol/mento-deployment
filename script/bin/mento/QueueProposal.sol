// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { Script } from "mento-std/Script.sol";
import { IGovernanceFactory } from "../../interfaces/IGovernanceFactory.sol";
import { IGovernor } from "../../interfaces/IGovernor.sol";
import { console } from "forge-std/console.sol";

contract QueueProposal is Script {
  function run(uint256 proposalId) public {
    IGovernor governance = IGovernor(lookup("MentoGovernor"));

    if (governance.state(proposalId) != 4) {
      revert(unicode"❌ Proposal is not successful, cannot be queued");
    }

    vm.startBroadcast(deployerPrivateKey());
    {
      governance.queue(proposalId);
    }
    vm.stopBroadcast();

    console.log(unicode"✅ Proposal has been queued");
  }
}
