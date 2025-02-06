// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { cGHSCeloChecksVerify } from "./cGHSCeloChecks.verify.sol";
import { cGHSCeloChecksSwap } from "./cGHSCeloChecks.swap.sol";

contract cGHSCeloChecks is Test {
  function run() public {
    new cGHSCeloChecksVerify().run();
    new cGHSCeloChecksSwap().run();
  }
}
