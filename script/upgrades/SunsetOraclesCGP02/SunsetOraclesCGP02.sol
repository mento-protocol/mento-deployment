// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { Chain } from "script/utils/mento/Chain.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";
import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";

/*
  Final CGP to clean up SortedOracles and leave only Redstone/Chainlink
*/

contract SunsetOraclesCGP02 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;
  ICeloGovernance.Transaction[] private transactions;

  address public mentoGovernor;

  IGovernanceFactory public governanceFactory;

  /**
   * @dev Loads the contracts from previous deployments
   */
  function loadDeployedContracts() public {
    // Load load deployment with governance factory
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");

    // Load the deployed ProxyAdmin contract
    contracts.loadSilent("MU09-Deploy-LockingProxyAdmin", "latest");
  }

  function prepare() public {
    loadDeployedContracts();

    address governanceFactoryAddress = contracts.deployed("GovernanceFactory");
    governanceFactory = IGovernanceFactory(governanceFactoryAddress);
    mentoGovernor = governanceFactory.mentoGovernor();
  }

  function run() public {
    prepare();

    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      // TODO: Change this to the forum post URL
      createProposal(_transactions, "changeMePlease", mentoGovernor);
    }
    vm.stopBroadcast();
  }

  function recreateExchange(address asset0, address asset1) internal {
    // Locate exchange with both assets
    // Get all the configuration: PoolExchange & PoolConfig
    // Delete old and re-create with new params
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    require(transactions.length == 0, "buildProposal() should only be called once");

    recreateExchanges();

    return transactions;
  }
}
