// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "forge-std/Script.sol";
import { Chain } from "script/utils/Chain.sol";

import { StableTokenGHSProxy } from "mento-core-2.6.0/tokens/StableTokenGHSProxy.sol";
import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

/**
 * @notice This script is use to create the proposal containing the CELO
 *         governance transactions needed to update the cGHS token name
 * @dev depends on: ../deploy/*.sol
 */
contract RenameCGHS is IMentoUpgrade, GovernanceScript {
  address payable private stableTokenGHSProxyAddress;
  address private stableTokenV2ImplementationAddress;
  address private tempImplementationAddress;

  ICeloGovernance.Transaction[] private transactions;

  // Note: TempStable uses a newer version of Solidity, so cannot be imported without compiler issues.
  // Due to compiler limitations in 0.5.13, we cannot use .selector on an interface with a matching signature.
  // Updating TempStable to an older version would require cascading changes in Mento Core, fork tests, etc.
  // Hardcoding the selector is the simplest solution given the straightforward function signature.
  bytes4 setNameSelector = bytes4(keccak256("setName(string)"));

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
    contracts.loadSilent("cGHS-00-Temp-Implementation", "latest");
  }

  /**
   * @dev Sets the addresses of the various contracts needed for the proposal.
   */
  function setAddresses() public {
    stableTokenGHSProxyAddress = contracts.deployed("StableTokenGHSProxy");
    stableTokenV2ImplementationAddress = contracts.deployed("StableTokenV2");
    tempImplementationAddress = contracts.deployed("TempStable");
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
    StableTokenGHSProxy _cGHSProxy = StableTokenGHSProxy(stableTokenGHSProxyAddress);

    // Set the implementation to the temp implementation
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        stableTokenGHSProxyAddress,
        abi.encodeWithSelector(_cGHSProxy._setImplementation.selector, tempImplementationAddress)
      )
    );

    // Update the name of the token
    transactions.push(
      ICeloGovernance.Transaction(0, stableTokenGHSProxyAddress, abi.encodeWithSelector(setNameSelector, GHS_NAME))
    );

    // Switch the implementation back to the stableTokenV2 implementation
    transactions.push(
      ICeloGovernance.Transaction(
        0,
        stableTokenGHSProxyAddress,
        abi.encodeWithSelector(_cGHSProxy._setImplementation.selector, stableTokenV2ImplementationAddress)
      )
    );

    return transactions;
  }
}
