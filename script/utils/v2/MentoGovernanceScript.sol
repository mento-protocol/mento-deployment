// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "./GovernanceScript.sol";
import { console } from "forge-std/console.sol";
import { IGovernor } from "../../interfaces/IGovernor.sol";

abstract contract MentoGovernanceScript is GovernanceScript {
  struct MentoGovernanceTransaction {
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string description;
  }

  function setUp() internal virtual override {
    load("MUGOV-00-Create-Factory", "latest");
  }

  string description;

  constructor(string memory _proposalTitle, string memory _descriptionPath) {
    string memory markdownDescription = vm.readFile(_descriptionPath);
    string memory proposal = "proposal";
    vm.serializeString(proposal, "title", _proposalTitle);
    vm.serializeUint(proposal, "timestamp", block.timestamp);
    description = vm.serializeString(proposal, "description", markdownDescription);
  }

  function createProposal() internal override {
    require(
      transactions.length > 0,
      "MentoGovernanceScript: Proposal has no transactions. Please check buildProposal() function returns transactions."
    );

    MentoGovernanceTransaction memory govTx;

    govTx.description = description;
    govTx.targets = new address[](transactions.length);
    govTx.values = new uint256[](transactions.length);
    govTx.calldatas = new bytes[](transactions.length);

    for (uint256 i = 0; i < transactions.length; i++) {
      govTx.targets[i] = transactions[i].destination;
      govTx.values[i] = transactions[i].value;
      govTx.calldatas[i] = transactions[i].data;
    }

    address governance = lookup("MentoGovernor");
    uint256 proposalId = IGovernor(governance).propose(govTx.targets, govTx.values, govTx.calldatas, govTx.description);

    console.log(unicode"  Proposal was successfully created. ID = %s", proposalId);
  }

  function simulateProposal() internal override {
    require(
      transactions.length > 0,
      "MentoGovernanceScript: Proposal has no transactions. Please check buildProposal() function returns transactions."
    );
    address governance = lookup("GovernanceTimelock");

    vm.activeFork();
    vm.startPrank(governance);
    for (uint256 i = 0; i < transactions.length; i++) {
      Transaction memory _tx = transactions[i];
      // solhint-disable-next-line avoid-call-value,avoid-low-level-calls
      (bool success, bytes memory returnData) = _tx.destination.call{ value: _tx.value }(_tx.data);
      if (success == false) {
        console.logBytes(returnData);
        revert("Failed to simulate the proposal");
      }
    }
    console.log(unicode"  Governance proposal simulated successfully.");
    vm.stopPrank();
  }
}
