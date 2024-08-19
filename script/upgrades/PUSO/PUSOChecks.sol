// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { Test } from "forge-std/Test.sol";

import { PUSOChecksVerify } from "./PUSOChecks.verify.sol";
import { PUSOChecksSwap } from "./PUSOChecks.swap.sol";

contract PUSOChecks is Test {
  function run() public {
    new PUSOChecksVerify().run();
    //new PUSOChecksSwap().run();
  }
}
