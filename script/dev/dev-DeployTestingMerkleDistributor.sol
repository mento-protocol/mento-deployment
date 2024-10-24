// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.17;

import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { TestingMerkleDistributor } from "contracts/TestingMerkleDistributor.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DeployTestingMerkleDistributor is Script {
  using SafeERC20 for IERC20;
  using Contracts for Contracts.Cache;
  bytes32 constant MERKLE_ROOT = 0xdd716a6e66a6279db2380d092d09dc3e4a9da808ef777d545e16e43d9bed1036;

  function run() public {
    address token = contracts.celoRegistry("StableToken");
    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      address distributor = address(new TestingMerkleDistributor(token, MERKLE_ROOT, block.timestamp + 1 weeks));
      IERC20(token).safeTransfer(distributor, 1e16);
    }
    vm.stopBroadcast();
  }
}
