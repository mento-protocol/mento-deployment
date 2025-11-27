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
    console.log("\n\n");

    console.log("========= Post-upgrade state =========");
    config.printAllStables();
    // console.log(unicode"🟢 MGP11Checks");

    // // Verify the implmentation is still the original StableTokenV2
    // address currentImplementation = Proxy(stableTokenGHSProxy)._getImplementation();
    // assertEq(currentImplementation, stableTokenV2Implementation, "Implementation is not the expected StableTokenV2");
    // console.log("🟢 Implementation is the expected StableTokenV2");

    // // Verify the name is correct
    // IERC20Lite token = IERC20Lite(stableTokenGHSProxy);
    // string memory currentName = token.name();
    // assertEq(currentName, GHS_NAME, "Token has not been changed to the correct name");
    // console.log("🟢 Token has been updated to %s", GHS_NAME);
  }
}
