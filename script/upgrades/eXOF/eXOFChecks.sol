// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { Test } from "forge-std/Test.sol";
import { Script } from "script/utils/Script.sol";
import { Contracts } from "script/utils/Contracts.sol";

import { eXOFChecksBase } from "./eXOFChecks.base.sol";
import { eXOFChecksSwap } from "./eXOFChecks.swap.sol";
import { eXOFChecksVerify } from "./eXOFChecks.verify.sol";

contract eXOFChecks is eXOFChecksBase {
  using Contracts for Contracts.Cache;

  function run() public {
    setUp();

    new eXOFChecksVerify().run();
    new eXOFChecksSwap().run();
  }
}
