// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { ISortedOracles } from "mento-core/contracts/interfaces/ISortedOracles.sol";

import { MedianDeltaBreaker } from "mento-core/contracts/MedianDeltaBreaker.sol";
import { BreakerBox } from "mento-core/contracts/BreakerBox.sol";
import { BreakerBoxProxy } from "mento-core/contracts/proxies/BreakerBoxProxy.sol";

/*
 Baklava: 
 forge script DeployCircuitBreaker --rpc-url $BAKLAVA_RPC_URL 
                     --broadcast --legacy --verify --verifier sourcify 
                     --private-key $BAKLAVA_DEPLOYER_PK
*/

contract DeployCircuitBreaker is Script {
  MedianDeltaBreaker private medianDeltaBreaker;
  BreakerBox private breakerBox;
  BreakerBoxProxy private breakerBoxProxy;

  function run() public {
    address[] memory rateFeedIDs = new address[](2);
    rateFeedIDs[0] = contracts.celoRegistry("StableToken");
    rateFeedIDs[1] = contracts.celoRegistry("StableTokenEUR");
    // rateFeedIDs[1] = contracts.celoRegistry("StableTokenBRL");
    address governance = contracts.celoRegistry("Governance");
    address sortedOracles = contracts.celoRegistry("SortedOracles");

    address[] memory __rateFeedIDs = new address[](0);
    uint256[] memory __rateChangeThresholds = new uint256[](0);
    uint256[] memory __cooldowns = new uint256[](0);

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      medianDeltaBreaker = new MedianDeltaBreaker(
        0,
        0,
        ISortedOracles(sortedOracles),
        __rateFeedIDs,
        __rateChangeThresholds,
        __cooldowns
      );
      medianDeltaBreaker.transferOwnership(governance);

      breakerBox = new BreakerBox(false);
      breakerBoxProxy = new BreakerBoxProxy();
      breakerBoxProxy._setAndInitializeImplementation(
        address(breakerBox),
        abi.encodeWithSelector(
          BreakerBox(address(breakerBoxProxy)).initialize.selector,
          rateFeedIDs,
          ISortedOracles(sortedOracles)
        )
      );
      breakerBoxProxy._transferOwnership(governance);
      BreakerBox(address(breakerBoxProxy)).transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("BreakerBox deployed at: ", address(breakerBox));
    console2.log("BreakerBoxProxy deployed at: ", address(breakerBoxProxy));
    console2.log("Transferred BreakerBox proxy & implementation ownership to ", address(governance));
    console2.log("----------");
    console2.log("MedianDeltaBreaker deployed at", address(medianDeltaBreaker));
    console2.log("Transferred MedianDeltaBreaker ownership to ", address(governance));
    console2.log("----------");
  }
}
