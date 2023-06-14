// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

// import { BreakerBoxProxy } from "mento-core/contracts/proxies/BreakerBoxProxy.sol";
import { BiPoolManagerProxy } from "mento-core/contracts/proxies/BiPoolManagerProxy.sol";
import { BrokerProxy } from "mento-core/contracts/proxies/BrokerProxy.sol";
import { PartialReserveProxy } from "contracts/PartialReserveProxy.sol";

/*
 forge script MU01_CreateProxies --rpc-url $RPC_URL
                             --broadcast --legacy 
                             --verify --verifier sourcify 
*/
contract MU01_CreateProxies is Script {
  function run() public {
    address breakerBoxProxy;
    address biPoolManagerProxy;
    address brokerProxy;
    address partialReserveProxy;

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      // breakerBoxProxy = address(new BreakerBoxProxy());
      biPoolManagerProxy = address(new BiPoolManagerProxy());
      brokerProxy = address(new BrokerProxy());
      partialReserveProxy = address(new PartialReserveProxy());
    }
    vm.stopBroadcast();

    console2.log("----------");
    // console2.log("BrokerProxy deployed at: ", brokerProxy);
    console2.log("BiPoolManagerProxy deployed at: ", biPoolManagerProxy);
    console2.log("BreakerBoxProxy deployed at: ", breakerBoxProxy);
    console2.log("PartialReserveProxy deployed at: ", partialReserveProxy);
    console2.log("----------");
  }
}
