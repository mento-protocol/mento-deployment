// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { ChainlinkRelayerFactory } from "mento-core-develop/oracles/ChainlinkRelayerFactory.sol";
import { ChainlinkRelayerFactoryProxy } from "mento-core-develop/oracles/ChainlinkRelayerFactoryProxy.sol";
import { ChainlinkRelayerFactoryProxyAdmin } from "mento-core-develop/oracles/ChainlinkRelayerFactoryProxyAdmin.sol";
import { IChainlinkRelayer } from "mento-core-develop/interfaces/IChainlinkRelayer.sol";
import { toRateFeedId, aggregators } from "script/utils/mento/Oracles.sol";

contract MU07_Deploy_ChainlinkRelayers is Script {
  using Contracts for Contracts.Cache;
  using { toRateFeedId } for string;

  struct Relayer {
    string rateFeed;
    string rateFeedDescription;
    IChainlinkRelayer.ChainlinkAggregator[] aggregators;
  }

  Relayer[] relayers = [
    Relayer({
      rateFeed: "relayed:CELOPHP",
      rateFeedDescription: "CELO/PHP (CELO/USD:USD/PHP)",
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.PHPUSD"), invert: true })
      )
    }),
    Relayer({
      rateFeed: "relayed:PHPUSD",
      rateFeedDescription: "PHP/USD",
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.PHPUSD"), invert: false })
      )
    })
  ];

  ChainlinkRelayerFactory relayerFactory;

  constructor() Script() {
    contracts.load("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    relayerFactory = ChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
  }

  function run() public {
    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      for (uint i = 0; i < relayers.length; i++) {
        deployRelayerIfNoneOrDifferent(relayers[i]);
      }
    }
    vm.stopBroadcast();

    for (uint i = 0; i < relayers.length; i++) {
      address rateFeedId = toRateFeedId(relayers[i].rateFeed);
      address relayer = relayerFactory.getRelayer(rateFeedId);
      console.log(relayers[i].rateFeed, rateFeedId, relayer);
    }
  }

  function deployRelayerIfNoneOrDifferent(Relayer memory relayer) internal {
    address rateFeedId = relayer.rateFeed.toRateFeedId();
    address relayerAddress = address(relayerFactory.deployedRelayers(rateFeedId));
    address newRelayerAddress = relayerFactory.computedRelayerAddress(
      rateFeedId,
      relayer.rateFeedDescription,
      relayer.aggregators
    );
    if (newRelayerAddress != relayerAddress) {
      if (relayerAddress == address(0)) {
        relayerFactory.deployRelayer(rateFeedId, relayer.rateFeedDescription, relayer.aggregators);
      } else {
        relayerFactory.redeployRelayer(rateFeedId, relayer.rateFeedDescription, relayer.aggregators);
      }
    }
  }
}
