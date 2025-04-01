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

contract MGP06 is IMentoUpgrade, GovernanceScript {
  using Contracts for Contracts.Cache;

  bool public hasChecks = true;

  address public mentoGovernor;
  address public locking;

  IGovernanceFactory public governanceFactory;

  function loadDeployedContracts() public {
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
      createStructuredProposal(
        "MGP-6: Remove Mento Labs multisig on Locking contract",
        "./script/upgrades/MGP06/MGP06.md",
        _transactions,
        mentoGovernor
      );
    }
    vm.stopBroadcast();
  }

  function buildProposal() public returns (ICeloGovernance.Transaction[] memory) {
    ICeloGovernance.Transaction[] memory _transactions = new ICeloGovernance.Transaction[](1);

    address mentoLabsMultisig = contracts.dependency("MentoLabsMultisig");
    require(ILockingLite(locking).mentoLabsMultisig() == mentoLabsMultisig, "Mento Labs multisig is already removed");

    _transactions[0] = ICeloGovernance.Transaction(
      0,
      locking,
      abi.encodeWithSelector(ILockingLite.setMentoLabsMultisig.selector, address(0))
    );

    return _transactions;
  }
}
