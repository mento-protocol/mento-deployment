// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import { console2 } from "forge-std/Script.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { MockGovernanceFactory } from "contracts/MockGovernanceFactory.sol";

/**
 * Usage: yarn script:dev -n sepolia -s DeployMockGovernanceFactory
 * Used to deploy the MockGovernanceFactory contract to Sepolia.
 */
contract DeployMockGovernanceFactory is Script {
  function run() public {
    require(ChainLib.isSepolia(), "Only Sepolia is supported");

    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      new MockGovernanceFactory();
    }
    vm.stopBroadcast();
  }
}
