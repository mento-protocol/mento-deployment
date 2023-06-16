// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { console2 } from "forge-std/Script.sol";
import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";

import { MedianDeltaBreaker } from "mento-core/contracts/MedianDeltaBreaker.sol";
import { ISortedOracles } from "mento-core/contracts/interfaces/ISortedOracles.sol";

/*
 forge script MU01_Phase2_DeployMedianDeltaBreaker --rpc-url $RPC_URL
                             --broadcast --legacy
                             --verify --verifier sourcify
*/
contract MU02_DeployMedianDeltaBreaker is Script {
  MedianDeltaBreaker private medianDeltaBreaker;

  function run() public {
    uint256 medianDeltaBreakerCooldown = 0;
    uint256 medianDeltaBreakerThreshold = 0;

    address governance = contracts.celoRegistry("Governance");
    address sortedOracles = contracts.celoRegistry("SortedOracles");

    address[] memory __rateFeedIDs = new address[](0);
    uint256[] memory __rateChangeThresholds = new uint256[](0);
    uint256[] memory __cooldowns = new uint256[](0);

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      medianDeltaBreaker = new MedianDeltaBreaker(
        medianDeltaBreakerCooldown,
        medianDeltaBreakerThreshold,
        ISortedOracles(sortedOracles),
        __rateFeedIDs,
        __rateChangeThresholds,
        __cooldowns
      );
      medianDeltaBreaker.transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("MedianDeltaBreaker deployed at", address(medianDeltaBreaker));
    console2.log("MedianDeltaBreaker(%s) ownership transferred to %s", address(medianDeltaBreaker), governance);
    console2.log("----------");
  }
}
