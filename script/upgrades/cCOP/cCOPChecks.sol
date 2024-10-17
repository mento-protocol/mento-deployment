// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { cCOPChecksVerify } from "./cCOPChecks.verify.sol";
import { cCOPChecksSwap } from "./cCOPChecks.swap.sol";

contract cCOPChecks is Test {
  function run() public {
    new cCOPChecksVerify().run();
    new cCOPChecksSwap().run();
  }
}
