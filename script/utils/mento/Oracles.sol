// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-visibility
pragma solidity ^0.8;

import { IChainlinkRelayer } from "mento-core-2.5.0/interfaces/IChainlinkRelayer.sol";

function toRateFeedId(string memory rateFeedString) pure returns (address) {
  return address(uint160(uint256(keccak256(abi.encodePacked(rateFeedString)))));
}

function aggregators(
  IChainlinkRelayer.ChainlinkAggregator memory agg0
) pure returns (IChainlinkRelayer.ChainlinkAggregator[] memory aggs) {
  aggs = new IChainlinkRelayer.ChainlinkAggregator[](1);
  aggs[0] = agg0;
}

function aggregators(
  IChainlinkRelayer.ChainlinkAggregator memory agg0,
  IChainlinkRelayer.ChainlinkAggregator memory agg1
) pure returns (IChainlinkRelayer.ChainlinkAggregator[] memory aggs) {
  aggs = new IChainlinkRelayer.ChainlinkAggregator[](2);
  aggs[0] = agg0;
  aggs[1] = agg1;
}

function aggregators(
  IChainlinkRelayer.ChainlinkAggregator memory agg0,
  IChainlinkRelayer.ChainlinkAggregator memory agg1,
  IChainlinkRelayer.ChainlinkAggregator memory agg2
) pure returns (IChainlinkRelayer.ChainlinkAggregator[] memory aggs) {
  aggs = new IChainlinkRelayer.ChainlinkAggregator[](3);
  aggs[0] = agg0;
  aggs[1] = agg1;
  aggs[2] = agg2;
}

function aggregators(
  IChainlinkRelayer.ChainlinkAggregator memory agg0,
  IChainlinkRelayer.ChainlinkAggregator memory agg1,
  IChainlinkRelayer.ChainlinkAggregator memory agg2,
  IChainlinkRelayer.ChainlinkAggregator memory agg3
) pure returns (IChainlinkRelayer.ChainlinkAggregator[] memory aggs) {
  aggs = new IChainlinkRelayer.ChainlinkAggregator[](4);
  aggs[0] = agg0;
  aggs[1] = agg1;
  aggs[2] = agg2;
  aggs[3] = agg3;
}
