// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { cJPYxNGNChecksVerify } from "./cJPYxNGNChecks.verify.sol";
import { cJPYxNGNChecksSwap } from "./cJPYxNGNChecks.swap.sol";

contract cJPYxNGNChecks is Test {
  function run() public {
    new cJPYxNGNChecksVerify().run();
    new cJPYxNGNChecksSwap().run();
  }
}
