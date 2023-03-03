// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { MU01_CGP_Phase1 } from "./MU01-CGP-Phase1.sol";
import { ICeloGovernance } from "mento-core/contracts/governance/interfaces/ICeloGovernance.sol";

import { DeploymentChecks } from "../tests/DeploymentChecks.sol";
import { Chain } from "script/utils/Chain.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { ICGPBuilder } from "script/utils/ICGPBuilder.sol";

// forge script {file} --rpc-url $BAKLAVA_RPC_URL
contract MU01_CGPSimulation is GovernanceScript {
  using Contracts for Contracts.Cache;

  address public governance;

  function run(uint8 phase) public {
    require(phase >= 1 && phase <= 3, "Invalid phase");
    Chain.fork();
    governance = contracts.celoRegistry("Governance");
    simulate(phase);
  }

  function getProposalBuilder(uint8 phase) internal returns (ICGPBuilder) {
    if (phase == 1) {
      return ICGPBuilder(new MU01_CGP_Phase1());
    } else if (phase == 2) {
      // return ICGPBuilder(new MU01_CGP_Phase2());
      revert("not implemented");
    } else if (phase == 3) {
      // return ICGPBuilder(new MU01_CGP_Phase3());
      revert("not implemented");
    } else {
      revert("Invalid phase");
    }
  }

  function simulate(uint8 phase) internal {
    ICGPBuilder cgp = getProposalBuilder(phase);
    cgp.prepare();
    simulateProposal(cgp.buildProposal(), governance);
    DeploymentChecks test = new DeploymentChecks();
    test.runInFork();
  }
}
