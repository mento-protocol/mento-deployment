// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "forge-std/Script.sol";

import { IERC20Metadata } from "mento-core-2.3.1/common/interfaces/IERC20Metadata.sol";
import { StableTokenGHSProxy } from "mento-core-2.6.0/tokens/StableTokenGHSProxy.sol";

import { TempStable } from "mento-core-2.6.4/tokens/TempStable.sol";

import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

/**
 * @notice This script is use to create the proposal containing the CELO
 *         governance transactions needed to update the cGHS token name
 * @dev depends on: ../deploy/*.sol
 */
contract cGHS is IMentoUpgrade, GovernanceScript {
  using TradingLimits for TradingLimits.Config;
  using FixidityLib for FixidityLib.Fraction;

  address private stableTokenGHSProxyAddress;
  address private stableTokenV2ImplementationAddress;
  address private tempImplementationAddress;

  ICeloGovernance.Transaction[] private transactions;

  bool public hasChecks = true;

  string private constant GHS_NAME = "Celo Ghanaian Cedi";

  function prepare() public {
    loadDeployedContracts();
    setAddresses();
  }

  /**
   * @dev Loads the deployed contracts from previous deployments
   */
  function loadDeployedContracts() public {
    contracts.loadSilent("MU04-00-Create-Implementations", "latest"); // First StableTokenV2 deployment
    contracts.loadSilent("cGHS-00-Deploy-Proxy", "latest");
    contracts.loadSilent("cGHS-Rename-Deploy-Implementation", "latest");
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    stableTokenGHSProxy = contracts.deployed("StableTokenGHSProxy");
    stableTokenV2Implementation = contracts.deployed("StableTokenV2");
    tempImplementation = contracts.deployed("TempStable");
  }

  function run() public {
    prepare();

    address governance = contracts.celoRegistry("Governance");
    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      createProposal(_transactions, "TODO: SET ME PLS :(", governance);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");
    StableTokenGHSProxy _cGHSProxy = StableTokenGHSProxy(stableTokenGHSProxy);

    // Set the implementation to the temp implementation
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        stableTokenGHSProxy,
        abi.encodeWithSelector(_cGHSProxy._setImplementation.selector, tempImplementationAddress)
      )
    );

    // Update the name of the token
    transactions.push(
      ICeloGovernance.Transaction(0, stableTokenGHSProxy, abi.encodeWithSelector(TempStable.setName.selector, GHS_NAME))
    );

    // Switch the implementation back to the stableTokenV2 implementation
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        stableTokenGHSProxy,
        abi.encodeWithSelector(_cGHSProxy._setImplementation.selector, stableTokenV2ImplementationAddress)
      )
    );

    return transactions;
  }
}
