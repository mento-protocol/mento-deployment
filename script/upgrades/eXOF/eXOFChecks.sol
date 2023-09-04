// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { eXOFChecksSwap } from "./eXOFChecks.swap.sol";
import { eXOFChecksVerify } from "./eXOFChecks.verify.sol";

contract eXOFChecks is Test {
  function run() public {
    new eXOFChecksVerify().run();
    new eXOFChecksSwap().run();
  }
}
