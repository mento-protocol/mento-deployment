// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { MockAggregatorV3 } from "lib/mento-core-develop/test/mocks/MockAggregatorV3.sol";

interface IAggregatorV3 {
  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/**
 * Usage: yarn script:dev -n alfajores -s UpdateMockChainlinkAggregators
 * Chainlink doesn't report all rates on testnets so in order to have as close
 * of a setup as possible between environments we deploy MockAggregatorV3
 * instances for the data feeds that are missing on Alfajores.
 * This script pulls data from the mainnet aggregators and updates the
 * mocks on Alfajores, and can be run periodically during testing.
 */
contract UpdateMockChainlinkAggregators is Script {
  using Contracts for Contracts.Cache;
  address PHPUSD = 0x4ce8e628Bb82Ea5271908816a6C580A71233a66c;

  constructor() Script() {
    contracts.load("dev-DeployMockChainlinkAggregator", "PHPUSD");
  }

  function run() public {
    uint256 celoFork = vm.createFork("celo");
    uint256 alfajoresFork = vm.createFork("alfajores");
    vm.selectFork(celoFork);
    (, int256 answer, , uint256 timestamp, ) = IAggregatorV3(PHPUSD).latestRoundData();
    vm.selectFork(alfajoresFork);

    address PHPUSD_aggregator = contracts.deployed("PHPUSDAggregatorV3");
    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      MockAggregatorV3(PHPUSD_aggregator).setRoundData(answer, timestamp);
    }
    vm.stopBroadcast();
  }
}
