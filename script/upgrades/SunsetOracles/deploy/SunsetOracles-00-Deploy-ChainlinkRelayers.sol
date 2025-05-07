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

contract SunsetOracles_Deploy_ChainlinkRelayers is Script {
  using Contracts for Contracts.Cache;

  address private cUSDProxy;
  address private cEURProxy;
  address private cBRLProxy;
  address payable private eXOFProxy;
  address payable private cKESProxy;

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

    cUSDProxy = contracts.celoRegistry("StableToken");
    cEURProxy = contracts.celoRegistry("StableTokenEUR");
    cBRLProxy = contracts.celoRegistry("StableTokenBRL");
    eXOFProxy = contracts.deployed("StableTokenXOFProxy");
    cKESProxy = contracts.deployed("StableTokenKESProxy");
  }

  function run() public {
    Relayer[] memory relayers = getRelayersConfigs();
    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      for (uint i = 0; i < relayers.length; i++) {
        deployRelayerIfNoneOrDifferent(relayers[i]);
      }
    }
    vm.stopBroadcast();

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

  /* solhint-disable */
  function getRelayersConfigs() internal returns (Relayer[] memory relayers) {
    relayers = new Relayer[](13);

    // ==================== ALL CELO/XXX pairs ====================
    relayers[0] = Relayer({
      rateFeed: "CELO/USD",
      rateFeedIdentifier: cUSDProxy,
      rateFeedDescription: "CELO/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false })
      )
    });

    relayers[1] = Relayer({
      rateFeed: "CELO/EUR",
      rateFeedIdentifier: cEURProxy,
      rateFeedDescription: "CELO/EUR (CELO/USD:USD/EUR)",
      maxTimestampSpread: 5 minutes,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.EURUSD"), invert: true })
      )
    });

    relayers[2] = Relayer({
      rateFeed: "CELO/BRL",
      rateFeedIdentifier: cBRLProxy,
      rateFeedDescription: "CELO/BRL (CELO/USD:USD/BRL)",
      maxTimestampSpread: 5 minutes,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.BRLUSD"), invert: true })
      )
    });

    relayers[3] = Relayer({
      rateFeed: "CELO/XOF",
      rateFeedIdentifier: eXOFProxy,
      rateFeedDescription: "CELO/XOF (CELO/USD:USD/XOF)",
      maxTimestampSpread: 5 minutes,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.XOFUSD"), invert: true })
      )
    });

    relayers[4] = Relayer({
      rateFeed: "CELO/KES",
      rateFeedIdentifier: cKESProxy,
      rateFeedDescription: "CELO/KES (CELO/USD:USD/KES)",
      maxTimestampSpread: 5 minutes,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.KESUSD"), invert: true })
      )
    });

    // ==================== ALL USDC/XXX pairs ====================
    relayers[5] = Relayer({
      rateFeed: "USDC/USD",
      rateFeedIdentifier: toRateFeedId("USDCUSD"),
      rateFeedDescription: "USDC/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.USDCUSD"), invert: false })
      )
    });

    relayers[6] = Relayer({
      rateFeed: "USDC/EUR",
      rateFeedIdentifier: toRateFeedId("USDCEUR"),
      rateFeedDescription: "USDC/EUR (USDC/USD:USD/EUR)",
      maxTimestampSpread: 5 minutes,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.USDCUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.EURUSD"), invert: true })
      )
    });

    relayers[7] = Relayer({
      rateFeed: "USDC/BRL",
      rateFeedIdentifier: toRateFeedId("USDCBRL"),
      rateFeedDescription: "USDC/BRL (USDC/USD:USD/BRL)",
      maxTimestampSpread: 5 minutes,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.USDCUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.BRLUSD"), invert: true })
      )
    });

    // ==================== ALL USDT/XXX pairs ====================
    relayers[8] = Relayer({
      rateFeed: "USDT/USD",
      rateFeedIdentifier: toRateFeedId("USDTUSD"),
      rateFeedDescription: "USDT/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.USDTUSD"), invert: false })
      )
    });

    // ==================== ALL EUROC/XXX pairs ====================
    relayers[9] = Relayer({
      rateFeed: "EUROC/EUR",
      rateFeedIdentifier: toRateFeedId("EUROCEUR"),
      rateFeedDescription: "EUROC/EUR (EUROC/USD:USD/EUR)",
      maxTimestampSpread: 5 minutes,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.EURCUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.EURUSD"), invert: true })
      )
    });

    relayers[10] = Relayer({
      rateFeed: "EUROC/XOF",
      rateFeedIdentifier: toRateFeedId("EUROCXOF"),
      rateFeedDescription: "EUROC/XOF (EUROC/USD:USD/XOF)",
      maxTimestampSpread: 5 minutes,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.EURCUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.XOFUSD"), invert: true })
      )
    });

    // ==================== EUR/XOF ====================
    relayers[11] = Relayer({
      rateFeed: "EUR/XOF",
      rateFeedIdentifier: toRateFeedId("EURXOF"),
      rateFeedDescription: "EUR/XOF (EUR/USD:USD/XOF)",
      maxTimestampSpread: 5 minutes,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.EURUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.XOFUSD"), invert: true })
      )
    });

    // ==================== KES/USD ====================
    relayers[12] = Relayer({
      rateFeed: "KES/USD",
      rateFeedIdentifier: toRateFeedId("KESUSD"),
      rateFeedDescription: "KES/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.KESUSD"), invert: false })
      )
    });

    return relayers;
  }
  /* solhint-enable */
}
