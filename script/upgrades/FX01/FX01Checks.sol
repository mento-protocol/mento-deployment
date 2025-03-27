// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { FX01ChecksVerify } from "./FX01Checks.verify.sol";
import { FX01ChecksSwap } from "./FX01Checks.swap.sol";

contract FX01Checks is Test {
  function run() public {
    new FX01ChecksVerify().run();
    new FX01ChecksSwap().run();
  }
}
