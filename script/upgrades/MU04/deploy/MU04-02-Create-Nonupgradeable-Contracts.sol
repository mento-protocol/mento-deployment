// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { ISortedOracles } from "mento-core-2.2.0/interfaces/ISortedOracles.sol";
import { NonrecoverableValueDeltaBreaker } from "contracts/NonrecoverableValueDeltaBreaker.sol";

/*
 yarn deploy -n <network> -u MU04 -s MU04-02-Create-Nonupgradeable-Contracts.sol
*/
contract MU04_CreateNonupgradeableContracts is Script {
  NonrecoverableValueDeltaBreaker private nonrecoverableValueDeltaBreaker;

  function run() public {
    address governance = contracts.celoRegistry("Governance");
    address sortedOracles = contracts.celoRegistry("SortedOracles");

    uint256 _defaultCooldown = 0;
    uint256 _defaultThreshold = 0;

    address[] memory __rateFeedIDs = new address[](0);
    uint256[] memory __rateChangeThresholds = new uint256[](0);
    uint256[] memory __cooldowns = new uint256[](0);

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      nonrecoverableValueDeltaBreaker = new NonrecoverableValueDeltaBreaker(
        _defaultCooldown,
        _defaultThreshold,
        ISortedOracles(sortedOracles),
        __rateFeedIDs,
        __rateChangeThresholds,
        __cooldowns
      );
      nonrecoverableValueDeltaBreaker.transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("ValueDeltaBreaker2 deployed at: ", address(nonrecoverableValueDeltaBreaker));
    console2.log(
      "ValueDeltaBreaker2(%s) ownership transferred to %s",
      address(nonrecoverableValueDeltaBreaker),
      governance
    );
    console2.log("----------");
  }
}
