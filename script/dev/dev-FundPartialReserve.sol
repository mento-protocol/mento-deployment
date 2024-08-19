// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/v1/Script.sol";
import { Chain } from "script/utils/v1/Chain.sol";
import { console } from "forge-std/console.sol";

import { IERC20Metadata } from "mento-core-2.0.0/common/interfaces/IERC20Metadata.sol";

contract FundPartialReserve is Script {
  function run() public {
    contracts.loadUpgrade("MU01");
    IERC20Metadata bridgedUSDC = IERC20Metadata(contracts.dependency("BridgedUSDC"));
    IERC20Metadata bridgedEUROC = IERC20Metadata(contracts.dependency("BridgedEUROC"));
    address partialReserve = contracts.deployed("PartialReserveProxy");
    IERC20Metadata celoToken = IERC20Metadata(contracts.celoRegistry("GoldToken"));

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      bridgedUSDC.transfer(partialReserve, 10_000_000 * 1e6);
      bridgedEUROC.transfer(partialReserve, 10_000_000 * 1e6);
      celoToken.transfer(partialReserve, 10_000 ether);
    }
    vm.stopBroadcast();
  }
}
