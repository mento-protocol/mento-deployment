// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

interface ICeloGovernance {
  struct Transaction {
    uint256 value;
    address destination;
    bytes data;
  }

  function minDeposit() external returns (uint256);

  function propose(
    uint256[] calldata values,
    address[] calldata destinations,
    bytes calldata data,
    uint256[] calldata dataLengths,
    string calldata descriptionUrl
  ) external payable returns (uint256);

  function setConstitution(address destination, bytes4 functionId, uint256 threshold) external;

  /**
   * @notice Returns the constitution for a particular destination and function ID.
   * @param destination The destination address to get the constitution for.
   * @param functionId The function ID to get the constitution for, zero for the destination
   *   default.
   * @return The ratio of yes:no votes needed to exceed in order to pass the proposal.
   */
  function getConstitution(address destination, bytes4 functionId) external view returns (uint256);
}
