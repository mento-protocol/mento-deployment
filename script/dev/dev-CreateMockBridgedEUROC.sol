// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { MockERC20 } from "contracts/MockERC20.sol";

contract CreateMockBridgedEUROC is Script {
  function run() public {
    address mockBridgedEUROC;

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      mockBridgedEUROC = address(new MockERC20("mockBridgedEUROC", "BridgedEUROC", 6));
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("MockBridgedEUROC deployed at: ", mockBridgedEUROC);
    console2.log("----------");
  }
}
