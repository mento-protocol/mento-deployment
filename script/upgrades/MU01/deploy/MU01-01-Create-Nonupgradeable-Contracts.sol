// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { console2 } from "forge-std/Script.sol";
import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";

import { ConstantSumPricingModule } from "mento-core/contracts/ConstantSumPricingModule.sol";
import { ConstantProductPricingModule } from "mento-core/contracts/ConstantProductPricingModule.sol";
import { MedianDeltaBreaker } from "mento-core/contracts/MedianDeltaBreaker.sol";
import { ValueDeltaBreaker } from "mento-core/contracts/ValueDeltaBreaker.sol";
import { ISortedOracles } from "mento-core/contracts/interfaces/ISortedOracles.sol";

/*
 forge script MU01_CreateNonupgradeableContracts --rpc-url $RPC_URL
                             --broadcast --legacy 
                             --verify --verifier sourcify 
*/
contract MU01_CreateNonupgradeableContracts is Script {
  ConstantSumPricingModule private csPricingModule;
  ConstantProductPricingModule private cpPricingModule;
  MedianDeltaBreaker private medianDeltaBreaker;
  ValueDeltaBreaker private valueDeltaBreaker;

  function run() public {
    //TODO: We need to get the correct values for these
    uint256 medianDeltaBreakerCooldown = 0;
    uint256 medianDeltaBreakerThreshold = 0;

    uint256 valueDeltaBreakerCooldown = 0;
    uint256 valueDeltaBreakerThreshold = 0;

    address sortedOracles = contracts.celoRegistry("SortedOracles");

    address[] memory __rateFeedIDs = new address[](0);
    uint256[] memory __rateChangeThresholds = new uint256[](0);
    uint256[] memory __cooldowns = new uint256[](0);

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      csPricingModule = new ConstantSumPricingModule();
      cpPricingModule = new ConstantProductPricingModule();

      medianDeltaBreaker = new MedianDeltaBreaker(
        medianDeltaBreakerCooldown,
        medianDeltaBreakerThreshold,
        ISortedOracles(sortedOracles),
        __rateFeedIDs,
        __rateChangeThresholds,
        __cooldowns
      );

      valueDeltaBreaker = new ValueDeltaBreaker(
        valueDeltaBreakerCooldown,
        valueDeltaBreakerThreshold,
        ISortedOracles(sortedOracles),
        __rateFeedIDs,
        __rateChangeThresholds,
        __cooldowns
      );
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("Constant sum pricing module deployed at: ", address(csPricingModule));
    console2.log("Constant product pricing module deployed at: ", address(cpPricingModule));
    console2.log("MedianDeltaBreaker deployed at", address(medianDeltaBreaker));
    console2.log("ValueDeltaBreaker deployed at", address(valueDeltaBreaker));
    console2.log("----------");
  }
}
