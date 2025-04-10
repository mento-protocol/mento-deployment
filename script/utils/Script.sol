// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Script as BaseScript, console2 } from "forge-std/Script.sol";
import { FixidityLib } from "./FixidityLib.sol";
import { Chain } from "./Chain.sol";
import { Contracts } from "./Contracts.sol";
import { GovernanceHelper } from "./GovernanceHelper.sol";
import { Factory } from "./Factory.sol";
import { PrecompileHandler } from "celo-foundry/PrecompileHandler.sol";

import { IERC20Lite } from "../interfaces/IERC20Lite.sol";

contract Script is BaseScript {
  using Contracts for Contracts.Cache;
  using FixidityLib for FixidityLib.Fraction;

  address public constant REGISTRY_ADDRESS = 0x000000000000000000000000000000000000ce10;

  Contracts.Cache public contracts;
  Factory public factory;
  PrecompileHandler public ph;

  constructor() public {
    ph = new PrecompileHandler();
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
  function toRateFeedId(string memory rateFeedString) internal pure returns (address) {
    return address(uint160(uint256(keccak256(abi.encodePacked(rateFeedString)))));
  }

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
