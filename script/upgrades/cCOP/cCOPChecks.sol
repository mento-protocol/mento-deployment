// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { cCOPChecksSwap } from "./cCOPChecks.swap.sol";
import { cCOPChecksVerify } from "./cCOPChecks.verify.sol";

contract cCOPChecks is Test {
  function run() public {
    new cCOPChecksVerify().run();

    // TODO: Exchange creation is currently commented out.
    //       Once we have rate feeds, we can uncomment this line
    // new cCOPChecksSwap().run();
  }
}
