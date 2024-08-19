// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { MockPHPUSDAggregator } from "contracts/MockPHPUSDAggregator.sol";

/**
 * Usage: yarn script:dev -n alfajores -s DeployMockChainlinkAggregator
 * Used to deploy mock Chainlink Aggregators to Alfajores to be used
 * in testnet relayers to mimic mainnet more closely.
 */
contract DeployMockPHPUSDAggregator is Script {
  function run() public {
    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      new MockPHPUSDAggregator();
    }
    vm.stopBroadcast();
  }
}
