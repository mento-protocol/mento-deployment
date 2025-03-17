// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";
import { Proxy } from "mento-core-2.3.1/common/Proxy.sol";
import { IERC20Lite } from "script/interfaces/IERC20Lite.sol";
import { Script } from "script/utils/Script.sol";
import { console2 as console } from "forge-std/Script.sol";

contract RenameCGHSChecks is Script, Test {
  string public constant GHS_NAME = "Celo Ghanaian Cedi";

  address payable public stableTokenGHSProxy;
  address public stableTokenV2Implementation;
  address public proxyOwner;
  address public testUser;

  constructor() public {
    setUp();
  }

  function setUp() public {
    contracts.loadSilent("MU04-00-Create-Implementations", "latest");
    contracts.loadSilent("cGHS-00-Deploy-Proxy", "latest");
    contracts.loadSilent("cGHS-00-Temp-Implementation", "latest");

    stableTokenGHSProxy = contracts.deployed("StableTokenGHSProxy");
    stableTokenV2Implementation = contracts.deployed("StableTokenV2");
  }

  function run() public {
    // Verify the implmentation is still the original StableTokenV2
    address currentImplementation = Proxy(stableTokenGHSProxy)._getImplementation();
    assertEq(currentImplementation, stableTokenV2Implementation, "Implementation is not the expected StableTokenV2");
    console.log("🟢 Implementation is the expected StableTokenV2");

    // Verify the name is correct
    IERC20Lite token = IERC20Lite(stableTokenGHSProxy);
    string memory currentName = token.name();
    assertEq(currentName, GHS_NAME, "Token has not been changed to the correct name");
    console.log("🟢 Token has been updated to %s", GHS_NAME);
  }
}
