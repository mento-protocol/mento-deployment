// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { StableTokenPSOProxy } from "mento-core-2.4.0/legacy/proxies/StableTokenPSOProxy.sol";

/*
 yarn deploy -n <network> -u PSO -s PSO-00-Create-Proxies.sol
*/
contract PSO_CreateProxies is Script {
  function run() public {
    address payable stableTokenPSOProxy;
    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenPSOProxy = address(new StableTokenPSOProxy());
      StableTokenPSOProxy(stableTokenPSOProxy)._transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenPSOProxy deployed at: ", stableTokenPSOProxy);
    console2.log("StableTokenPSOProxy(%s) ownership transferred to %s", stableTokenPSOProxy, governance);
    console2.log("----------");
  }
}
