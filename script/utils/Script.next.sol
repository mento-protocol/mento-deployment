// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { Script as BaseScript, console2 } from "forge-std-next/Script.sol";
import { StdChains } from "forge-std-next/StdChains.sol";

// import { ChainHelper } from "./Chain.next.sol";
import { Contracts } from "./mento/Contracts.sol";
import { Factory } from "./Factory.sol";

contract Script is BaseScript {
  using Contracts for Contracts.Cache;

  address public constant REGISTRY_ADDRESS = 0x000000000000000000000000000000000000ce10;

  Contracts.Cache public contracts;
  Factory public factory;

  constructor() {
    _init();
  }

  function _init() internal {
    factory = new Factory();
    setChain("celo", ChainData("Celo Mainnet", 42220, ""));
    setChain("baklava", ChainData("Celo Baklava Testnet", 62320, ""));
    setChain("alfajores", ChainData("Celo Alfajores Testnet", 44787, ""));
  }

  function fork() public {
    // Chain.fork();
    Chain memory chain = getChain(block.chainid);
    uint256 forkId = vm.createFork(chain.rpcUrl);
    vm.selectFork(forkId);
    _init();
  }
}
