// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

interface IGovernanceFactory {
  /// @dev Parameters for the initial token allocation
  struct MentoTokenAllocationParams {
    uint256 airgrabAllocation;
    uint256 mentoTreasuryAllocation;
    address[] additionalAllocationRecipients;
    uint256[] additionalAllocationAmounts;
  }

  function createGovernance(
    address watchdogMultiSig_,
    bytes32 airgrabRoot,
    address fractalSigner,
    MentoTokenAllocationParams calldata allocationParams
  ) external;

  function mentoToken() external view returns (address);

  function emission() external view returns (address);

  function airgrab() external view returns (address);

  function governanceTimelock() external view returns (address);

  function mentoGovernor() external view returns (address);

  function locking() external view returns (address);
}
