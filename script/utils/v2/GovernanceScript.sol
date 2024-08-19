// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { Script } from "mento-std/Script.sol";
import { IERC20Lite } from "../../interfaces/IERC20Lite.sol";

abstract contract GovernanceScript is Script {
  struct Transaction {
    uint256 value;
    address destination;
    bytes data;
  }

  Transaction[] public transactions;

  function add(uint256 value, address destination, bytes memory data) internal {
    transactions.push(Transaction(value, destination, data));
  }

  function add(address destination, bytes memory data) internal {
    add(0, destination, data);
  }

  function add(uint256 value, address destination) internal {
    add(value, destination, bytes(""));
  }

  function run() public virtual {
    setUp();
    buildProposal();

    vm.startBroadcast(deployerPrivateKey());
    {
      createProposal();
    }
    vm.stopBroadcast();
  }

  function simulate() external virtual {
    setUp();
    buildProposal();
    simulateProposal();
  }

  function setUp() internal virtual;

  function buildProposal() internal virtual;

  function createProposal() internal virtual;

  function simulateProposal() internal virtual;

  function hasChecks() external virtual returns (bool);

  /**
   * @notice Helper function to get the exchange ID for a pool.
   */
  function getExchangeId(address asset0, address asset1, bool isConstantSum) internal view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          IERC20Lite(asset0).symbol(),
          IERC20Lite(asset1).symbol(),
          isConstantSum ? "ConstantSum" : "ConstantProduct"
        )
      );
  }
}
