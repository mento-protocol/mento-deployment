// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { console } from "forge-std/console.sol";
import { GovernanceScript } from "./GovernanceScript.sol";
import { ICeloGovernance } from "../../interfaces/ICeloGovernance.sol";

abstract contract CeloGovernanceScript is GovernanceScript {
  struct ProposalTransaction {
    uint256[] values;
    address[] destinations;
    bytes data;
    uint256[] dataLengths;
  }

  string public descriptionURL;

  constructor(string memory _descriptionURL) {
    descriptionURL = _descriptionURL;
  }

  function createProposal() internal override {
    require(
      transactions.length > 0,
      "CeloGovernanceScript: Proposal has no transactions. Please check buildProposal() function returns transactions."
    );

    if (isCelo()) {
      verifyDescription();
    }

    ICeloGovernance governance = ICeloGovernance(lookup("Governance"));

    // Serialize transactions
    ProposalTransaction memory proposalTx = buildProposalTransaction();

    uint256 depositAmount = governance.minDeposit();
    console.log("CeloGovernanceScript: Deposit Required = %d", depositAmount);

    // Submit proposal
    uint256 proposalId = governance.propose{ value: depositAmount }(
      proposalTx.values,
      proposalTx.destinations,
      proposalTx.data,
      proposalTx.dataLengths,
      descriptionURL
    );

    console.log("CeloGovernanceScript: New Proposal ID = %d", proposalId);
  }

  function simulateProposal() internal override {
    require(
      transactions.length > 0,
      "CeloGovernanceScript: Proposal has no transactions. Please check buildProposal() function returns transactions."
    );

    address governance = lookup("Governance");

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
    console.log("Proposal was simulated successfully.");
    vm.stopPrank();
  }

  function buildProposalTransaction() internal view returns (ProposalTransaction memory proposalTx) {
    proposalTx.values = new uint256[](transactions.length);
    proposalTx.destinations = new address[](transactions.length);
    proposalTx.dataLengths = new uint256[](transactions.length);

    for (uint256 i = 0; i < transactions.length; i++) {
      proposalTx.values[i] = transactions[i].value;
      proposalTx.destinations[i] = transactions[i].destination;
      proposalTx.data = abi.encodePacked(proposalTx.data, transactions[i].data);
      proposalTx.dataLengths[i] = transactions[i].data.length;
    }
  }

  /**
   * @notice Helper function to verify that the description URL starts with https://
   */
  function verifyDescription() internal view {
    bytes memory descriptionPrefix = new bytes(8);
    require(bytes(descriptionURL).length > 8, "Description URL must start with https://");
    for (uint i = 0; i < 8; i++) {
      descriptionPrefix[i] = bytes(descriptionURL)[i];
    }

    require(
      keccak256(descriptionPrefix) == keccak256("https://"),
      "GovernanceScript: Description URL must start with https://"
    );
  }
}
