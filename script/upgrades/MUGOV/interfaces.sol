// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

interface IMentoToken {
  function emissionSupply() external view returns (uint256);

  function totalSupply() external view returns (uint256);

  function emission() external view returns (address);

  function locking() external view returns (address);

  function owner() external view returns (address);

  function paused() external view returns (bool);

  function balanceOf(address account) external view returns (uint256);

  function symbol() external view returns (string memory);

  function name() external view returns (string memory);

  function decimals() external view returns (uint8);
}

interface IEmission {
  function mentoToken() external view returns (address);

  function owner() external view returns (address);

  function emissionTarget() external view returns (address);
}

interface IAirgrab {
  function root() external view returns (bytes32);

  function fractalSigner() external view returns (address);

  function fractalMaxAge() external view returns (uint256);

  function endTimestamp() external view returns (uint256);

  function slopePeriod() external view returns (uint32);

  function cliffPeriod() external view returns (uint32);

  function token() external view returns (address);

  function locking() external view returns (address);

  function mentoTreasury() external view returns (address);
}

interface ITimelock {
  function PROPOSER_ROLE() external view returns (bytes32);

  function EXECUTOR_ROLE() external view returns (bytes32);

  function CANCELLER_ROLE() external view returns (bytes32);

  function hasRole(bytes32 role, address account) external view returns (bool);

  function getMinDelay() external view returns (uint256);
}

interface IMentoGovernor {
  function token() external view returns (address);

  function votingDelay() external view returns (uint256);

  function votingPeriod() external view returns (uint256);

  function proposalThreshold() external view returns (uint256);

  function quorumNumerator() external view returns (uint256);

  function timelock() external view returns (address);
}

interface ILocking {
  function token() external view returns (address);

  function minCliffPeriod() external view returns (uint256);

  function minSlopePeriod() external view returns (uint256);

  function owner() external view returns (address);

  function getWeek() external view returns (uint256);

  function symbol() external view returns (string memory);

  function name() external view returns (string memory);
}
