// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { Test } from "forge-std/Test.sol";

import { GDChecksVerify } from "./GDChecks.verify.sol";
//import { GDChecksSwap } from "./GDChecks.swap.sol";

contract GDChecks is Test {
  function run() public {
    new GDChecksVerify().run();
    //new GDChecksSwap().run();
  }
}
