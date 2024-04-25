// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

// TODO: Update ref to latest mento-core and import StableTokenCOP
import { StableTokenCOPProxy } from "mento-core-copkes/legacy/proxies/StableTokenCOPProxy.sol";

/*
 yarn deploy -n <network> -u cCOP -s cCOP-00-Create-Proxies.sol
*/
contract eXOF_CreateProxies is Script {
  function run() public {
    address payable stableTokenCOPProxy;
    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenCOPProxy = address(new StableTokenCOPProxy());
      StableTokenCOPProxy(stableTokenCOPProxy)._transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenCOPProxy deployed at: ", stableTokenCOPProxy);
    console2.log("StableTokenCOPProxy(%s) ownership transferred to %s", stableTokenCOPProxy, governance);
    console2.log("----------");
  }
}
