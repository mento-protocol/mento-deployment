// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { Test } from "forge-std/Test.sol";
import { ICeloProxy } from "contracts/interfaces/ICeloProxy.sol";
import { IOwnable } from "contracts/interfaces/IOwnable.sol";
import { IERC20 } from "contracts/interfaces/IERC20.sol";
import { IERC20Metadata } from "mento-core-2.3.1/common/interfaces/IERC20Metadata.sol";
import { GovernanceScript } from "script/utils/Script.sol";
import { console2 as console } from "forge-std/Script.sol";

contract cGHSRenameChecks is GovernanceScript, Test {
  string public constant GHS_NAME = "Celo Ghanaian Cedi";

  address public stableTokenGHSProxy;
  address public originalImplementation; // StableTokenV2
  address public tempImplementation;
  address public proxyOwner;
  address public testUser;

  function setUp() public {
    contracts.loadSilent("MU04-00-Create-Implementations", "latest");
    contracts.loadSilent("cGHS-00-Deploy-Proxy", "latest");
    contracts.loadSilent("cGHS-Rename-Deploy-Implementation", "latest");

    stableTokenGHSProxy = contracts.deployed("StableTokenGHSProxy");
    stableTokenV2Implementation = contracts.deployed("StableTokenV2");
    tempImplementation = contracts.deployed("TempStable");
  }

  function run() public {
    // Verify the implmentation is still the original StableTokenV2
    address currentImplementation = ICeloProxy(stableTokenGHSProxy)._getImplementation();
    assertEq(currentImplementation, expectedImplementation, "Implementation is not the expected StableTokenV2");

    // Verify the name is correct
    IERC20Metadata token = IERC20Metadata(stableTokenGHSProxy);
    string memory currentName = token.name();
    assertEq(currentName, GHS_NAME, "Token has not been changed to the correct name");
  }
}
