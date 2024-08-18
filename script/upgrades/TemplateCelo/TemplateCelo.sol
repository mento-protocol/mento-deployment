// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import { CeloGovernanceScript } from "script/utils/v2/CeloGovernanceScript.sol";

contract TemplateCelo is CeloGovernanceScript {
  bool public constant override hasChecks = true;

  constructor()
    CeloGovernanceScript(
      // TODO: Add the URL from celo-org/governance.
      "todo: Proposal URL"
    )
  {}

  function setUp() internal override {
    // TODO: Load any deployments scripts needed.
    // e.g.: load("DeployExampleContract", latest);
  }

  function buildProposal() internal override {
    // TODO: Add transactions to proposal.
    add({ destination: lookup("Governance"), data: bytes("") });
  }
}
