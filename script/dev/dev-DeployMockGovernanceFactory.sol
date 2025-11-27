// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import { console2 } from "forge-std/Script.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { MockGovernanceFactory } from "contracts/MockGovernanceFactory.sol";

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
