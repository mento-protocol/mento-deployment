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

interface IOwnableLite {
  function transferOwnership(address recipient) external;
}

contract MU09 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;

  address public mentoGovernor;
  address public lockingProxyAdmin;
  address public lockingProxy;

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

    // Get newly deployed LockingProxyAdmin address
    lockingProxyAdmin = contracts.deployed("ProxyAdmin");
    require(lockingProxyAdmin != address(0), "LockingProxyAdmin address not found");

    // Get and set the governance factory
    address governanceFactoryAddress = contracts.deployed("GovernanceFactory");
    require(governanceFactoryAddress != address(0), "GovernanceFactory address not found");
    governanceFactory = IGovernanceFactory(governanceFactoryAddress);

    // Get the mento governor address
    mentoGovernor = governanceFactory.mentoGovernor();
    require(mentoGovernor != address(0), "MentoGovernor address not found");

    // Get the locking proxy address
    lockingProxy = governanceFactory.locking();
    require(lockingProxy != address(0), "LockingProxy address not found");
  }

  function run() public {
    prepare();

    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      // TODO: Change this to the forum post URL
      createProposal(_transactions, "https://CHANGE-ME-PLEASE", mentoGovernor);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    ICeloGovernance.Transaction[] memory _transactions = new ICeloGovernance.Transaction[](1);

    // Create transaction to transfer proxy ownership
    _transactions[0] = ICeloGovernance.Transaction(
      0,
      lockingProxy,
      abi.encodeWithSelector(IOwnableLite.transferOwnership.selector, lockingProxyAdmin)
    );

    return _transactions;
  }
}
