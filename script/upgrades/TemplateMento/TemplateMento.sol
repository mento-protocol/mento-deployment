// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { MentoGovernanceScript } from "script/utils/v2/MentoGovernanceScript.sol";

contract TemplateMento is MentoGovernanceScript {
  bool public constant override hasChecks = true;
  // Add the descroption URL here:
  string public constant TITLE = "<todo: add title>";
  string public constant PROPOSAL_ID = "TemplateMento"; // Same as filename

  constructor() MentoGovernanceScript(TITLE, PROPOSAL_ID) {}

  function setUp() internal override {
    super.setUp();
    // Load any deployments scripts needed:
    // load("DeployMentScript", latest);
  }

  function buildProposal() internal override {
    // Add transactions here
    add({ value: 0, destination: lookup("Governance"), data: abi.encode() });
  }
}
