// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import { Script as BaseScript } from "forge-std/Script.sol";
import { FixidityLib } from "../FixidityLib.sol";
import { Chain } from "./Chain.sol";
import { Contracts } from "./Contracts.sol";
import { Factory } from "../Factory.sol";
import { GovernanceHelper } from "./GovernanceHelper.sol";
import { IERC20Lite } from "../../interfaces/IERC20Lite.sol";

contract Script is BaseScript {
  using Contracts for Contracts.Cache;
  using FixidityLib for FixidityLib.Fraction;

  Contracts.Cache public contracts;
  Factory public factory;

  constructor() {
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

contract GovernanceScript is Script, GovernanceHelper {
  /**
   * @notice Helper function to get the exchange ID for a pool.
   */
  function getExchangeId(address asset0, address asset1, bool isConstantSum) internal view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          IERC20Lite(asset0).symbol(),
          IERC20Lite(asset1).symbol(),
          isConstantSum ? "ConstantSum" : "ConstantProduct"
        )
      );
  }
}
