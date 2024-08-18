// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/v1/Script.sol";
import { Chain } from "script/utils/v1/Chain.sol";
import { console } from "forge-std/console.sol";

import { StableTokenCOPProxy } from "mento-core-2.3.1/legacy/proxies/StableTokenCOPProxy.sol";

/*
 yarn deploy -n <network> -u cCOP -s cCOP-00-Create-Proxies.sol
*/
contract cCOP_CreateProxies is Script {
  function run() public {
    address payable stableTokenCOPProxy;
    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenCOPProxy = address(new StableTokenCOPProxy());
      StableTokenCOPProxy(stableTokenCOPProxy)._transferOwnership(governance);
    }
    vm.stopBroadcast();

    console.log("----------");
    console.log("StableTokenCOPProxy deployed at: ", stableTokenCOPProxy);
    console.log("StableTokenCOPProxy(%s) ownership transferred to %s", stableTokenCOPProxy, governance);
    console.log("----------");
  }
}
