// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { ISortedOracles } from "mento-core-2.2.0/interfaces/ISortedOracles.sol";
import { MedianDeltaBreaker } from "mento-core-2.2.0/oracles/breakers/MedianDeltaBreaker.sol";
import { BreakerBox } from "mento-core-2.2.0/oracles/BreakerBox.sol";
import { ConstantSumPricingModule } from "mento-core-2.2.0/swap/ConstantSumPricingModule.sol";

/*
 yarn deploy -n <network> -u MU03 -s MU03-01-Create-Nonupgradeable-Contracts.sol
*/
contract MU03_CreateNonupgradeableContracts is Script {
  BreakerBox private breakerBox;
  MedianDeltaBreaker private medianDeltaBreaker;
  ConstantSumPricingModule private constantSumPriceModule;

  function run() public {
    address governance = contracts.celoRegistry("Governance");
    address sortedOracles = contracts.celoRegistry("SortedOracles");

    uint256 medianDeltaBreakerCooldown = 0;
    uint256 medianDeltaBreakerThreshold = 0;

    address[] memory __rateFeedIDs = new address[](0);
    uint256[] memory __rateChangeThresholds = new uint256[](0);
    uint256[] memory __cooldowns = new uint256[](0);

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      breakerBox = new BreakerBox(__rateFeedIDs, ISortedOracles(sortedOracles));
      BreakerBox(breakerBox).transferOwnership(governance);

      medianDeltaBreaker = new MedianDeltaBreaker(
        medianDeltaBreakerCooldown,
        medianDeltaBreakerThreshold,
        ISortedOracles(sortedOracles),
        address(breakerBox),
        __rateFeedIDs,
        __rateChangeThresholds,
        __cooldowns
      );
      medianDeltaBreaker.transferOwnership(governance);

      constantSumPriceModule = new ConstantSumPricingModule();
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("BreakerBox deployed at: ", address(breakerBox));
    console2.log("BreakerBox(%s) ownership transferred to %s", address(breakerBox), governance);
    console2.log("MedianDeltaBreaker deployed at: ", address(medianDeltaBreaker));
    console2.log("MedianDeltaBreaker(%s) ownership transferred to %s", address(medianDeltaBreaker), governance);
    console2.log("ConstantSumPricingModule(%s) deployed at %s", address(constantSumPriceModule));
    console2.log("----------");
  }
}
