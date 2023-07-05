// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Script as BaseScript, console2 } from "forge-std/Script.sol";
import { FixidityLib } from "./FixidityLib.sol";
import { Chain } from "./Chain.sol";
import { Contracts } from "./Contracts.sol";
import { GovernanceHelper } from "./GovernanceHelper.sol";
import { Factory } from "./Factory.sol";

contract Script is BaseScript {
  using Contracts for Contracts.Cache;
  using FixidityLib for FixidityLib.Fraction;

  address public constant REGISTRY_ADDRESS = 0x000000000000000000000000000000000000ce10;

  Contracts.Cache public contracts;
  Factory public factory;

  constructor() public {
    _init();
  }

  function _init() internal {
    factory = new Factory();
  }

  function fork() public {
    Chain.fork();
    _init();
  }
}

contract GovernanceScript is Script, GovernanceHelper {}
