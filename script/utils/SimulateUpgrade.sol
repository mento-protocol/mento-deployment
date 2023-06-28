// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;


import { console } from "forge-std/console.sol";
import { GovernanceScript } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { ICGPBuilder } from "script/interfaces/ICGPBuilder.sol";
import { IDeploymentChecks } from "script/interfaces/IDeploymentChecks.sol";

contract SimulateUpgrade is GovernanceScript {
  using Contracts for Contracts.Cache;

  address public governance;
  

  function run(string memory upgrade) public {
    fork();
    governance = contracts.celoRegistry("Governance");
    simulate(upgrade);
  }

  function getProposalBuilder(string memory upgrade) internal returns (ICGPBuilder, bool){
    return (ICGPBuilder(factory.create(upgrade)), true);
  }

  function getDeploymentChecks(string memory upgrade) internal returns (IDeploymentChecks, bool) {
    return (IDeploymentChecks(factory.create(string(abi.encodePacked(upgrade, "-Checks")))), true);
  }

  function simulate(string memory upgrade) internal {
    (ICGPBuilder cgp, bool foundCGP) = getProposalBuilder(upgrade);
    if (!foundCGP) {
      console.log("No deployment script found for: ", upgrade);
      return;
    }

    cgp.prepare();
    simulateProposal(cgp.buildProposal(), governance);

    (IDeploymentChecks test, bool hasChecks) = getDeploymentChecks(upgrade);
    if (hasChecks) test.runInFork();
    else {
      console.log("No deployment checks found for: ", upgrade);
    }
  }
}




