// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { cINRChecksSwap } from "./cINRChecks.swap.sol";
import { cINRChecksVerify } from "./cINRChecks.verify.sol";

contract cINRChecks is Test {
  function run() public {
    new cINRChecksVerify().run();
    new cINRChecksSwap().run();
  }
}
