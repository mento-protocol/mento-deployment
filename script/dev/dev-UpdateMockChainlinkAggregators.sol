// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

interface IAggregatorV3 {
  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface IMockAggregator {
  function setAnswer(int256 answer) external;
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
  address constant PHPUSDMainnetAggregator = 0x4ce8e628Bb82Ea5271908816a6C580A71233a66c;
  address PHPUSDTestnetMock;

  mapping(address => address) mockForAggregator;
  mapping(address => int256) aggregatorAnswers;
  address[] aggregatorsToForward;

  constructor() Script() {
    /// @dev Load additional deployed aggregators here to forward rates
    contracts.load("DeployMockPHPUSDAggregator", "latest");
    PHPUSDTestnetMock = contracts.deployed("MockPHPUSDAggregator");
    mockForAggregator[PHPUSDMainnetAggregator] = PHPUSDTestnetMock;

    aggregatorsToForward.push(PHPUSDMainnetAggregator);
  }

  function run() public {
    uint256 celoFork = vm.createFork("celo");
    uint256 alfajoresFork = vm.createFork("alfajores");

    vm.selectFork(celoFork);
    for (uint i = 0; i < aggregatorsToForward.length; i++) {
      address agg = aggregatorsToForward[i];
      (, int256 answer, , , ) = IAggregatorV3(agg).latestRoundData();
      aggregatorAnswers[agg] = answer;
    }

    vm.selectFork(alfajoresFork);

    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      for (uint i = 0; i < aggregatorsToForward.length; i++) {
        address agg = aggregatorsToForward[i];
        address mock = mockForAggregator[agg];
        int256 answer = aggregatorAnswers[agg];
        IMockAggregator(mock).setAnswer(answer);
      }
    }
    vm.stopBroadcast();
  }
}
