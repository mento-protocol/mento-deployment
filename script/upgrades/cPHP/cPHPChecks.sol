// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { cPHPChecksVerify } from "./cPHPChecks.verify.sol";
import { cPHPChecksSwap } from "./cPHPChecks.swap.sol";

contract cPHPChecks is Test {
  function run() public {
    new cPHPChecksVerify().run();
    //new cPHPChecksSwap().run();
  }
}
