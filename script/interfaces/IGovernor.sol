pragma solidity ^0.8.18;

/**
 * @dev Interface of the Bravo Compatible Governor.
 */
interface IGovernor {
  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) external returns (uint256 proposalId);

  /**
   * @dev Part of the Governor Bravo's interface: _"Queues a proposal of state succeeded"_.
   */
  function queue(uint256 proposalId) external;

  /**
   * @dev Part of the Governor Bravo's interface: _"Executes a queued proposal if eta has passed"_.
   */
  function execute(uint256 proposalId) external;

  /**
   * @dev Cancels a proposal only if sender is the proposer, or proposer delegates dropped below proposal threshold.
   */
  function cancel(uint256 proposalId) external;

  /**
   * @dev Cast a vote
   *
   * Emits a {VoteCast} event.
   */
  function castVote(uint256 proposalId, uint8 support) external returns (uint256 balance);
}
