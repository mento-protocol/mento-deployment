// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable contract-name-camelcase
pragma solidity ^0.8.18;

import { console2 } from "forge-std/console2.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { ChainlinkRelayerFactory } from "mento-core-2.5.0/oracles/ChainlinkRelayerFactory.sol";
import { ChainlinkRelayerFactoryProxy } from "mento-core-2.5.0/oracles/ChainlinkRelayerFactoryProxy.sol";
import { ChainlinkRelayerFactoryProxyAdmin } from "mento-core-2.5.0/oracles/ChainlinkRelayerFactoryProxyAdmin.sol";
import { IChainlinkRelayer } from "mento-core-2.5.0/interfaces/IChainlinkRelayer.sol";
import { toRateFeedId, aggregators } from "script/utils/mento/Oracles.sol";

interface IChainlinkAggregator {
  function description() external view returns (string memory);
}

contract OracleMigration_Deploy_CheckExistingRelayers is Script {
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
    console2.log("\n\n");
    // vm.startBroadcast(ChainLib.deployerPrivateKey());
    // {
    //   for (uint i = 0; i < relayers.length; i++) {
    //     deployRelayerIfNoneOrDifferent(relayers[i]);
    //   }
    // }
    // vm.stopBroadcast();

    address[] memory relayers = relayerFactory.getRelayers();
    console2.log("Relayer factory address: %s", address(relayerFactory));
    console2.log("Number of relayers deployed: %d", relayers.length);

    for (uint i = 0; i < relayers.length; i++) {
      address relayerAddress = relayers[i];
      IChainlinkRelayer relayer = IChainlinkRelayer(relayerAddress);
      console2.log("Relayer(%s): %s", relayerAddress, relayer.rateFeedDescription());

      IChainlinkRelayer.ChainlinkAggregator[] memory aggregators = relayer.getAggregators();
      for (uint j = 0; j < aggregators.length; j++) {
        address aggregatorAddress = aggregators[j].aggregator;
        console2.log("\tAggregator(%s) - %s", aggregatorAddress, IChainlinkAggregator(aggregatorAddress).description());
      }
      console2.log();
    }
  }
}
