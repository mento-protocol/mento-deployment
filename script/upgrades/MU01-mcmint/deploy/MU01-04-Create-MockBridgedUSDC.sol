// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { MockERC20 } from "contracts/MockERC20.sol";

contract MU01_CreateMockBridgedUSDC is Script {
  function run() public {
    address mockBridgedUSDC;

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      mockBridgedUSDC = address(new MockERC20("mockBridgedUSDC", "BridgedUSDC", 18));
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("MockBridgedUSDC deployed at: ", mockBridgedUSDC);
    console2.log("----------");
  }
}
