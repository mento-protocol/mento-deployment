// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable contract-name-camelcase
pragma solidity ^0.8.18;

import { console2 } from "forge-std/console2.sol";
import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { ChainlinkRelayerFactory } from "mento-core-2.5.0/oracles/ChainlinkRelayerFactory.sol";
import { IChainlinkRelayer } from "mento-core-2.5.0/interfaces/IChainlinkRelayer.sol";
import { toRateFeedId, aggregators } from "script/utils/mento/Oracles.sol";

contract OracleMigration_Deploy_ChainlinkRelayers is Script {
  using Contracts for Contracts.Cache;

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

    address[] memory relayersAfter = relayerFactory.getRelayers();
    console2.log("Relayer factory address: %s", address(relayerFactory));
    console2.log("Number of relayers deployed: %d", relayersAfter.length);

    for (uint i = 0; i < relayersAfter.length; i++) {
      address relayerAddress = relayersAfter[i];
      IChainlinkRelayer relayer = IChainlinkRelayer(relayerAddress);
      console2.log("Relayer(%s, feed:%s): %s", relayerAddress, relayer.rateFeedId(), relayer.rateFeedDescription());
      console2.log();
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
    relayers = new Relayer[](9);

    // ==================== eXOF ====================
    relayers[0] = Relayer({
      rateFeed: "CELO/XOF",
      rateFeedIdentifier: eXOFProxy,
      rateFeedDescription: "CELO/XOF (CELO/USD:USD/XOF)",
      maxTimestampSpread: 5 minutes,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.XOFUSD"), invert: true })
      )
    });
    relayers[1] = Relayer({
      rateFeed: "EUROC/XOF",
      rateFeedIdentifier: toRateFeedId("EUROCXOF"),
      rateFeedDescription: "EUROC/XOF (EUROC/USD:USD/XOF)",
      maxTimestampSpread: 5 minutes,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.EURCUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.XOFUSD"), invert: true })
      )
    });
    relayers[2] = Relayer({
      rateFeed: "EUR/XOF",
      rateFeedIdentifier: toRateFeedId("EURXOF"),
      rateFeedDescription: "EUR/XOF (EUR/USD:USD/XOF)",
      maxTimestampSpread: 5 minutes,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.EURUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.XOFUSD"), invert: true })
      )
    });

    // ==================== cKES ====================
    relayers[3] = Relayer({
      rateFeed: "CELO/KES",
      rateFeedIdentifier: cKESProxy,
      rateFeedDescription: "CELO/KES (CELO/USD:USD/KES)",
      maxTimestampSpread: 5 minutes,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.CELOUSD"), invert: false }),
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.KESUSD"), invert: true })
      )
    });
    relayers[4] = Relayer({
      rateFeed: "KES/USD",
      rateFeedIdentifier: toRateFeedId("KESUSD"),
      rateFeedDescription: "KES/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.KESUSD"), invert: false })
      )
    });

    // ==================== USDT ====================
    relayers[5] = Relayer({
      rateFeed: "USDT/USD",
      rateFeedIdentifier: toRateFeedId("USDTUSD"),
      rateFeedDescription: "USDT/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.USDTUSD"), invert: false })
      )
    });

    // ================= New relayers that will be used in future restructuring proposal =================
    // EUR/USD
    relayers[6] = Relayer({
      rateFeed: "EUR/USD",
      rateFeedIdentifier: toRateFeedId("relayed:EURUSD"),
      rateFeedDescription: "EUR/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.EURUSD"), invert: false })
      )
    });
    // BRL/USD
    relayers[7] = Relayer({
      rateFeed: "BRL/USD",
      rateFeedIdentifier: toRateFeedId("relayed:BRLUSD"),
      rateFeedDescription: "BRL/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.BRLUSD"), invert: false })
      )
    });
    // XOF/USD
    relayers[8] = Relayer({
      rateFeed: "XOF/USD",
      rateFeedIdentifier: toRateFeedId("relayed:XOFUSD"),
      rateFeedDescription: "XOF/USD",
      maxTimestampSpread: 0,
      aggregators: aggregators(
        IChainlinkRelayer.ChainlinkAggregator({ aggregator: contracts.dependency("Chainlink.XOFUSD"), invert: false })
      )
    });

    return relayers;
  }
}
