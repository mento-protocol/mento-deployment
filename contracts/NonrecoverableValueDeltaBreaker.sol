// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
import { ISortedOracles } from "mento-core-2.2.0/interfaces/ISortedOracles.sol";
import { ValueDeltaBreaker } from "mento-core-2.2.0/oracles/breakers/ValueDeltaBreaker.sol";

contract NonrecoverableValueDeltaBreaker is ValueDeltaBreaker {
  constructor(
    uint256 _defaultCooldownTime,
    uint256 _defaultRateChangeThreshold,
    ISortedOracles _sortedOracles,
    address[] memory rateFeedIDs,
    uint256[] memory rateChangeThresholds,
    uint256[] memory cooldownTimes
  )
    public
    ValueDeltaBreaker(
      _defaultCooldownTime,
      _defaultRateChangeThreshold,
      _sortedOracles,
      rateFeedIDs,
      rateChangeThresholds,
      cooldownTimes
    )
  {}
}
