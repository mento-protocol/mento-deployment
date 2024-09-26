// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { console } from "forge-std-next/console.sol";
import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";

interface IDistributor {
  function setClaimed(uint256 index, bool claimed) external;
}

/*
 * How to run:
 * env DISTRIBUTOR=0x... CLAIMER_INDEX=0x0 yarn script:dev -n celo -s ToggleTestingDistributorClaimed
 */
contract ToggleTestingDistributorClaimed is Script {
  function run() public {
    address distributor = vm.envAddress("DISTRIBUTOR");
    uint256 index = vm.envUint("CLAIMER_INDEX");

    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      IDistributor(distributor).setClaimed(index, false);
    }
    vm.stopBroadcast();
  }
}
