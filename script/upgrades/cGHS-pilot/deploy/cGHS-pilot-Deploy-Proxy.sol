// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { Arrays } from "script/utils/Arrays.sol";
import { console2 } from "forge-std/Script.sol";

import { StableTokenGHSProxy } from "mento-core-2.6.0/tokens/StableTokenGHSProxy.sol";
import { IStableTokenV2 } from "mento-core-2.5.0/interfaces/IStableTokenV2.sol";

/*
 yarn deploy -n <network> -u cGHS -s cGHS-00-Create-Proxies.sol
*/
contract cGHS_CreateProxies is Script {
  function run() public {
    contracts.load("MU04-00-Create-Implementations", "latest"); // First StableTokenV2 deployment
    StableTokenGHSProxy stableTokenGHSProxy;
    address governance = contracts.celoRegistry("Governance");
    address stableTokenV2 = contracts.deployed("StableTokenV2");
    address MPFLedger = 0x0aa27E23f2cf34d925B387FABEb1fD8ac605C8c5;
    uint256 MPFAllocation = 1_500_000 * 1e18;

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      stableTokenGHSProxy = new StableTokenGHSProxy();
      stableTokenGHSProxy._setAndInitializeImplementation(
        stableTokenV2,
        abi.encodeWithSelector(
          IStableTokenV2(0).initialize.selector,
          "cGHS (pilot)",
          "cGHS",
          0,
          address(0),
          0,
          0,
          Arrays.addresses(MPFLedger),
          Arrays.uints(MPFAllocation),
          ""
        )
      );
      IStableTokenV2(address(stableTokenGHSProxy)).initializeV2(MPFLedger, address(0), address(0));
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("StableTokenGHSProxy deployed and configured at: ", address(stableTokenGHSProxy));
    console2.log("----------");
  }
}
