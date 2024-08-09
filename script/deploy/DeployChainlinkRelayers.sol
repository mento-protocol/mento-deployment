// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { ChainlinkRelayerFactory } from "mento-core-develop/oracles/ChainlinkRelayerFactory.sol";
import { ChainlinkRelayerFactoryProxy } from "mento-core-develop/oracles/ChainlinkRelayerFactoryProxy.sol";
import { ChainlinkRelayerFactoryProxyAdmin } from "mento-core-develop/oracles/ChainlinkRelayerFactoryProxyAdmin.sol";
import { IChainlinkRelayer } from "mento-core-develop/interfaces/IChainlinkRelayer.sol";

contract DeployChainlinkRelayers is Script {
  using Contracts for Contracts.Cache;

  struct Relayer {
    string rateFeed;
    IChainlinkRelayer.Config config;
  }

  Relayer[] relayers = [
    Relayer({
      rateFeed: "chainlink:CELO/USD:v1",
      config: singleAggConfig(contracts.dependency("Chainlink.CELOUSD"), false)
    }),
    Relayer({
      rateFeed: "chainlink:USDT/USD:v1",
      config: singleAggConfig(contracts.dependency("Chainlink.USDTUSD"), false)
    }),
    Relayer({
      rateFeed: "chainlink:CELO/PHP",
      config: IChainlinkRelayer.Config({
        maxTimestampSpread: 1000,
        chainlinkAggregator0: contracts.dependency("Chainlink.CELOUSD"),
        chainlinkAggregator1: contracts.dependency("Chainlink.PHPUSD"),
        chainlinkAggregator2: address(0),
        chainlinkAggregator3: address(0),
        invertAggregator0: false,
        invertAggregator1: true,
        invertAggregator2: false,
        invertAggregator3: false
      })
    }),
    Relayer({ rateFeed: "PHP/USD", config: singleAggConfig(contracts.dependency("Chainlink.PHPUSD"), false) })
  ];

  ChainlinkRelayerFactory relayerFactory;

  constructor() Script() {
    contracts.load("ChainlinkRelayerFactory", "checkpoint");
    relayerFactory = ChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
  }

  function run() public {
    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      for (uint i = 0; i < relayers.length; i++) {
        deployRelayerIfNoneOrDifferent(toRateFeedId(relayers[i].rateFeed), relayers[i].config);
      }
    }
    vm.stopBroadcast();

    for (uint i = 0; i < relayers.length; i++) {
      address rateFeedId = toRateFeedId(relayers[i].rateFeed);
      address relayer = relayerFactory.getRelayer(rateFeedId);
      console.log(relayers[i].rateFeed, rateFeedId, relayer);
    }
  }

  function deployRelayerIfNoneOrDifferent(address rateFeedId, IChainlinkRelayer.Config memory config) internal {
    address relayer = address(relayerFactory.deployedRelayers(rateFeedId));
    address newRelayer = relayerFactory.computedRelayerAddress(rateFeedId, config);
    if (newRelayer != relayer) {
      if (relayer == address(0)) {
        relayerFactory.deployRelayer(rateFeedId, config);
      } else {
        relayerFactory.redeployRelayer(rateFeedId, config);
      }
    }
  }

  function toRateFeedId(string memory rateFeedString) internal pure returns (address) {
    return address(uint160(uint256(keccak256(abi.encodePacked(rateFeedString)))));
  }

  function singleAggConfig(address aggregator, bool invert) internal pure returns (IChainlinkRelayer.Config memory) {
    return
      IChainlinkRelayer.Config({
        maxTimestampSpread: 0,
        chainlinkAggregator0: aggregator,
        chainlinkAggregator1: address(0),
        chainlinkAggregator2: address(0),
        chainlinkAggregator3: address(0),
        invertAggregator0: invert,
        invertAggregator1: false,
        invertAggregator2: false,
        invertAggregator3: false
      });
  }
}
