// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { Script } from "./Script.sol";
import { IGovernanceFactory } from "../../interfaces/IGovernanceFactory.sol";
import { IGovernor } from "../../interfaces/IGovernor.sol";
import { console2 } from "forge-std/Script.sol";

contract PassProposal is Script {
  function run(uint256 proposalId) public {
    IGovernor governance = IGovernor(IGovernanceFactory(GOVERNANCE_FACTORY).mentoGovernor());
    uint8 state = governance.state(proposalId);

    if (state != 1) {
      revert(unicode"❌ Proposal is not active");
    }

    (, , , uint256 startBlock, , , , , ) = governance.proposals(proposalId);
    uint256 quorumRequired = governance.quorum(startBlock);
    console2.log("Quorum required: ", quorumRequired);

    vm.startBroadcast(vm.envUint("MENTO_DEPLOYER_PK"));
    {
      IGovernor(governance).castVote(proposalId, 1);
    }
    vm.stopBroadcast();

    (, , , , , uint256 forVotes, uint256 againstVotes, , ) = governance.proposals(proposalId);

    console2.log("For votes: ", forVotes);
    console2.log("Against votes: ", againstVotes);

    if (forVotes >= quorumRequired && forVotes > againstVotes) {
      console2.log(unicode"🟢 Proposal has enough votes to pass");
    } else {
      revert(unicode"❌ Proposal needs more votes to pass");
    }
  }
}
