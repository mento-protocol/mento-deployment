// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script, console2 } from "forge-std/Script.sol";
import { IRegistry } from "../interfaces/IRegistry.sol";
import { ICeloGovernance } from "../interfaces/ICeloGovernance.sol";

contract ExecuteProposal is Script {
  function run(uint256 proposalId) public {
    IRegistry registry = IRegistry(0x000000000000000000000000000000000000ce10);
    ICeloGovernance governance = ICeloGovernance(registry.getAddressForStringOrDie("Governance"));

    uint256[] memory dequeue = governance.getDequeue();
    uint256 proposalIndex = 0;
    for (uint256 i = 0; i < dequeue.length; i++) {
      if (dequeue[i] == proposalId) {
        proposalIndex = i;
        break;
      }
    }
    require(dequeue[proposalIndex] == proposalId, "Proposal not found");

    vm.startBroadcast(vm.envUint("MENTO_DEPLOYER_PK"));
    {
      governance.execute(proposalId, proposalIndex);
    }
    vm.stopBroadcast();
  }
}
