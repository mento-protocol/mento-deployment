// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { BreakerBoxProxy } from "mento-core/contracts/proxies/BreakerBoxProxy.sol";
import { BiPoolManagerProxy } from "mento-core/contracts/proxies/BiPoolManagerProxy.sol";
import { BrokerProxy } from "mento-core/contracts/proxies/BrokerProxy.sol";
import { MedianDeltaBreaker } from "mento-core/contracts/MedianDeltaBreaker.sol";


/*
 forge script MU01CreateImplementations --rpc-url $RPC_URL
                             --broadcast --legacy 
                             --verify --verifier sourcify 
*/
contract MU01_GovernanceOwnershipTransfer is Script {
  function run() public {
    contracts.load("MU01-00-Create-Proxies", "1674224277");
    contracts.load("MU01-01-Create-Nonupgradable-Contracts", "1674224321");
    address payable breakerBoxProxy = address(uint160(contracts.deployed("BreakerBoxProxy")));
    address payable biPoolManagerProxy = address(uint160(contracts.deployed("BiPoolManagerProxy")));
    address payable brokerProxy = address(uint160(contracts.deployed("BrokerProxy")));
    address payable medianDeltaBreaker = address(uint160(contracts.deployed("MedianDeltaBreaker")));
    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      BreakerBoxProxy(breakerBoxProxy)._transferOwnership(governance);
      BiPoolManagerProxy(biPoolManagerProxy)._transferOwnership(governance);
      BrokerProxy(brokerProxy)._transferOwnership(governance);
      MedianDeltaBreaker(medianDeltaBreaker).transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("BrokerProxy(%s) ownership transferred to %s", brokerProxy, governance);
    console2.log("BiPoolManagerProxy(%s) ownership transferred to %s", biPoolManagerProxy, governance);
    console2.log("BreakerBoxProxy(%s) ownership transferred to %s", breakerBoxProxy, governance);
    console2.log("MedianDeltaBreaker(%s) ownership transferred to %s", medianDeltaBreaker, governance);
    console2.log("----------");
  }
}
