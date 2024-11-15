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

interface IProxyAdminLite {
  function getProxyAdmin(address proxy) external view returns (address);

  function changeProxyAdmin(address proxy, address newAdmin) external;
}

contract MU09 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;

  address public mentoGovernor;
  address public lockingProxyAdmin;
  address public lockingProxy;

  address public oldLockingProxyAdmin;

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

    // Get and set the governance factory
    address governanceFactoryAddress = contracts.deployed("GovernanceFactory");
    governanceFactory = IGovernanceFactory(governanceFactoryAddress);

    // Get the mento governor address
    mentoGovernor = governanceFactory.mentoGovernor();
    require(mentoGovernor != address(0), "MentoGovernor address not found");

    // Get the locking proxy address
    lockingProxy = governanceFactory.locking();
    require(lockingProxy != address(0), "LockingProxy address not found");

    // Get the old locking proxy admin address
    oldLockingProxyAdmin = governanceFactory.proxyAdmin();
    require(oldLockingProxyAdmin != address(0), "Old LockingProxyAdmin address not found");
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

    // Check that the proxy admin of locking is the proxy admin from the governance factory
    address proxyAdminOfLocking = IProxyAdminLite(oldLockingProxyAdmin).getProxyAdmin(lockingProxy);
    require(
      proxyAdminOfLocking == oldLockingProxyAdmin,
      "Proxy admin of locking is not `governanceFactory.proxyAdmin()`"
    );

    // Send tx to the old proxy admin to change the proxy admin of locking to the new locking proxy admin
    _transactions[0] = ICeloGovernance.Transaction(
      0,
      oldLockingProxyAdmin,
      abi.encodeWithSelector(IProxyAdminLite.changeProxyAdmin.selector, lockingProxy, lockingProxyAdmin)
    );

    return _transactions;
  }
}
