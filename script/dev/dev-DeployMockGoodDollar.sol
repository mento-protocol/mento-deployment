// // SPDX-License-Identifier: GPL-3.0-or-later
// pragma solidity ^0.5.13;

// import { Script } from "script/utils/Script.sol";
// import { Chain } from "script/utils/Chain.sol";
// import { console2 } from "forge-std/Script.sol";

// import { MockERC20 } from "contracts/MockERC20.sol";

// contract DeployMockGoodDollar is Script {
//   function run() public {
//     address mockGoodDollar;

//     vm.startBroadcast(Chain.deployerPrivateKey());
//     {
//       mockGoodDollar = address(new MockERC20("mock Good Dollar", "mG$", 18));
//     }
//     vm.stopBroadcast();

//     console2.log("----------");
//     console2.log("MockBridgedUSDC deployed at: ", mockBridgedUSDC);
//     console2.log("----------");
//   }
// }
