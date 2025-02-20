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

contract SunsetOraclesCGP01_Deploy_ChainlinkRelayers is Script {
  using Contracts for Contracts.Cache;

  address payable private cKESProxy;
  address payable private eXOFProxy;

  struct Relayer {
    string rateFeed;
    address rateFeedIdentifier;
    string rateFeedDescription;
    uint256 maxTimestampSpread;
    IChainlinkRelayer.ChainlinkAggregator[] aggregators;
  }

  ChainlinkRelayerFactory private relayerFactory;

  constructor() Script() {
    contracts.load("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    contracts.load("cKES-00-Create-Proxies", "latest");
    contracts.load("eXOF-00-Create-Proxies", "latest");

    relayerFactory = ChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    cKESProxy = contracts.deployed("StableTokenKESProxy");
    eXOFProxy = contracts.deployed("StableTokenXOFProxy");
  }

  function run() public {
    Relayer[] memory relayers = getRelayersConfigs();
    // vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      for (uint i = 0; i < relayers.length; i++) {
        deployRelayerIfNoneOrDifferent(relayers[i]);
      }
    }
    // vm.stopBroadcast();

    for (uint i = 0; i < relayers.length; i++) {
      address relayer = relayerFactory.getRelayer(relayers[i].rateFeedIdentifier);
      console.log("%s - identifier:%s, relayer:%s", relayers[i].rateFeed, relayers[i].rateFeedIdentifier, relayer);
    }
  }

  function deployRelayerIfNoneOrDifferent(Relayer memory relayer) internal {
    address relayerAddress = address(relayerFactory.deployedRelayers(relayer.rateFeedIdentifier));
    address newRelayerAddress = relayerFactory.computedRelayerAddress(
      relayer.rateFeedIdentifier,
      relayer.rateFeedDescription,
      relayer.maxTimestampSpread,
      relayer.aggregators
    );
    if (newRelayerAddress != relayerAddress) {
      if (relayerAddress == address(0)) {
        relayerFactory.deployRelayer(
          relayer.rateFeedIdentifier,
          relayer.rateFeedDescription,
          relayer.maxTimestampSpread,
          relayer.aggregators
        );
      } else {
        relayerFactory.redeployRelayer(
          relayer.rateFeedIdentifier,
          relayer.rateFeedDescription,
          relayer.maxTimestampSpread,
          relayer.aggregators
        );
      }
    }
  }

  function getRelayersConfigs() internal returns (Relayer[] memory relayers) {
    relayers = new Relayer[](6);

    // TODO: deploy mock relayers for all aggregators and add dependencies for Alfajores
    // also add read aggregator addresses for mainnet

    // TODO: Check the maxTimeStampSpread for pairs with > 1 aggregator. It seems like it could be 5 min:
    // time comparison to relay is: newest - oldest <= maxSpread
    // X       X       X        X       X
    //     Y     Y
    // 1 2 3 4 5 6 7 8 9 10 12 13 14 15 16

    // ===== cKES Relayers =====
    relayers[0] = Relayer({
      rateFeed: "CELO/KES",
      rateFeedIdentifier: cKESProxy,
      rateFeedDescription: "CELO/KES (CELO/USD:USD/KES)",
      maxTimestampSpread: 24 hours, // TODO: double check
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.KESUSD"), invert: true })
      )
    });
    relayers[1] = Relayer({
      rateFeed: "KESUSD",
      rateFeedIdentifier: toRateFeedId("KESUSD"),
      rateFeedDescription: "KES/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.KESUSD"), invert: false })
      )
    });

    // ===== eXOF Relayers =====
    relayers[2] = Relayer({
      rateFeed: "CELO/XOF",
      rateFeedIdentifier: eXOFProxy,
      rateFeedDescription: "CELO/XOF (CELO/USD:USD/XOF)",
      maxTimestampSpread: 24 hours, // TODO: double check
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.XOFUSD"), invert: true })
      )
    });

    relayers[3] = Relayer({
      rateFeed: "EUROCXOF",
      rateFeedIdentifier: toRateFeedId("EUROCXOF"),
      // TODO: check whether chainlink calls this EUROC or EURC for the description
      rateFeedDescription: "EUROC/XOF (EUROC/EUR:EUR/USD:USD/XOF)",
      maxTimestampSpread: 24 hours, // TODO: double check
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({
          // TODO: check whether chainlink calls this EUROC or EURC
          aggregator: contracts.dependency("Chainlink.EUROCEUR"),
          invert: false
        }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.EURUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.XOFUSD"), invert: true })
      )
    });

    relayers[4] = Relayer({
      rateFeed: "EURXOF",
      rateFeedIdentifier: toRateFeedId("EURXOF"),
      rateFeedDescription: "EUR/XOF (EUR/USD:USD/XOF)",
      maxTimestampSpread: 24 hours, // TODO: double check
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.EURUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.XOFUSD"), invert: true })
      )
    });

    // ===== USDT/USD Relayer =====
    relayers[5] = Relayer({
      rateFeed: "USDTUSD",
      rateFeedIdentifier: toRateFeedId("USDTUSD"),
      rateFeedDescription: "USDT/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.USDTUSD"), invert: false })
      )
    });

    return relayers;
  }
}
