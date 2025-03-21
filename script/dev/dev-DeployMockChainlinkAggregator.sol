// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { MockChainlinkAggregator } from "contracts/MockChainlinkAggregator.sol";

/**
 * Usage: yarn script:dev -n alfajores -s DeployMockChainlinkAggregator -r "run(string, uint8)" PHPUSD 8
 * Used to deploy mock Chainlink Aggregators to Alfajores to be used
 * in testnet relayers to mimic mainnet more closely.
 * ========== IMPORTANT ======================================
 * @dev After deploying the script save the broadcast file as run-{rateFeed}.json,
 * update the reference in `dependencies.json` to the new waddress,
 * and update the dev-UpdateMockChainlinkAggregators script if it's a new aggregator
 * ===========================================================
 */
contract DeployMockChainlinkAggregator is Script {
  function run(string memory rateFeed, uint8 decimals) public {
    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      new MockChainlinkAggregator(rateFeed, decimals);
    }
    vm.stopBroadcast();
  }
}
