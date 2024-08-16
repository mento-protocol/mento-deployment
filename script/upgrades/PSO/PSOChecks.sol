// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { PSOChecksVerify } from "./PSOChecks.verify.sol";
import { PSOChecksSwap } from "./PSOChecks.swap.sol";

contract PSOChecks is Test {
  function run() public {
    new PSOChecksVerify().run();
    //new PSOChecksSwap().run();
  }
}
