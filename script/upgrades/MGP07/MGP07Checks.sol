// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;
/* solhint-disable max-line-length */

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { console2 as console } from "forge-std/console2.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { Test } from "forge-std/Test.sol";
import { Chain } from "script/utils/mento/Chain.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";
import { IGovernor } from "script/interfaces/IGovernor.sol";

import { IMentoTokenLite } from "./MGP07.sol";

contract MGP07Checks is GovernanceScript, Test {
  using Contracts for Contracts.Cache;

  address public mentoToken;
  IGovernanceFactory governanceFactory;

  function prepare() public {
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");

    address governanceFactoryAddress = contracts.deployed("GovernanceFactory");
    require(governanceFactoryAddress != address(0), "GovernanceFactory address not found");
    governanceFactory = IGovernanceFactory(governanceFactoryAddress);

    mentoToken = governanceFactory.mentoToken();
    require(mentoToken != address(0), "MentoToken address not found");

    console.log("MentoToken address:", mentoToken);
  }

  function run() public {
    console.log("\nStarting MGP07 checks:");
    prepare();

    verifyTokenUnpaused();
    verifyTokenTransfer();
  }

  function verifyTokenUnpaused() public view {
    console.log("\n== Verifying token unpause: ==");

    require(!IMentoTokenLite(mentoToken).paused(), "MentoToken is still paused");
    console.log(unicode"🟢 MentoToken is unpaused");
  }

  function verifyTokenTransfer() public {
    console.log("\n== Verifying token transfer functionality: ==");

    address airgrab = governanceFactory.airgrab();
    uint256 airgrabBalance = IMentoTokenLite(mentoToken).balanceOf(airgrab);
    require(airgrabBalance > 0, "Airgrab contract has no tokens");

    address receiver = address(123);
    uint256 transferAmount = 345 ether;

    vm.startPrank(airgrab);
    IMentoTokenLite(mentoToken).transfer(receiver, transferAmount);
    require(
      IMentoTokenLite(mentoToken).balanceOf(airgrab) == airgrabBalance - transferAmount,
      "Airgrab balance is incorrect"
    );
    require(IMentoTokenLite(mentoToken).balanceOf(receiver) == transferAmount, "Receiver balance is incorrect");
    vm.stopPrank();

    console.log(unicode"🟢 Token transfers work");
  }
}
