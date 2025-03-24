// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { StableTokenAUDProxy } from "mento-core-2.6.5/tokens/StableTokenAUDProxy.sol";
import { StableTokenGBPProxy } from "mento-core-2.6.5/tokens/StableTokenGBPProxy.sol";
import { StableTokenZARProxy } from "mento-core-2.6.5/tokens/StableTokenZARProxy.sol";
import { StableTokenCADProxy } from "mento-core-2.6.5/tokens/StableTokenCADProxy.sol";

/*
 yarn cgp:deploy -n <network> -u FX01-CreateProxies -s FX01-Create-Proxies.sol
*/
contract FX01_CreateProxies is Script {
  function run() public {
    address payable stableTokenAUDProxy;
    address payable stableTokenGBPProxy;
    address payable stableTokenZARProxy;
    address payable stableTokenCADProxy;

    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenAUDProxy = address(new StableTokenAUDProxy());
      StableTokenAUDProxy(stableTokenAUDProxy)._transferOwnership(governance);

      stableTokenGBPProxy = address(new StableTokenGBPProxy());
      StableTokenGBPProxy(stableTokenGBPProxy)._transferOwnership(governance);

      stableTokenZARProxy = address(new StableTokenZARProxy());
      StableTokenZARProxy(stableTokenZARProxy)._transferOwnership(governance);

      stableTokenCADProxy = address(new StableTokenCADProxy());
      StableTokenCADProxy(stableTokenCADProxy)._transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenAUDProxy deployed at: ", stableTokenAUDProxy);
    console2.log("StableTokenAUDProxy(%s) ownership transferred to %s", stableTokenAUDProxy, governance);
    console2.log("");
    console2.log("StableTokenGBPProxy deployed at: ", stableTokenGBPProxy);
    console2.log("StableTokenGBPProxy(%s) ownership transferred to %s", stableTokenGBPProxy, governance);
    console2.log("");
    console2.log("StableTokenZARProxy deployed at: ", stableTokenZARProxy);
    console2.log("StableTokenZARProxy(%s) ownership transferred to %s", stableTokenZARProxy, governance);
    console2.log("");
    console2.log("StableTokenCADProxy deployed at: ", stableTokenCADProxy);
    console2.log("StableTokenCADProxy(%s) ownership transferred to %s", stableTokenCADProxy, governance);
    console2.log("----------");
  }
}
