// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { FX03ChecksVerify } from "./FX03Checks.verify.sol";
import { FX03ChecksSwap } from "./FX03Checks.swap.sol";

contract FX03Checks is Test {
  function run() public {
    new FX03ChecksVerify().run();
    new FX03ChecksSwap().run();
  }
}
