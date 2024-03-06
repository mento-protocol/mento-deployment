// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { MU05ChecksSwap } from "./MU05Checks.swap.sol";
import { MU05ChecksVerify } from "./MU05Checks.verify.sol";

contract MU05Checks is Test {
  function run() public {
    new MU05ChecksVerify().run();
    new MU05ChecksSwap().run();
  }
}
