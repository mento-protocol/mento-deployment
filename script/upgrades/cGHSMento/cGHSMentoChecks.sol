// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { cGHSMentoChecksVerify } from "./cGHSMentoChecks.verify.sol";
import { cGHSMentoChecksSwap } from "./cGHSMentoChecks.swap.sol";

contract cGHSMentoChecks is Test {
  function run() public {
    new cGHSMentoChecksVerify().run();
    new cGHSMentoChecksSwap().run();
  }
}
