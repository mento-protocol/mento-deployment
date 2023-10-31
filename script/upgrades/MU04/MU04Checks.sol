// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { MU04ChecksSwap } from "./MU04Checks.swap.sol";
import { MU04ChecksVerify } from "./MU04Checks.verify.sol";

contract MU04Checks is Test {
  function run() public {
    new MU04ChecksVerify().run();
    new MU04ChecksSwap().run();
  }
}
