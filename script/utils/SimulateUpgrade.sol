// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;


import { GovernanceScript } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { ICGPBuilder } from "script/utils/ICGPBuilder.sol";
import { IDeploymentChecks } from "script/utils/IDeploymentChecks.sol";

contract SimulateUpgrade is GovernanceScript {
  using Contracts for Contracts.Cache;

  address public governance;
  

  function run(string memory upgrade) public {
    Chain.fork();
    governance = contracts.celoRegistry("Governance");
    simulate(upgrade);
  }

  function getProposalBuilder(string memory upgrade) internal returns (ICGPBuilder){
    return (IDeploymentChecks(factory.create(upgrade)), true);
  }

  function getDeploymentChecks(string memory upgrade) internal returns (IDeploymentChecks, bool) {
    return (IDeploymentChecks(factory.create(abi.encodePacked(upgrade, "-Checks"))), true);
  }

  function simulate(string memory upgrade) internal {
    ICGPBuilder cgp = getProposalBuilder(upgrade);
    cgp.prepare();
    simulateProposal(cgp.buildProposal(), governance);

    (IDeploymentChecks test, bool hasChecks) = getDeploymentChecks();
    if (hasChecks) test.runInFork();
  }
}




