// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { Test } from "forge-std/Test.sol";
// import { Proxy } from "mento-core-2.3.1/common/Proxy.sol";
import { IERC20Lite } from "script/interfaces/IERC20Lite.sol";
import { Script } from "script/utils/mento/Script.sol";
import { console2 as console } from "forge-std/Script.sol";

import { MGP11Config } from "./Config.sol";

contract MGP11Checks is Script, Test {
  string public constant GHS_NAME = "Celo Ghanaian Cedi";

  address payable public stableTokenGHSProxy;
  address public stableTokenV2Implementation;
  address public proxyOwner;
  address public testUser;

  MGP11Config private config;

  constructor() public {
    setUp();
  }

  function setUp() public {
    // contracts.loadSilent("MU04-00-Create-Implementations", "latest");
    // contracts.loadSilent("cGHS-00-Deploy-Proxy", "latest");
    // contracts.loadSilent("cGHS-00-Temp-Implementation", "latest");

    // stableTokenGHSProxy = contracts.deployed("StableTokenGHSProxy");
    // stableTokenV2Implementation = contracts.deployed("StableTokenV2");

    config = new MGP11Config();
    config.load();
  }

  function run() public {
    address[] memory stables = config.getStables();
    for (uint256 i = 0; i < stables.length; i++) {
      address stable = stables[i];

      require(equal(config.getTask(stable).newName, IERC20Lite(stable).name()), "Current name != expected old name");
      require(
        equal(config.getTask(stable).newSymbol, IERC20Lite(stable).symbol()),
        "Current symbol != expected old symbol"
      );
    }

    console.log("\n");
    console.log("========= Post-upgrade state =========");
    console.log("\n");
    config.printAllStables();
    console.log("\n");
    console.log(unicode"🟢 All %s tokens have been renamed correctly", stables.length);
  }

  function equal(string memory a, string memory b) internal pure returns (bool) {
    return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
  }
}
