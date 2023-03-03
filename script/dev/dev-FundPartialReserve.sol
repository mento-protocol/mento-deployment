// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { IERC20Metadata } from "mento-core/contracts/common/interfaces/IERC20Metadata.sol";

contract FundPartialReserve is Script {
  function run() public {
    contracts.loadUpgrade("MU01");
    IERC20Metadata bridgedUSDC = IERC20Metadata(contracts.dependency("BridgedUSDC"));
    address partialReserve = contracts.dependency("PartialReserveProxy");
    IERC20Metadata celoToken = IERC20Metadata(contracts.dependency("GoldToken"));

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      bridgedUSDC.transfer(partialReserve, 100_000 ether);
      celoToken.transfer(partialReserve, 100_000 ether);
    }
    vm.stopBroadcast();
  }
}
