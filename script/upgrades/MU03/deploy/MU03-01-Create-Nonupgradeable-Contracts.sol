// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { BreakerBox } from "2.2.0/contracts/oracles/BreakerBox.sol";
import { ISortedOracles } from "2.2.0/contracts/interfaces/ISortedOracles.sol";

/*
 forge script MU02_DeployBreakerBox --rpc-url $RPC_URL
                             --broadcast --legacy 
                             --verify --verifier sourcify 
*/
contract MU03_CreateNonupgradeableContracts is Script {
  BreakerBox private breakerBox;

  function run() public {
    vm.startBroadcast(Chain.deployerPrivateKey());
    address[] memory __rateFeedIDs = new address[](0);
    address governance = contracts.celoRegistry("Governance");
    address sortedOracles = contracts.celoRegistry("SortedOracles");

    {
      breakerBox = new BreakerBox(__rateFeedIDs, ISortedOracles(sortedOracles));
      BreakerBox(breakerBox).transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("BreakerBox deployed at: ", address(breakerBox));
    console2.log("BreakerBox(%s) ownership transferred to %s", address(breakerBox), governance);
    console2.log("----------");
  }
}