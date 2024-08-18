// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { Script } from "mento-std/Script.sol";
import { IGovernanceFactory } from "../../interfaces/IGovernanceFactory.sol";
import { IGovernor } from "../../interfaces/IGovernor.sol";
import { console } from "forge-std/Script.sol";

contract PassProposal is Script {
  function run(uint256 proposalId) public {
    IGovernor governance = IGovernor(lookup("MentoGovernor"));

    if (governance.state(proposalId) != 1) {
      revert(unicode"❌ Proposal is not active");
    }

    (, , , uint256 startBlock, , , , , ) = governance.proposals(proposalId);
    uint256 quorumRequired = governance.quorum(startBlock);
    console.log("Quorum required: ", quorumRequired);

    vm.startBroadcast(vm.envUint("MENTO_DEPLOYER_PK"));
    {
      governance.castVote(proposalId, 1);
    }
    vm.stopBroadcast();

    (, , , , , uint256 forVotes, uint256 againstVotes, , ) = governance.proposals(proposalId);

    console.log("For votes: ", forVotes);
    console.log("Against votes: ", againstVotes);

    if (forVotes >= quorumRequired && forVotes > againstVotes) {
      console.log(unicode"✅ Proposal has enough votes to pass");
    } else {
      revert(unicode"❌ Proposal needs more votes to pass");
    }
  }
}
