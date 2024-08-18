// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Script } from "script/utils/v1/Script.sol";
import { Chain } from "script/utils/v1/Chain.sol";
import { console } from "forge-std/console.sol";

import { IERC20Metadata } from "mento-core-2.0.0/common/interfaces/IERC20Metadata.sol";
import { IReserve } from "mento-core-2.0.0/interfaces/IReserve.sol";

contract DrainPartialReserve is Script {
  // TODO: Change this when running
  address private constant oldPartialReserveAddress = 0xAC7cf1c3c13C91b5fCE10090CE0D518853BC49C2;

  function run() public {
    contracts.loadUpgrade("MU01");
    IReserve oldPartialReserve = IReserve(oldPartialReserveAddress);
    IERC20Metadata celoToken = IERC20Metadata(contracts.celoRegistry("GoldToken"));
    IERC20Metadata bridgedUSDC = IERC20Metadata(contracts.dependency("BridgedUSDC"));
    address payable newPartialReserve = contracts.deployed("PartialReserveProxy");

    uint256 celoBalance = celoToken.balanceOf(oldPartialReserveAddress);
    uint256 bridgedUSDCBalance = bridgedUSDC.balanceOf(oldPartialReserveAddress);

    console.log("Reserve Address %s", oldPartialReserveAddress);
    console.log("Reserve Celo balance: %d", celoBalance);
    console.log("Reserve BridgedUSDC balance: %d", bridgedUSDCBalance);
    require(celoBalance > 0 || bridgedUSDCBalance > 0, "Reserve has no funds");

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      if (celoBalance > 0) {
        oldPartialReserve.transferCollateralAsset(address(celoToken), newPartialReserve, celoBalance);
      }
      if (bridgedUSDCBalance > 0) {
        oldPartialReserve.transferCollateralAsset(address(bridgedUSDC), newPartialReserve, bridgedUSDCBalance);
      }
    }
    vm.stopBroadcast();
  }
}
