// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { console } from "forge-std/console.sol";
import { Script } from "script/utils/Script.sol";
import { Chain as ChainLib } from "script/utils/Chain.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { IRegistry } from "../../../interfaces/IRegistry.sol";
import { Contracts } from "../../../utils/Contracts.sol";
import { IGovernanceFactory } from "../../../interfaces/IGovernanceFactory.sol";
import { stdJson } from "forge-std/StdJson.sol";

contract MINIDROP_CreateMerkleDistributor is Script {
  using Contracts for Contracts.Cache;

  function run() public {
    contracts.load("MUGOV-00-Create-Factory", "latest");
    IRegistry registry = IRegistry(0x000000000000000000000000000000000000ce10);
    address cUSD = registry.getAddressForStringOrDie("StableToken");
    address MENTO = IGovernanceFactory(contracts.deployed("GovernanceFactory")).mentoToken();

    // 91 days after the current block timestamp roughly 3 months
    uint256 endTime = block.timestamp + 91 days;

    bytes32 merkleRootCUSD = readMerkleRoot(".cUSDRoot");
    bytes32 merkleRootMENTO = readMerkleRoot(".mentoRoot");

    address cUSDDistributor;
    address mentoDistributor;

    vm.startBroadcast(vm.envUint("MENTO_DEPLOYER_PK"));
    {
      cUSDDistributor = deployMerkleDistributor(
        "out/MerkleDistributorWithDeadline.sol/MerkleDistributorWithDeadline.json",
        cUSD,
        merkleRootCUSD,
        endTime
      );
      console.log("MerkleDistributor for cUSD deployed at:", cUSDDistributor);
      mentoDistributor = deployMerkleDistributor(
        "out/MerkleDistributorWithDeadline.sol/MerkleDistributorWithDeadline.json",
        MENTO,
        merkleRootMENTO,
        endTime
      );
      console.log("MerkleDistributor for MENTO deployed at:", mentoDistributor);
    }

    vm.stopBroadcast();
  }

  function deployMerkleDistributor(
    string memory path,
    address token,
    bytes32 merkleRoot,
    uint256 endTime
  ) private returns (address) {
    bytes memory bytecode = abi.encodePacked(vm.getCode(path), abi.encode(token, merkleRoot, endTime));
    address deployedAddress;
    assembly {
      deployedAddress := create(0, add(bytecode, 0x20), mload(bytecode))
    }
    return deployedAddress;
  }

  function readMerkleRoot(string memory token) internal view returns (bytes32) {
    string memory network = ChainLib.rpcToken(); // celo | alfajores
    string memory root = vm.projectRoot();
    string memory path = string(abi.encodePacked(root, "/script/upgrades/MINIDROP/data/", network, ".root.json"));
    string memory json = vm.readFile(path);
    return stdJson.readBytes32(json, token);
  }
}
