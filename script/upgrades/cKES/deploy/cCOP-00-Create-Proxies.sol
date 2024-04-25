// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

// TODO: Update ref to latest mento-core and import StableTokenKES
import { StableTokenXOFProxy as StableTokenKESProxy } from "mento-core-2.2.0/legacy/proxies/StableTokenXOFProxy.sol";

/*
 yarn deploy -n <network> -u cKES -s cKES-00-Create-Proxies.sol
*/
contract eXOF_CreateProxies is Script {
  function run() public {
    address payable stableTokenKESProxy;
    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenKESProxy = address(new StableTokenKESProxy());
      StableTokenKESProxy(stableTokenKESProxy)._transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenKESProxy deployed at: ", stableTokenKESProxy);
    console2.log("StableTokenKESProxy(%s) ownership transferred to %s", stableTokenKESProxy, governance);
    console2.log("----------");
  }
}