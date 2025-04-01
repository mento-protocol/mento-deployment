// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;
/* solhint-disable max-line-length */

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { console } from "forge-std/console.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { Test } from "forge-std/Test.sol";
import { Chain } from "script/utils/mento/Chain.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";
import { IGovernor } from "script/interfaces/IGovernor.sol";

interface ILockingLite {
  function mentoLabsMultisig() external view returns (address);

  function setL2TransitionBlock(uint256 l2TransitionBlock_) external;

  function l2TransitionBlock() external view returns (uint256);

  function paused() external view returns (bool);
}

contract MGP06Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  address public mentoLabsMultisig;
  address public locking;

  function prepare() public {
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");

    mentoLabsMultisig = contracts.dependency("MentoLabsMultisig");
    require(mentoLabsMultisig != address(0), "MentoLabsMultisig address not found");

    address governanceFactoryAddress = contracts.deployed("GovernanceFactory");
    require(governanceFactoryAddress != address(0), "GovernanceFactory address not found");
    IGovernanceFactory governanceFactory = IGovernanceFactory(governanceFactoryAddress);

    locking = governanceFactory.locking();
    require(locking != address(0), "LockingProxy address not found");
  }

  function run() public {
    console.log("\nStarting MGP06 checks:");
    prepare();

    verifyMentoLabsMultisig();
  }

  function verifyMentoLabsMultisig() public view {
    console.log("\n== Verifying mento labs multisig removal: ==");

    require(ILockingLite(locking).mentoLabsMultisig() == address(0), "Mento Labs multisig is not removed");
    console.log(unicode"🟢 Mento Labs multisig is removed");
  }
}
