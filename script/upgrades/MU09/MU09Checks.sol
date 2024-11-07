// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { Test } from "forge-std/Test.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

interface IOwnableLite {
  function owner() external view returns (address);

  function transferOwnership(address recipient) external;
}

contract MU09Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  address public lockingProxyAdmin;
  address public lockingProxy;
  address public mentoLabsMultisig;

  function prepare() public {
    // Load addresses from deployments
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");
    contracts.loadSilent("MU09-Deploy-LockingProxyAdmin", "latest");

    mentoLabsMultisig = contracts.dependency("MentoLabsMultisig");
    require(mentoLabsMultisig != address(0), "MentoLabsMultisig address not found");

    // Get newly deployed LockingProxyAdmin address
    lockingProxyAdmin = contracts.deployed("ProxyAdmin");
    require(lockingProxyAdmin != address(0), "LockingProxyAdmin address not found");

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
    verifyLockingProxyOwnership();
  }

  function verifyLockingProxyAdminOwnership() public {
    console.log("\n== Verifying locking proxy admin ownership: ==");

    address lockingProxyAdminOwner = IOwnableLite(lockingProxyAdmin).owner();
    require(lockingProxyAdminOwner == mentoLabsMultisig, "LockingProxyAdmin owner is not MentoLabsMultisig");
    console.log(unicode"🟢 LockingProxyAdmin owner is MentoLabsMultisig: %s", lockingProxyAdminOwner);
  }

  function verifyLockingProxyOwnership() public {
    console.log("\n== Verifying locking proxy ownership: ==");

    address lockingProxyOwner = IOwnableLite(lockingProxy).owner();
    require(lockingProxyOwner == lockingProxyAdmin, "LockingProxy owner is not LockingProxyAdmin");
    console.log(unicode"🟢 LockingProxy owner is LockingProxyAdmin: %s", lockingProxyOwner);
  }
}
