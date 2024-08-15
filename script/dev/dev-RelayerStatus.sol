// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { ChainlinkRelayerFactory } from "mento-core-develop/oracles/ChainlinkRelayerFactory.sol";
import { IChainlinkRelayer } from "mento-core-develop/interfaces/IChainlinkRelayer.sol";

import { toRateFeedId } from "script/utils/mento/Oracles.sol";

interface ISortedOracles {
  function numRates(address) external view returns (uint256);

  function medianRate(address) external view returns (uint256, uint256);
}

/*
 * How to run:
 * yarn script:dev -n alfajores -s RelayerStatus -r "run(string)" "relayed:CELO/PHP"
 */
contract RelayerStatus is Script {
  using Contracts for Contracts.Cache;
  ISortedOracles sortedOracles;
  ChainlinkRelayerFactory relayerFactory;

  constructor() Script() {
    contracts.loadSilent("DeployChainlinkRelayerFactory", "latest");
    relayerFactory = ChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
  }

  function run(string calldata rateFeed) public view {
    address rateFeedId = toRateFeedId(rateFeed);
    // IChainlinkRelayer relayer = IChainlinkRelayer(relayerFactory.getRelayer(rateFeedId));
    console.log("RateFeedID: %s", rateFeedId);
    console.log("Num rates: %d", sortedOracles.numRates(rateFeedId));
  }
}
