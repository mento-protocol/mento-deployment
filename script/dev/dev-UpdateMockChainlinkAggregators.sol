// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable var-name-mixedcase, const-name-snakecase
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

  function description() external view returns (string memory);
}

interface IMockAggregator {
  function setAnswer(int256 answer) external;

  function description() external view returns (string memory);
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
  address private constant PHPUSDMainnetAggregator = 0x4ce8e628Bb82Ea5271908816a6C580A71233a66c;
  address private constant CELOUSDMainnetAggregator = 0x0568fD19986748cEfF3301e55c0eb1E729E0Ab7e;
  address private constant COPUSDMainnetAggregator = 0x97b770B0200CCe161907a9cbe0C6B177679f8F7C;
  address private constant GHSUSDMainnetAggregator = 0x2719B648DB57C5601Bd4cB2ea934Dec6F4262cD8;

  mapping(address => address) private mockForAggregator;
  mapping(address => int256) private aggregatorAnswers;
  mapping(address => string) private aggregatorDescription;
  address[] private aggregatorsToForward;

  constructor() Script() {
    if (ChainLib.isAlfajores()) {
      setUp_alfajores();
    } else {
      console.log("This script is only meant to be run on testnets");
    }
  }

  function setUp_alfajores() internal {
    /// @dev Load additional deployed aggregators here to forward rates
    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "PHPUSD");
    address PHPUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "COPUSD");
    address COPUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    contracts.loadSilent("dev-DeployMockChainlinkAggregator", "GHSUSD");
    address GHSUSDTestnetMock = contracts.deployed("MockChainlinkAggregator");

    mockForAggregator[PHPUSDMainnetAggregator] = PHPUSDTestnetMock;
    mockForAggregator[COPUSDMainnetAggregator] = COPUSDTestnetMock;
    mockForAggregator[GHSUSDMainnetAggregator] = GHSUSDTestnetMock;

    aggregatorsToForward.push(PHPUSDMainnetAggregator);
    aggregatorsToForward.push(COPUSDMainnetAggregator);
    aggregatorsToForward.push(GHSUSDMainnetAggregator);
  }

  function run() public {
    uint256 celoFork = vm.createFork("celo");
    uint256 testnetFork = vm.createFork(ChainLib.rpcToken());

    vm.selectFork(celoFork);
    for (uint i = 0; i < aggregatorsToForward.length; i++) {
      address agg = aggregatorsToForward[i];
      (, int256 answer, , , ) = IAggregatorV3(agg).latestRoundData();
      aggregatorAnswers[agg] = answer;
      aggregatorDescription[agg] = IAggregatorV3(agg).description();
    }

    vm.selectFork(testnetFork);

    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      for (uint i = 0; i < aggregatorsToForward.length; i++) {
        address agg = aggregatorsToForward[i];
        address mock = mockForAggregator[agg];
        int256 answer = aggregatorAnswers[agg];
        IMockAggregator(mock).setAnswer(answer);
        console.log("Update %s mock aggregator with value: %d", IMockAggregator(mock).description(), uint256(answer));
        console.log("       From mainnet aggregator: %s (%s)", aggregatorDescription[agg], address(agg));
        console.log("       Testnet mock aggregator: %s", mock);
      }
    }
    vm.stopBroadcast();
  }
}
