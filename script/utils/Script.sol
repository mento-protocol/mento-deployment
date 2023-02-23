// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Script as BaseScript, console2 } from "forge-std/Script.sol";
import { FixidityLib } from "mento-core/contracts/common/FixidityLib.sol";
import { Chain } from "./Chain.sol";
import { Contracts } from "./Contracts.sol";
import { GovernanceHelper } from "./GovernanceHelper.sol";
import { IPricingModule } from "mento-core/contracts/interfaces/IPricingModule.sol";
import { IERC20Metadata } from "mento-core/contracts/common/interfaces/IERC20Metadata.sol";

contract Script is BaseScript {
  using Contracts for Contracts.Cache;
  using FixidityLib for FixidityLib.Fraction;

  address public constant REGISTRY_ADDRESS = 0x000000000000000000000000000000000000ce10;

  Contracts.Cache public contracts;
}

contract GovernanceScript is Script, GovernanceHelper {
}
