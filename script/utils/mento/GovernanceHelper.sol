// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { Script, console2 } from "forge-std/Script.sol";
import { ICeloGovernance } from "../../interfaces/ICeloGovernance.sol";
import { IGovernor } from "../../interfaces/IGovernor.sol";
import { Chain } from "./Chain.sol";
import { Contracts } from "./Contracts.sol";

contract GovernanceHelper is Script {
  struct MentoGovernanceTransaction {
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string description;
  }

  function createProposal(
    ICeloGovernance.Transaction[] memory transactions,
    string memory descriptionURL,
    address governance
  ) internal {
    if (Chain.isCelo()) {
      verifyDescription(descriptionURL);
    } else {
      // Add timestamp to the description URL on testnets to avoid proposalId conflicts
      descriptionURL = string(abi.encodePacked(descriptionURL, "-", Contracts.uint2str(block.timestamp)));
    }

    MentoGovernanceTransaction memory govTx;

    govTx.description = descriptionURL;
    govTx.targets = new address[](transactions.length);
    govTx.values = new uint256[](transactions.length);
    govTx.calldatas = new bytes[](transactions.length);

    for (uint256 i = 0; i < transactions.length; i++) {
      govTx.targets[i] = transactions[i].destination;
      govTx.values[i] = transactions[i].value;
      govTx.calldatas[i] = transactions[i].data;
    }

    uint256 proposalId = IGovernor(governance).propose(govTx.targets, govTx.values, govTx.calldatas, govTx.description);

    console2.log("Proposal was successfully created. ID: ", proposalId);
  }

  function simulateProposal(ICeloGovernance.Transaction[] memory transactions, address governance) internal {
    require(
      transactions.length > 0,
      "Proposal has no transactions. Please check buildProposal() function returns transactions."
    );
    vm.activeFork();
    vm.startPrank(governance);
    for (uint256 i = 0; i < transactions.length; i++) {
      ICeloGovernance.Transaction memory _tx = transactions[i];
      // solhint-disable-next-line avoid-call-value,avoid-low-level-calls
      (bool success, bytes memory returnData) = _tx.destination.call{ value: _tx.value }(_tx.data);
      if (success == false) {
        console2.logBytes(returnData);
        revert("Failed to simulate the proposal");
      }
    }
    console2.log("Proposal was simulated successfully.");
    vm.stopPrank();
  }

  function verifyDescription(string memory descriptionURL) internal pure {
    bytes memory descriptionPrefix = new bytes(8);
    require(bytes(descriptionURL).length > 8, "Description URL must start with https://");
    for (uint i = 0; i < 8; i++) {
      descriptionPrefix[i] = bytes(descriptionURL)[i];
    }

    require(keccak256(descriptionPrefix) == keccak256("https://"), "Description URL must start with https://");
  }
}
