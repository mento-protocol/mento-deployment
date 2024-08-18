// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { MentoGovernanceScript } from "script/utils/v2/MentoGovernanceScript.sol";

contract TemplateMento is MentoGovernanceScript {
  bool public constant override hasChecks = true;

  constructor()
    MentoGovernanceScript(
      // TODO: Add the proposal title.
      "todo: Proposal Title",
      // TODO: Add the path to the description markdown.
      "script/upgrades/TemplateMento/TemplateMento.md"
    )
  {}

  function setUp() internal override {
    super.setUp();
    // TODO: Load any deployments scripts needed.
    // e.g.: load("DeployExampleContract", latest);
  }

  function buildProposal() internal override {
    // TODO: Add transactions to proposal.
    add({ destination: lookup("Governance"), data: bytes("") });
  }
}
