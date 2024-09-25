// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { Script } from "./Script.sol";
import { IGovernanceFactory } from "../../interfaces/IGovernanceFactory.sol";
import { IGovernor } from "../../interfaces/IGovernor.sol";
import { Chain } from "./Chain.sol";

contract ExecuteProposal is Script {
  function run(uint256 proposalId) public {
    address governance = IGovernanceFactory(Chain.governanceFactory()).mentoGovernor();

    if (IGovernor(governance).state(proposalId) != 5) {
      revert(unicode"❌ Proposal is not queued, cannot be executed");
    }

    vm.startBroadcast(vm.envUint("MENTO_DEPLOYER_PK"));
    {
      IGovernor(governance).execute(proposalId);
    }
    vm.stopBroadcast();
  }
}
