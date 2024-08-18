// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/v1/Script.sol";
import { Chain } from "script/utils/v1/Chain.sol";
import { console } from "forge-std/console.sol";

import { BreakerBoxProxy } from "mento-core-2.0.0/proxies/BreakerBoxProxy.sol";
import { BiPoolManagerProxy } from "mento-core-2.0.0/proxies/BiPoolManagerProxy.sol";
import { BrokerProxy } from "mento-core-2.0.0/proxies/BrokerProxy.sol";
import { PartialReserveProxy } from "contracts/PartialReserveProxy.sol";

/*
 yarn deploy -n <network> -u MU01 -s MU01-00-Create-Proxies.sol
*/
contract MU01_CreateProxies is Script {
  function run() public {
    address breakerBoxProxy;
    address biPoolManagerProxy;
    address brokerProxy;
    address partialReserveProxy;

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      breakerBoxProxy = address(new BreakerBoxProxy());
      biPoolManagerProxy = address(new BiPoolManagerProxy());
      brokerProxy = address(new BrokerProxy());
      partialReserveProxy = address(new PartialReserveProxy());
    }
    vm.stopBroadcast();

    console.log("----------");
    console.log("BrokerProxy deployed at: ", brokerProxy);
    console.log("BiPoolManagerProxy deployed at: ", biPoolManagerProxy);
    console.log("BreakerBoxProxy deployed at: ", breakerBoxProxy);
    console.log("PartialReserveProxy deployed at: ", partialReserveProxy);
    console.log("----------");
  }
}
