// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { ReserveProxy } from "mento-core-2.6.0/swap/ReserveProxy.sol";

/*
 yarn cgp:deploy -n <network> -u MU08 -s MU08-00-Create-Proxies.sol
*/

contract MU08_CreateProxies is Script {
  function run() public {
    address payable reserveProxy;
    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      reserveProxy = address(new ReserveProxy());
      ReserveProxy(reserveProxy)._transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("ReserveProxy deployed at: ", reserveProxy);
    console2.log("----------");
  }
}
