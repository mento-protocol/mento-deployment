// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import { console } from "forge-std-next/console.sol";
import { stdJson } from "forge-std-next/StdJson.sol";

import { Script } from "script/utils/mento/Script.sol";
import { Chain as ChainLib } from "script/utils/mento/Chain.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";

import { IRegistry } from "script/interfaces/IRegistry.sol";
import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";

import { MerkleDistributorWithDeadline } from "merkle-distributor/MerkleDistributorWithDeadline.sol";

contract MINIDROP_CreateMerkleDistributor is Script {
  using Contracts for Contracts.Cache;

  function run() public {
    contracts.load("MUGOV-00-Create-Factory", "latest");
    IRegistry registry = IRegistry(0x000000000000000000000000000000000000ce10);
    address cUSD = registry.getAddressForStringOrDie("StableToken");
    address MENTO = IGovernanceFactory(contracts.deployed("GovernanceFactory")).mentoToken();
    address mentoLabsMultisig = contracts.dependency("MentoLabsMultisig");

    bytes32 merkleRootCUSD = readMerkleRoot("cUSD");
    bytes32 merkleRootMENTO = readMerkleRoot("MENTO");

    address cUSDDistributor;
    address mentoDistributor;

    vm.startBroadcast(vm.envUint("MENTO_DEPLOYER_PK"));
    {
      cUSDDistributor = new MerkleDistributorWithDeadline(cUSD, merkleRootCUSD, block.timestmap + 31 days);
      console.log("MerkleDistributor for cUSD deployed at:", cUSDDistributor);
      mentoDistributor = new MerkleDistributorWithDeadline(MENTO, merkleRootMENTO, block.timestamp + 121 days);
      console.log("MerkleDistributor for MENTO deployed at:", mentoDistributor);

      cUSDDistributor.transferOwnership(mentoLabsMultisig);
      mentoDistributor.transferOwnership(mentoLabsMultisig);
      console.log("Transferred ownership of MerkleDistributors to MentoLabs Multisig");
    }

    vm.stopBroadcast();
  }

  function readMerkleRoot(string memory token) internal view returns (bytes32) {
    string memory root = vm.projectRoot();
    string memory path = string(abi.encodePacked(root, "/data/oct2024.minipay.", token, ".root.json"));
    string memory json = vm.readFile(path);
    return stdJson.readBytes32(json, token);
  }
}
