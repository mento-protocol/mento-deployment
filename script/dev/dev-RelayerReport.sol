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

/*
 * How to run:
 * yarn script:dev -n alfajores -s RelayerReport -r "run(string)" "chainlink:CELO/USD:v1"
 */
contract RelayerReport is Script {
  using Contracts for Contracts.Cache;
  ChainlinkRelayerFactory relayerFactory;

  constructor() Script() {
    contracts.load("ChainlinkRelayerFactory", "checkpoint");
    relayerFactory = ChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
  }

  function run(string calldata rateFeed) public {
    IChainlinkRelayer relayer;
    address[] memory relayers = relayerFactory.getRelayers();
    address requestedRateFeedId = toRateFeedId(rateFeed);
    for (uint i = 0; i < relayers.length; i++) {
      address rateFeedId = IChainlinkRelayer(relayers[i]).rateFeedId();
      if (rateFeedId == requestedRateFeedId) {
        relayer = IChainlinkRelayer(relayers[i]);
        break;
      }
    }

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      // CELOUSD_relayer.relay();
      relayer.relay();
    }
    vm.stopBroadcast();
  }

  function toRateFeedId(string memory rateFeedString) internal pure returns (address) {
    return address(uint160(uint256(keccak256(abi.encodePacked(rateFeedString)))));
  }
}
