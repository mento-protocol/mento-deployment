// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable contract-name-camelcase
pragma solidity ^0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { ChainlinkRelayerFactory } from "mento-core-2.5.0/oracles/ChainlinkRelayerFactory.sol";
import { ChainlinkRelayerFactoryProxy } from "mento-core-2.5.0/oracles/ChainlinkRelayerFactoryProxy.sol";
import { ChainlinkRelayerFactoryProxyAdmin } from "mento-core-2.5.0/oracles/ChainlinkRelayerFactoryProxyAdmin.sol";
import { IChainlinkRelayer } from "mento-core-2.5.0/interfaces/IChainlinkRelayer.sol";
import { toRateFeedId, aggregators } from "script/utils/mento/Oracles.sol";

contract FX00_Deploy_ChainlinkRelayers is Script {
  using Contracts for Contracts.Cache;
  using { toRateFeedId } for string;

  struct Relayer {
    string rateFeed;
    string rateFeedDescription;
    uint256 maxTimestampSpread;
    IChainlinkRelayer.ChainlinkAggregator[] aggregators;
  }

  Relayer[] private relayers = [
    //  ==== GBP ====
    Relayer({
      rateFeed: "relayed:CELOGBP",
      rateFeedDescription: "CELO/GBP (CELO/USD:USD/GBP)",
      maxTimestampSpread: 24 hours,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.GBPUSD"), invert: true })
      )
    }),
    Relayer({
      rateFeed: "relayed:GBPUSD",
      rateFeedDescription: "GBP/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.GBPUSD"), invert: false })
      )
    }),
    //  ==== ZAR ====
    Relayer({
      rateFeed: "relayed:CELOZAR",
      rateFeedDescription: "CELO/ZAR (CELO/USD:USD/ZAR)",
      maxTimestampSpread: 24 hours,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.ZARUSD"), invert: true })
      )
    }),
    Relayer({
      rateFeed: "relayed:ZARUSD",
      rateFeedDescription: "ZAR/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.ZARUSD"), invert: false })
      )
    }),
    //  ==== CHF ====
    Relayer({
      rateFeed: "relayed:CELOCHF",
      rateFeedDescription: "CELO/CHF (CELO/USD:USD/CHF)",
      maxTimestampSpread: 24 hours,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CHFUSD"), invert: true })
      )
    }),
    Relayer({
      rateFeed: "relayed:CHFUSD",
      rateFeedDescription: "CHF/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CHFUSD"), invert: false })
      )
    }),
    //  ==== CAD ====
    Relayer({
      rateFeed: "relayed:CELOCAD",
      rateFeedDescription: "CELO/CAD (CELO/USD:USD/CAD)",
      maxTimestampSpread: 24 hours,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CADUSD"), invert: true })
      )
    }),
    Relayer({
      rateFeed: "relayed:CADUSD",
      rateFeedDescription: "CAD/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CADUSD"), invert: false })
      )
    }),
    //  ==== AUD ====
    Relayer({
      rateFeed: "relayed:CELOAUD",
      rateFeedDescription: "CELO/AUD (CELO/USD:USD/AUD)",
      maxTimestampSpread: 24 hours,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.AUDUSD"), invert: true })
      )
    }),
    Relayer({
      rateFeed: "relayed:AUDUSD",
      rateFeedDescription: "AUD/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.AUDUSD"), invert: false })
      )
    })
  ];

  ChainlinkRelayerFactory private relayerFactory;

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
      console.log("%s - ratefeed:%s, relayer:%s", relayers[i].rateFeed, rateFeedId, relayer);
    }
  }

  function deployRelayerIfNoneOrDifferent(Relayer memory relayer) internal {
    address rateFeedId = relayer.rateFeed.toRateFeedId();
    address relayerAddress = address(relayerFactory.deployedRelayers(rateFeedId));
    address newRelayerAddress = relayerFactory.computedRelayerAddress(
      rateFeedId,
      relayer.rateFeedDescription,
      relayer.maxTimestampSpread,
      relayer.aggregators
    );
    if (newRelayerAddress != relayerAddress) {
      if (relayerAddress == address(0)) {
        relayerFactory.deployRelayer(
          rateFeedId,
          relayer.rateFeedDescription,
          relayer.maxTimestampSpread,
          relayer.aggregators
        );
      } else {
        relayerFactory.redeployRelayer(
          rateFeedId,
          relayer.rateFeedDescription,
          relayer.maxTimestampSpread,
          relayer.aggregators
        );
      }
    }
  }
}
