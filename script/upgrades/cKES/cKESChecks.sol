// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { cKESChecksSwap } from "./cKESChecks.swap.sol";
import { cKESChecksVerify } from "./cKESChecks.verify.sol";

contract cKESChecks is Test {
  function run() public {
    new cKESChecksVerify().run();
    new cKESChecksSwap().run();
  }
}
