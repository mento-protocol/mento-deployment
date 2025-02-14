// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase, function-max-lines, var-name-mixedcase
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/mento/Script.sol";
import { Contracts } from "script/utils/mento/Contracts.sol";
import { Chain } from "script/utils/mento/Chain.sol";

import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";
import { IMentoUpgrade, ICeloGovernance } from "script/interfaces/IMentoUpgrade.sol";
import { IGovernor } from "script/interfaces/IGovernor.sol";

contract MGP04 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;

  address public mentoGovernor;

  IGovernanceFactory public governanceFactory;

  function loadDeployedContracts() public {
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");
  }

  function prepare() public {
    loadDeployedContracts();

    governanceFactory = IGovernanceFactory(contracts.deployed("GovernanceFactory"));

    mentoGovernor = governanceFactory.mentoGovernor();
    require(mentoGovernor != address(0), "MentoGovernor address not found");
  }

  function run() public {
    prepare();

    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      // TODO: Change this to the forum post URL
      createProposal(_transactions, "updateWithUrl", mentoGovernor);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    ICeloGovernance.Transaction[] memory _transactions = new ICeloGovernance.Transaction[](1);

    // TODO: before submitting, update this to 8 days (691200) if MU08 already executed
    (uint256 currentVotingPeriod, uint256 newVotingPeriod) = Chain.isCelo() ? (120960, 604800) : (60, 300);

    require(IGovernor(mentoGovernor).votingPeriod() == currentVotingPeriod, "Current voting period is not correct");

    _transactions[0] = ICeloGovernance.Transaction(
      0,
      mentoGovernor,
      abi.encodeWithSelector(IGovernor.setVotingPeriod.selector, newVotingPeriod)
    );

    return _transactions;
  }
}
