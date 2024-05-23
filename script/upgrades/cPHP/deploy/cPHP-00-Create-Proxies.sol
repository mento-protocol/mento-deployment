// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { StableTokenPHPProxy } from "mento-core-2.4.0/legacy/proxies/StableTokenPHPProxy.sol";

/*
 yarn deploy -n <network> -u cPHP -s cPHP-00-Create-Proxies.sol
*/
contract cPHP_CreateProxies is Script {
  function run() public {
    address payable stableTokenPHPProxy;
    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenPHPProxy = address(new StableTokenPHPProxy());
      StableTokenPHPProxy(stableTokenPHPProxy)._transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenPHPProxy deployed at: ", stableTokenPHPProxy);
    console2.log("StableTokenPHPProxy(%s) ownership transferred to %s", stableTokenPHPProxy, governance);
    console2.log("----------");
  }
}
