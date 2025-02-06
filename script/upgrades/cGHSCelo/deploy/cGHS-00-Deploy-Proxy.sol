// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";
import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

import { StableTokenGHSProxy } from "mento-core-2.6.0/tokens/StableTokenGHSProxy.sol";

/*
 yarn deploy -n <network> -u cGHS -s cGHS-00-Deploy-Proxy.sol
*/
contract cGHS_DeployProxy is Script {
  function run() public {
    address payable stableTokenGHSProxy;

    address governanceFactory = contracts.deployed("GovernanceFactory");
    address timelockProxy = IGovernanceFactory(governanceFactory).governanceTimelock();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenGHSProxy = address(new StableTokenGHSProxy());
      StableTokenGHSProxy(stableTokenGHSProxy)._transferOwnership(timelockProxy);
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenGHSProxy deployed at: ", stableTokenGHSProxy);
    console2.log("StableTokenGHSProxy(%s) ownership transferred to %s", stableTokenGHSProxy, timelockProxy);
    console2.log("----------");
  }
}
