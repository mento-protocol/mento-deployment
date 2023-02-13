// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { MockERC20 } from "contracts/MockERC20.sol";

contract MU01_CreateMockUSDCet is Script {
  function run() public {
    address mockUSDCet;

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      mockUSDCet = address(new MockERC20("mockUSDCet", "USDCet", 18));
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("MockUSDCet deployed at: ", mockUSDCet);
    console2.log("----------");
  }
}
