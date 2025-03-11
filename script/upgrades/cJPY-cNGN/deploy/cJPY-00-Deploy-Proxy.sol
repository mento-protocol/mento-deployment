// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { StableTokenJPYProxy } from "mento-core-2.6.3/tokens/StableTokenJPYProxy.sol";

/*
  yarn deploy -n <network> -u cJPY-cNGN -s cJPY-00-Deploy-Proxy.sol
*/
contract cJPY_DeployProxy is Script {
  function run() public {
    address payable stableTokenJPYProxy;

    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenJPYProxy = address(new StableTokenJPYProxy());
      StableTokenJPYProxy(stableTokenJPYProxy)._transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenJPYProxy deployed at: ", stableTokenJPYProxy);
    console2.log("StableTokenJPYProxy(%s) ownership transferred to %s", stableTokenJPYProxy, governance);
    console2.log("----------");
  }
}
