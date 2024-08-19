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
 * yarn script:dev -n alfajores -s RelayerStatus
 */
contract RelayerStatus is Script {
  using Contracts for Contracts.Cache;
  ISortedOracles sortedOracles;
  ChainlinkRelayerFactory relayerFactory;

  constructor() Script() {
    contracts.load("MU07-Deploy-ChainlinkRelayerFactory", "latest");
    relayerFactory = ChainlinkRelayerFactory(contracts.deployed("ChainlinkRelayerFactoryProxy"));
    sortedOracles = ISortedOracles(contracts.celoRegistry("SortedOracles"));
  }

  function run() public {
    address[] memory relayers = relayerFactory.getRelayers();

    for (uint i = 0; i < relayers.length; i++) {
      IChainlinkRelayer relayer = IChainlinkRelayer(relayers[i]);
      address rateFeedId = relayer.rateFeedId();
      string memory description = relayer.rateFeedDescription();
      (uint256 num, ) = sortedOracles.medianRate(rateFeedId);
      console.log("====== %s =======", description);
      console.log("RateFeedID: %s", rateFeedId);
      console.log("Num rates: %d", sortedOracles.numRates(rateFeedId));
      console.log("Median rate: %d", num);
    }
  }
}
