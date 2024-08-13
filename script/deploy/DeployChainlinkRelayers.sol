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
    string rateFeedDescription;
    uint256 maxTimestampSpread;
    IChainlinkRelayer.ChainlinkAggregator[] aggregators;
  }

  Relayer[] relayers = [
    Relayer({
      rateFeed: "CELO/PHP",
      rateFeedDescription: "CELO/PHP (CELO/USD * USD/PHP)",
      maxTimestampSpread: maxTimestampSpread,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.PHPUSD"), invert: true })
      )
    }),
    Relayer({
      rateFeed: "PHP/USD",
      rateFeedDescription: "PHP/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.PHPUSD"), invert: false })
      )
    })
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

  function aggregators(
    IChainlinkRelayer.ChainlinkAggregator agg0
  ) internal pure returns (IChainlinkRelayer.ChainlinkAggregator[] memory aggs) {
    aggs = new IChainlinkRelayer.ChainlinkAggregator[](1);
    aggs[0] = agg0;
  }

  function aggregators(
    IChainlinkRelayer.ChainlinkAggregator agg0,
    IChainlinkRelayer.ChainlinkAggregator agg1
  ) internal pure returns (IChainlinkRelayer.ChainlinkAggregator[] memory aggs) {
    aggs = new IChainlinkRelayer.ChainlinkAggregator[](2);
    aggs[0] = agg0;
    aggs[1] = agg1;
  }

  function aggregators(
    IChainlinkRelayer.ChainlinkAggregator agg0,
    IChainlinkRelayer.ChainlinkAggregator agg1,
    IChainlinkRelayer.ChainlinkAggregator agg2
  ) internal pure returns (IChainlinkRelayer.ChainlinkAggregator[] memory aggs) {
    aggs = new IChainlinkRelayer.ChainlinkAggregator[](3);
    aggs[0] = agg0;
    aggs[1] = agg1;
    aggs[2] = agg2;
  }

  function aggregators(
    IChainlinkRelayer.ChainlinkAggregator agg0,
    IChainlinkRelayer.ChainlinkAggregator agg1,
    IChainlinkRelayer.ChainlinkAggregator agg2,
    IChainlinkRelayer.ChainlinkAggregator agg3
  ) internal pure returns (IChainlinkRelayer.ChainlinkAggregator[] memory aggs) {
    aggs = new IChainlinkRelayer.ChainlinkAggregator[](4);
    aggs[0] = agg0;
    aggs[1] = agg1;
    aggs[2] = agg2;
    aggs[3] = agg3;
  }
}
