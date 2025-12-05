pragma solidity ^0.8.18;

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

/**
 * @title MockGovernanceFactory
 * @notice A mock implementation of the GovernanceFactory contract for Sepolia,
 * that hardcodes the addresses of the contracts that were deployed in the
 * mento-deployments-v2 repo.
 *
 * This is as a dependency of some our scripts which fetch the timelock and governor addresses
 * in order to simulate and execute proposals.
 */
contract MockGovernanceFactory is IGovernanceFactory {
  address public constant MENTO_TOKEN = 0x07867fd40EB56b4380bE39c88D0a7EA59Aa99A20;

  address public constant EMISSION = 0x3C1BEA0F35b5dcAc1065CA9b3b6877657dEa4A69;

  address public constant LOCKING = 0xB72320fC501cb30E55bAF0DA48c20b11fAc9f79D;

  address public constant GOVERNOR = 0x23173Ac37b8E4e5a60d787aC543B3F51e8f398b4;

  address public constant TIME_LOCK = 0x74c44Be99937815173A3C56274331e0A05611e0D;

  function createGovernance(
    address watchdogMultiSig_,
    bytes32 airgrabRoot,
    address fractalSigner,
    MentoTokenAllocationParams calldata allocationParams
  ) external {
    revert("MockGovernanceFactory: not implemented");
  }

  function mentoToken() external view returns (address) {
    return MENTO_TOKEN;
  }

  function emission() external view returns (address) {
    return EMISSION;
  }

  function airgrab() external view returns (address) {
    revert("MockGovernanceFactory: not deployed");
  }

  function governanceTimelock() external view returns (address) {
    return TIME_LOCK;
  }

  function mentoGovernor() external view returns (address) {
    return GOVERNOR;
  }

  function locking() external view returns (address) {
    return LOCKING;
  }

  function proxyAdmin() external view returns (address) {
    // This was deployed  to sepolia but there are different proxy admins for
    // each contract instead of a single one.
    revert("MockGovernanceFactory: not deployed");
  }
}
