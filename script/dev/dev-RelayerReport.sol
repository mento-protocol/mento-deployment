// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { ChainlinkRelayerFactory } from "mento-core-2.5.0/oracles/ChainlinkRelayerFactory.sol";
import { ChainlinkRelayerFactoryProxy } from "mento-core-2.5.0/oracles/ChainlinkRelayerFactoryProxy.sol";
import { ChainlinkRelayerFactoryProxyAdmin } from "mento-core-2.5.0/oracles/ChainlinkRelayerFactoryProxyAdmin.sol";
import { IChainlinkRelayer } from "mento-core-2.5.0/interfaces/IChainlinkRelayer.sol";

import { toRateFeedId } from "script/utils/mento/Oracles.sol";

/*
 * How to run:
 * yarn script:dev -n alfajores -s RelayerReport
 */
contract RelayerReport is Script {
  using Contracts for Contracts.Cache;
  ChainlinkRelayerFactory private relayerFactory;

  constructor() Script() {
    contracts.load("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    relayerFactory = ChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
  }

  function run() public {
    address[] memory relayers = relayerFactory.getRelayers();

    for (uint i = 0; i < relayers.length; i++) {
      IChainlinkRelayer relayer = IChainlinkRelayer(relayers[i]);
      string memory description = relayer.rateFeedDescription();
      vm.startBroadcast(ChainLib.deployerPrivateKey());
      {
        try relayer.relay() {
          console.log("Relayed %s successfully.", description);
        } catch (bytes memory reason) {
          console.log("Could not relay %s", description);
          console.logBytes(reason);
        }
      }
      vm.stopBroadcast();
    }
  }
}
