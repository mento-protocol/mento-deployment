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

contract MGP03Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  address public mentoLabsMultisig;
  address public mentoGovernor;
  address public locking;

  function prepare() public {
    // Load addresses from deployments
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");

    mentoLabsMultisig = contracts.dependency("MentoLabsMultisig");
    require(mentoLabsMultisig != address(0), "MentoLabsMultisig address not found");

    address governanceFactoryAddress = contracts.deployed("GovernanceFactory");
    require(governanceFactoryAddress != address(0), "GovernanceFactory address not found");
    IGovernanceFactory governanceFactory = IGovernanceFactory(governanceFactoryAddress);

    locking = governanceFactory.locking();
    require(locking != address(0), "LockingProxy address not found");

    mentoGovernor = governanceFactory.mentoGovernor();
    require(mentoGovernor != address(0), "MentoGovernor address not found");
  }

  function run() public {
    console.log("\nStarting MGP03 checks:");
    prepare();

    verifyVotingPeriod();
    verifyMentoLabsMultisig();
    verifyMentoLabsMultisigPriviliges();
  }

  function verifyVotingPeriod() public {
    console.log("\n== Verifying voting period: ==");

    uint256 expectedVotingPeriod = Chain.isCelo() ? 604800 : 300;

    require(IGovernor(mentoGovernor).votingPeriod() == expectedVotingPeriod, "Voting period is not correct");
    console.log(unicode"🟢 Voting period is correct: %s", expectedVotingPeriod);
  }

  function verifyMentoLabsMultisig() public {
    console.log("\n== Verifying mento labs multisig: ==");

    require(ILockingLite(locking).mentoLabsMultisig() == mentoLabsMultisig, "Mento Labs multisig is not correct");
    console.log(unicode"🟢 Mento Labs multisig is correct: %s", mentoLabsMultisig);
  }

  function verifyMentoLabsMultisigPriviliges() public {
    console.log("\n== Verifying mento labs multisig priviliges: ==");

    vm.prank(mentoLabsMultisig);
    ILockingLite(locking).setL2TransitionBlock(block.number);

    require(ILockingLite(locking).paused(), "Locking contract is not paused");
    require(ILockingLite(locking).l2TransitionBlock() == block.number, "L2 transition block is not set");

    console.log(unicode"🟢 Mento Labs multisig priviliges are set correctly");
  }
}
