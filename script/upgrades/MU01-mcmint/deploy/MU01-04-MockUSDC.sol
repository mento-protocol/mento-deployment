pragma solidity ^0.5.13;

import { Script } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { console2 } from "forge-std/Script.sol";

import { MockUSDC } from "contracts/MockUSDC.sol";

contract MU01_MockUSDC is Script {
  function run() public {
    address mockUSDC;

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      mockUSDC = address(new MockUSDC());
    }
    vm.stopBroadcast();

    console2.log("----------");
    console2.log("MockUSDC deployed at: ", mockUSDC);
    console2.log("----------");
  }
}
