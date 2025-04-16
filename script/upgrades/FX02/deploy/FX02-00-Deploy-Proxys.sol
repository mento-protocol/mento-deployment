// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { StableTokenJPYProxy } from "mento-core-2.6.5/tokens/StableTokenJPYProxy.sol";
import { StableTokenNGNProxy } from "mento-core-2.6.5/tokens/StableTokenNGNProxy.sol";

/*
  yarn cgp:deploy -n <network> -u FX02 -s FX02-00-Deploy-Proxys.sol
*/
contract FX02_DeployProxys is Script {
  function run() public {
    address payable stableTokenJPYProxy;
    address payable stableTokenNGNProxy;

    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenJPYProxy = address(new StableTokenJPYProxy());
      stableTokenNGNProxy = address(new StableTokenNGNProxy());

      StableTokenJPYProxy(stableTokenJPYProxy)._transferOwnership(governance);
      StableTokenNGNProxy(stableTokenNGNProxy)._transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenJPYProxy deployed at: ", stableTokenJPYProxy);
    console2.log("StableTokenNGNProxy deployed at: ", stableTokenNGNProxy);
    console2.log("----------");

    require(StableTokenJPYProxy(stableTokenJPYProxy)._getOwner() == governance, "JPY ownership transfer failed");
    require(StableTokenNGNProxy(stableTokenNGNProxy)._getOwner() == governance, "NGN ownership transfer failed");

    console2.log("✅ All ownership transfers verified successfully");
    console2.log("----------");
  }
}
