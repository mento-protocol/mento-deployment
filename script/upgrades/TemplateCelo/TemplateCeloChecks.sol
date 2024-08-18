// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { console } from "forge-std/console.sol";
import { Test } from "mento-std/Test.sol";
import { TemplateCelo } from "./TemplateCelo.sol";

contract TemplateCeloChecks is TemplateCelo, Test {
  function run() public override {
    // TODO: Add checks to verify the proposal.
    console.log(unicode"  Governance proposal checks passed");
  }
}
