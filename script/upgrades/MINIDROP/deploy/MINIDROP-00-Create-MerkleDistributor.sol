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
    bytes32 merkleRootCUSD = readMerkleRoot();
    bytes32 merkleRootMENTO = readMerkleRoot();

    address cUSDDistributor;
    address mentoDistributor;

    vm.startBroadcast(vm.envUint("MENTO_DEPLOYER_PK"));

    {
      cUSDDistributor = deployMerkleDistributor("MerkleDistributor.sol", cUSD, merkleRootCUSD);
      console.log("MerkleDistributor for cUSD deployed at:", cUSDDistributor);
      mentoDistributor = deployMerkleDistributor("MerkleDistributor.sol", MENTO, merkleRootMENTO);
      console.log("MerkleDistributor for MENTO deployed at:", mentoDistributor);
    }

    vm.stopBroadcast();
  }

  function deployMerkleDistributor(string memory path, address token, bytes32 merkleRoot) private returns (address) {
    bytes memory bytecode = abi.encodePacked(vm.getCode(path), abi.encode(token, merkleRoot));
    address deployedAddress;
    assembly {
      deployedAddress := create(0, add(bytecode, 0x20), mload(bytecode))
    }
    return deployedAddress;
  }

  function readMerkleRoot() internal view returns (bytes32) {
    string memory network = ChainLib.rpcToken(); // celo | alfajores
    string memory root = vm.projectRoot();
    string memory path = string(abi.encodePacked(root, "/data/test.root.json"));
    string memory json = vm.readFile(path);
    return stdJson.readBytes32(json, ".root");
  }
}
