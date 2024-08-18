// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { CeloGovernanceScript } from "script/utils/v2/CeloGovernanceScript.sol";

contract TemplateCelo is CeloGovernanceScript {
  bool public constant override hasChecks = true;
  // Add the descroption URL here:
  string public constant DESCRIPTION_URL = "<todo: add url>";

  constructor() CeloGovernanceScript(DESCRIPTION_URL) {}

  function setUp() public override {
    // Load any deployments scripts needed:
    // load("DeployMentScript", latest);
  }

  function buildProposal() public override {
    // Add transactions here
    add({ value: 0, destination: lookup("Governance"), data: abi.encode() });
  }
}
