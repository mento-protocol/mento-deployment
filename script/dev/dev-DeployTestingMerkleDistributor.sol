// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.17;

import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { TestingMerkleDistributor } from "contracts/TestingMerkleDistributor.sol";

contract DeployTestingMerkleDistributor is Script {
  using Contracts for Contracts.Cache;
  bytes32 constant MERKLE_ROOT = 0xc8148553672963b66a8972e21bff370b4c8dba9ce7f108282edf784c76875a43;

  function run() public {
    address token = contracts.celoRegistry("StableToken");
    vm.startBroadcast(ChainLib.deployerPrivateKey());
    {
      new TestingMerkleDistributor(token, MERKLE_ROOT, block.timestamp + 1 weeks);
    }
    vm.stopBroadcast();
  }
}
