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

  address public constant EMISSION = 0x7c990801cA84e23e8Df85AB2AdB52c8e2e518797;

  address public constant LOCKING = 0xC955e54F7f6a302d926720890ddE96705104db38;

  address public constant GOVERNOR = 0x910A940a53C12982ae2277392C5Cfa03aa8c602b;

  address public constant TIME_LOCK = 0x32346936c5bAf3c7B53Ea3fe40B405EFD3A3e656;

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
