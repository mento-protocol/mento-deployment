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

contract MGP04Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  address public mentoGovernor;

  function prepare() public {
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");

    address governanceFactoryAddress = contracts.deployed("GovernanceFactory");
    require(governanceFactoryAddress != address(0), "GovernanceFactory address not found");
    IGovernanceFactory governanceFactory = IGovernanceFactory(governanceFactoryAddress);

    mentoGovernor = governanceFactory.mentoGovernor();
    require(mentoGovernor != address(0), "MentoGovernor address not found");
  }

  function run() public {
    console.log("\nStarting MGP04 checks:");
    prepare();

    verifyVotingPeriod();
  }

  function verifyVotingPeriod() public view {
    console.log("\n== Verifying voting period: ==");

    uint256 expectedVotingPeriod = Chain.isCelo() ? 604800 : 300;

    require(IGovernor(mentoGovernor).votingPeriod() == expectedVotingPeriod, "Voting period is not correct");
    console.log(unicode"🟢 Voting period is correct: %s", expectedVotingPeriod);
  }
}
