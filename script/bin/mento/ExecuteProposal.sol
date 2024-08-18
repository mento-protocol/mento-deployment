// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { Script } from "mento-std/Script.sol";
import { IGovernanceFactory } from "../../interfaces/IGovernanceFactory.sol";
import { IGovernor } from "../../interfaces/IGovernor.sol";

contract ExecuteProposal is Script {
  function run(uint256 proposalId) public {
    IGovernor governance = IGovernor(lookup("MentoGovernor"));

    if (governance.state(proposalId) != 5) {
      revert(unicode"❌ Proposal is not queued, cannot be executed");
    }

    vm.startBroadcast(deployerPrivateKey());
    {
      governance.execute(proposalId);
    }
    vm.stopBroadcast();
  }
}
