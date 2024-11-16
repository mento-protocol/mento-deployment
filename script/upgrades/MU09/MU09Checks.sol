// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { Test } from "forge-std/Test.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";
import { ITransparentUpgradeableProxy } from "mento-core-2.6.0-tp/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "mento-core-2.6.0-tp/ProxyAdmin.sol";

contract MockImplementation {}

contract MU09Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  address public newLockingProxyAdmin;
  address public lockingProxy;
  address public mentoLabsMultisig;

  event Upgraded(address indexed newImplementation);

  function prepare() public {
    // Load addresses from deployments
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");
    contracts.loadSilent("MU09-Deploy-LockingProxyAdmin", "latest");

    mentoLabsMultisig = contracts.dependency("MentoLabsMultisig");
    require(mentoLabsMultisig != address(0), "MentoLabsMultisig address not found");

    // Get newly deployed LockingProxyAdmin address
    newLockingProxyAdmin = contracts.deployed("ProxyAdmin");
    require(newLockingProxyAdmin != address(0), "LockingProxyAdmin address not found");

    // Get and set the governance factory
    address governanceFactoryAddress = contracts.deployed("GovernanceFactory");
    require(governanceFactoryAddress != address(0), "GovernanceFactory address not found");
    IGovernanceFactory governanceFactory = IGovernanceFactory(governanceFactoryAddress);

    // Get the locking proxy address
    lockingProxy = governanceFactory.locking();
    require(lockingProxy != address(0), "LockingProxy address not found");
  }

  function run() public {
    console.log("\nStarting MU09 checks:");
    prepare();

    verifyLockingProxyAdminOwnership();
    verifyLockingProxyAdminIsNewLockingProxyAdmin();
    verifyMultisigCanUpgrade();
  }

  function verifyLockingProxyAdminOwnership() public {
    console.log("\n== Verifying locking proxy admin ownership: ==");

    address lockingProxyAdminOwner = ProxyAdmin(newLockingProxyAdmin).owner();
    require(lockingProxyAdminOwner == mentoLabsMultisig, "LockingProxyAdmin owner is not MentoLabsMultisig");
    console.log(unicode"🟢 LockingProxyAdmin owner is MentoLabsMultisig: %s", lockingProxyAdminOwner);
  }

  function verifyLockingProxyAdminIsNewLockingProxyAdmin() public {
    console.log("\n== Verifying locking proxy admin is new locking proxy admin: ==");

    address lockingProxyAdmin = ProxyAdmin(newLockingProxyAdmin).getProxyAdmin(
      ITransparentUpgradeableProxy(lockingProxy)
    );
    require(lockingProxyAdmin == newLockingProxyAdmin, "LockingProxyAdmin is not the new LockingProxyAdmin");
    console.log(unicode"🟢 LockingProxyAdmin is new LockingProxyAdmin: %s", lockingProxyAdmin);
  }

  function verifyMultisigCanUpgrade() public {
    console.log("\n== Verifying the multisig can successfuly upgrade implementation: ==");

    // Deploy a mock implementation
    MockImplementation mockImplementation = new MockImplementation();
    vm.startPrank(mentoLabsMultisig);

    // Verify that the upgrade event is emitted with the fake implementation
    vm.expectEmit(true, true, true, true);
    emit Upgraded(address(mockImplementation));

    ProxyAdmin(newLockingProxyAdmin).upgrade(ITransparentUpgradeableProxy(lockingProxy), address(mockImplementation));

    console.log(unicode"🟢 Multisig can upgrade implementation");
  }
}
