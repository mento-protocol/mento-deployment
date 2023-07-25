// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { StableTokenXOFProxy } from "mento-core-2.2.0/legacy/proxies/StableTokenXOFProxy.sol";

/*
 yarn deploy -n <network> -u MU04 -s MU04-00-Create-Proxies.sol
*/
contract MU04_CreateProxies is Script {
  function run() public {
    address stableTokenXOFProxy;

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenXOFProxy = address(new StableTokenXOFProxy());
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenXOFProxy deployed at: ", stableTokenXOFProxy);
    console2.log("----------");
  }
}
