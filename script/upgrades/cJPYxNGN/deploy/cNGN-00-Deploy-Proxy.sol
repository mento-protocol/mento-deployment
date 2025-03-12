// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { StableTokenNGNProxy } from "mento-core-2.6.3/tokens/StableTokenNGNProxy.sol";

/*
 yarn cgp:deploy -n <network> -u cJPYxNGN -s cNGN-00-Deploy-Proxy.sol
*/
contract cNGN_DeployProxy is Script {
  function run() public {
    address payable stableTokenNGNProxy;

    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenNGNProxy = address(new StableTokenNGNProxy());
      StableTokenNGNProxy(stableTokenNGNProxy)._transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenNGNProxy deployed at: ", stableTokenNGNProxy);
    console2.log("StableTokenNGNProxy(%s) ownership transferred to %s", stableTokenNGNProxy, governance);
    console2.log("----------");
  }
}
