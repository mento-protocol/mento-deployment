// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { console } from "forge-std/console.sol";
import { Script } from "mento-std/Script.sol";
import { IRegistry } from "../../interfaces/IRegistry.sol";
import { ICeloGovernance } from "../../interfaces/ICeloGovernance.sol";

contract ExecuteProposal is Script {
  function run(uint256 proposalId) public {
    ICeloGovernance governance = ICeloGovernance(lookup("Governance"));

    uint256[] memory dequeue = governance.getDequeue();
    uint256 proposalIndex = 0;
    for (uint256 i = 0; i < dequeue.length; i++) {
      if (dequeue[i] == proposalId) {
        proposalIndex = i;
        break;
      }
    }
    require(dequeue[proposalIndex] == proposalId, "Proposal not found");

    vm.startBroadcast(deployerPrivateKey());
    {
      governance.execute(proposalId, proposalIndex);
    }
    vm.stopBroadcast();
  }
}
