// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { StableTokenGBPProxy } from "mento-core-2.6.5/tokens/StableTokenGBPProxy.sol";
import { StableTokenAUDProxy } from "mento-core-2.6.5/tokens/StableTokenAUDProxy.sol";
import { StableTokenCADProxy } from "mento-core-2.6.5/tokens/StableTokenCADProxy.sol";
import { StableTokenCHFProxy } from "mento-core-2.6.5/tokens/StableTokenCHFProxy.sol";
import { StableTokenZARProxy } from "mento-core-2.6.5/tokens/StableTokenZARProxy.sol";

/*
  yarn cgp:deploy -n <network> -u FX00 -s FX00-00-Deploy-Proxys.sol
*/
contract FX00_DeployProxys is Script {
  function run() public {
    address payable stableTokenGBPProxy;
    address payable stableTokenAUDProxy;
    address payable stableTokenCADProxy;
    address payable stableTokenCHFProxy;
    address payable stableTokenZARProxy;

    address governance = contracts.celoRegistry("Governance");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenGBPProxy = address(new StableTokenGBPProxy());
      stableTokenAUDProxy = address(new StableTokenAUDProxy());
      stableTokenCADProxy = address(new StableTokenCADProxy());
      stableTokenCHFProxy = address(new StableTokenCHFProxy());
      stableTokenZARProxy = address(new StableTokenZARProxy());

      StableTokenGBPProxy(stableTokenGBPProxy)._transferOwnership(governance);
      StableTokenAUDProxy(stableTokenAUDProxy)._transferOwnership(governance);
      StableTokenCADProxy(stableTokenCADProxy)._transferOwnership(governance);
      StableTokenCHFProxy(stableTokenCHFProxy)._transferOwnership(governance);
      StableTokenZARProxy(stableTokenZARProxy)._transferOwnership(governance);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenGBPProxy deployed at: ", stableTokenGBPProxy);
    console2.log("StableTokenAUDProxy deployed at: ", stableTokenAUDProxy);
    console2.log("StableTokenCADProxy deployed at: ", stableTokenCADProxy);
    console2.log("StableTokenCHFProxy deployed at: ", stableTokenCHFProxy);
    console2.log("StableTokenZARProxy deployed at: ", stableTokenZARProxy);
    console2.log("----------");

    require(StableTokenGBPProxy(stableTokenGBPProxy)._getOwner() == governance, "GBP ownership transfer failed");
    require(StableTokenAUDProxy(stableTokenAUDProxy)._getOwner() == governance, "AUD ownership transfer failed");
    require(StableTokenCADProxy(stableTokenCADProxy)._getOwner() == governance, "CAD ownership transfer failed");
    require(StableTokenCHFProxy(stableTokenCHFProxy)._getOwner() == governance, "CHF ownership transfer failed");
    require(StableTokenZARProxy(stableTokenZARProxy)._getOwner() == governance, "ZAR ownership transfer failed");

    console2.log("✅ All ownership transfers verified successfully");
    console2.log("----------");
  }
}
