// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Script, console2 } from "forge-std/Script.sol";
import { ICeloGovernance } from "../interfaces/ICeloGovernance.sol";
import { Chain } from "./Chain.sol";

contract GovernanceHelper is Script {
  struct SerializedTransactions {
    uint256[] values;
    address[] destinations;
    bytes data;
    uint256[] dataLengths;
  }

  function createProposal(
    ICeloGovernance.Transaction[] memory transactions,
    string memory descriptionURL,
    address governance
  ) internal {
    if (Chain.isCelo()) {
      verifyDescription(descriptionURL);
    }
    // Serialize transactions
    SerializedTransactions memory serTxs = serializeTransactions(transactions);

    uint256 depositAmount = ICeloGovernance(governance).minDeposit();
    console2.log("Celo governance proposal required deposit amount: ", depositAmount);

    // Submit proposal
    // solhint-disable-next-line avoid-call-value,avoid-low-level-calls
    (bool success, bytes memory returnData) = address(governance).call.value(depositAmount)(
      abi.encodeWithSelector(
        ICeloGovernance(0).propose.selector,
        serTxs.values,
        serTxs.destinations,
        serTxs.data,
        serTxs.dataLengths,
        descriptionURL
      )
    );

    if (success == false) {
      console2.logBytes(returnData);
      revert("Failed to create proposal");
    }
    console2.log("Proposal was successfully created. ID: ", abi.decode(returnData, (uint256)));
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
      (bool success, bytes memory returnData) = _tx.destination.call.value(_tx.value)(_tx.data);
      if (success == false) {
        console2.logBytes(returnData);
        revert("Failed to simulate the proposal");
      }
    }
    console2.log("Proposal was simulated successfully.");
    vm.stopPrank();
  }

  function serializeTransactions(
    ICeloGovernance.Transaction[] memory transactions
  ) internal pure returns (SerializedTransactions memory serTxs) {
    serTxs.values = new uint256[](transactions.length);
    serTxs.destinations = new address[](transactions.length);
    serTxs.dataLengths = new uint256[](transactions.length);

    for (uint256 i = 0; i < transactions.length; i++) {
      serTxs.values[i] = transactions[i].value;
      serTxs.destinations[i] = transactions[i].destination;
      serTxs.data = abi.encodePacked(serTxs.data, transactions[i].data);
      serTxs.dataLengths[i] = transactions[i].data.length;
    }
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
