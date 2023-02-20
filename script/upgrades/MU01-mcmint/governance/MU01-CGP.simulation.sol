// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { MU01_CGP } from "./MU01-CGP.sol";
import { ICeloGovernance } from "mento-core/contracts/governance/interfaces/ICeloGovernance.sol";

import { DeploymentChecks } from "../tests/DeploymentChecks.sol";
import { Chain } from "script/utils/Chain.sol";
import { Contracts } from "script/utils/Contracts.sol";

// forge script {file} --rpc-url $BAKLAVA_RPC_URL
contract MU01_BaklavaCGPSimulation is GovernanceScript {
  using Contracts for Contracts.Cache;

  address public governance;

  function run() public {
    Chain.fork();
    governance = contracts.celoRegistry("Governance");
    simulate();
  }

  function simulate() internal {
    MU01_CGP rev = new MU01_CGP();
    rev.prepare();
    simulateProposal(rev.buildProposal(), governance);
    DeploymentChecks test = new DeploymentChecks();
    test.runInFork();
  }
}