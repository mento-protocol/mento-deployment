pragma solidity ^0.8;

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
   */
  function castVote(uint256 proposalId, uint8 support) external returns (uint256 balance);

  /**
   * @dev Returns information about a proposal
   */
  function proposals(
    uint256 proposalId
  )
    external
    returns (
      uint256 id,
      address proposer,
      uint256 eta,
      uint256 startBlock,
      uint256 endBlock,
      uint256 forVotes,
      uint256 againstVotes,
      bool canceled,
      bool executed
    );

  /**
   * @dev Returns the quorum required for a block number
   */
  function quorum(uint256 blockNumber) external view returns (uint256);

  /**
   * @dev Returns the state of a proposal
   */
  function state(uint256 proposalId) external view returns (uint8);

  /**
   * @dev Set the voting period
   */
  function setVotingPeriod(uint256 newVotingPeriod) external;

  /**
   * @dev Get the voting period
   */
  function votingPeriod() external view returns (uint256);
}
