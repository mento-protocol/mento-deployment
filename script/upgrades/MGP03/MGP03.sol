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

interface ILockingLite {
  function setMentoLabsMultisig(address mentoLabsMultisig_) external;

  function mentoLabsMultisig() external view returns (address);
}

contract MGP03 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;

  address public mentoGovernor;
  address public locking;

  IGovernanceFactory public governanceFactory;

  /**
   * @dev Loads the contracts from previous deployments
   */
  function loadDeployedContracts() public {
    // Load load deployment with governance factory
    contracts.loadSilent("MUGOV-00-Create-Factory", "latest");
  }

  function prepare() public {
    loadDeployedContracts();

    governanceFactory = IGovernanceFactory(contracts.deployed("GovernanceFactory"));

    mentoGovernor = governanceFactory.mentoGovernor();
    require(mentoGovernor != address(0), "MentoGovernor address not found");

    locking = governanceFactory.locking();
    require(locking != address(0), "Locking address not found");
  }

  function run() public {
    prepare();

    ICeloGovernance.Transaction[] memory _transactions = buildProposal();

    vm.startBroadcast(Chain.deployerPrivateKey());
    {
      // TODO: Change this to the forum post URL
      createProposal(_transactions, "https://CHANGE-ME-PLEASE", mentoGovernor);
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    ICeloGovernance.Transaction[] memory _transactions = new ICeloGovernance.Transaction[](2);

    address mentoLabsMultisig = contracts.dependency("MentoLabsMultisig");

    uint256 currentVotingPeriod;
    uint256 newVotingPeriod;
    if (Chain.isCelo()) {
      currentVotingPeriod = 120960;
      newVotingPeriod = 604800;
    } else {
      currentVotingPeriod = 60;
      newVotingPeriod = 300;
    }

    require(IGovernor(mentoGovernor).votingPeriod() == currentVotingPeriod, "Current voting period is not correct");

    require(ILockingLite(locking).mentoLabsMultisig() == address(0), "Mento Labs multisig is already set");

    _transactions[0] = ICeloGovernance.Transaction(
      0,
      mentoGovernor,
      abi.encodeWithSelector(IGovernor.setVotingPeriod.selector, newVotingPeriod)
    );

    _transactions[1] = ICeloGovernance.Transaction(
      0,
      locking,
      abi.encodeWithSelector(ILockingLite.setMentoLabsMultisig.selector, mentoLabsMultisig)
    );

    return _transactions;
  }
}
