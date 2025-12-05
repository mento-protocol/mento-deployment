// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { Test } from "forge-std/Test.sol";
import { IERC20Lite } from "script/interfaces/IERC20Lite.sol";
import { Script } from "script/utils/mento/Script.sol";
import { console2 as console } from "forge-std/Script.sol";
import { IProxy } from "mento-core-2.5.0/common/interfaces/IProxy.sol";

import { MGP12Config } from "./Config.sol";

contract MGP12Checks is Script, Test {
  MGP12Config private config;

  constructor() public {
    config = new MGP12Config();
    config.load();
  }

  function run() public {
    address[] memory stables = config.getStables();
    for (uint256 i = 0; i < stables.length; i++) {
      address stable = stables[i];

      require(equal(config.getTask(stable).newName, IERC20Lite(stable).name()), "Current name != expected new name");
      require(
        equal(config.getTask(stable).newSymbol, IERC20Lite(stable).symbol()),
        "Current symbol != expected new symbol"
      );
      require(
        IProxy(stable)._getImplementation() == config.getStableTokenV2ImplAddress(),
        "Current impl != expected impl"
      );
    }

    console.log("\n");
    console.log("========= Post-upgrade state =========\n");
    config.printAllStables();
    console.log("\n");
    console.log(unicode"🟢 All %s tokens have been renamed correctly", stables.length);
    console.log(
      unicode"🟢 All %s tokens have the expected implementation (%s)",
      stables.length,
      config.getStableTokenV2ImplAddress()
    );
  }

  function equal(string memory a, string memory b) internal pure returns (bool) {
    return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
  }
}
