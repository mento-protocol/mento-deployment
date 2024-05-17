// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { StableTokenINRProxy } from "mento-core-2.4.0/legacy/proxies/StableTokenINRProxy.sol";

/*
 yarn deploy -n <network> -u cINR -s cINR-00-Create-Proxies.sol
*/
contract cINR_CreateProxies is Script {
  function run() public {
    address payable stableTokenINRProxy;
    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenINRProxy = address(new StableTokenINRProxy());
      StableTokenINRProxy(stableTokenINRProxy)._transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenINRProxy deployed at: ", stableTokenINRProxy);
    console2.log("StableTokenINRProxy(%s) ownership transferred to %s", stableTokenINRProxy, governance);
    console2.log("----------");
  }
}
