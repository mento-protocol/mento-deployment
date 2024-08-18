// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { MentoGovernanceScript } from "script/utils/v2/MentoGovernanceScript.sol";

contract TemplateMento is MentoGovernanceScript {
  bool public constant override hasChecks = true;
  // TODO: Add the proposal title.
  string public constant TITLE = "Template for Mento Governance Proposals";
  // TODO: Add the path to the description markdown.
  string public constant DESCRIPTION_PATH = "script/upgrades/TemplateMento/TemplateMento.md";

  constructor() MentoGovernanceScript(TITLE, DESCRIPTION_PATH) {}

  function setUp() internal override {
    super.setUp();
    // TODO: Load any deployments scripts needed.
    // e.g.: load("DeployExampleContract", latest);
  }

  function buildProposal() internal override {
    // TODO: Add transactions to proposal.
    add({ value: 0, destination: lookup("Governance"), data: abi.encode() });
  }
}
