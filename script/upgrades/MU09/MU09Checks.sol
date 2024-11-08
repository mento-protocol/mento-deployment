// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { Test } from "forge-std/Test.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

interface IProxyAdminLite {
  function getProxyAdmin(address proxy) external view returns (address);
}

interface IOwnableLite {
  function owner() external view returns (address);
}

contract MU09Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  address public newLockingProxyAdmin;
  address public lockingProxy;
  address public mentoLabsMultisig;

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
  }

  function verifyLockingProxyAdminOwnership() public {
    console.log("\n== Verifying locking proxy admin ownership: ==");

    address lockingProxyAdminOwner = IOwnableLite(newLockingProxyAdmin).owner();
    require(lockingProxyAdminOwner == mentoLabsMultisig, "LockingProxyAdmin owner is not MentoLabsMultisig");
    console.log(unicode"🟢 LockingProxyAdmin owner is MentoLabsMultisig: %s", lockingProxyAdminOwner);
  }

  function verifyLockingProxyAdminIsNewLockingProxyAdmin() public {
    console.log("\n== Verifying locking proxy admin is new locking proxy admin: ==");

    address lockingProxyAdmin = IProxyAdminLite(newLockingProxyAdmin).getProxyAdmin(lockingProxy);
    require(lockingProxyAdmin == newLockingProxyAdmin, "LockingProxyAdmin is not the new LockingProxyAdmin");
    console.log(unicode"🟢 LockingProxyAdmin is new LockingProxyAdmin: %s", lockingProxyAdmin);
  }
}
