// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std-prev/Test.sol";

import { MU06ChecksSwap } from "./MU06Checks.swap.sol";
import { MU06ChecksVerify } from "./MU06Checks.verify.sol";

contract MU06Checks is Test {
  function run() public {
    new MU06ChecksVerify().run();
    new MU06ChecksSwap().run();
  }
}
