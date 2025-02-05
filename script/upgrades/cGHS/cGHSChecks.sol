// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { cGHSChecksVerify } from "./cGHSChecks.verify.sol";
import { cGHSChecksSwap } from "./cGHSChecks.swap.sol";

contract cGHSChecks is Test {
  function run() public {
    new cGHSChecksVerify().run();
    new cGHSChecksSwap().run();
  }
}
