// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/v1/Script.sol";
import { Chain } from "script/utils/v1/Chain.sol";
import { console } from "forge-std/console.sol";

import { MockERC20 } from "contracts/MockERC20.sol";

contract CreateMockBridgedUSDC is Script {
  function run() public {
    address mockBridgedUSDC;

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      mockBridgedUSDC = address(new MockERC20("mockBridgedUSDC", "BridgedUSDC", 6));
    }
    vm.stopBroadcast();

    console.log("----------");
    console.log("MockBridgedUSDC deployed at: ", mockBridgedUSDC);
    console.log("----------");
  }
}
