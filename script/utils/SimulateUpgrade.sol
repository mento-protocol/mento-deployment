// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { console } from "forge-std/console.sol";
import { GovernanceScript } from "script/utils/Script.sol";
import { Chain } from "script/utils/Chain.sol";
import { Contracts } from "script/utils/Contracts.sol";
import { IMentoUpgrade } from "script/interfaces/IMentoUpgrade.sol";

interface IScript {
  function run() external;
}

contract SimulateUpgrade is GovernanceScript {
  using Contracts for Contracts.Cache;

  function run(string memory _upgrade) public {
    fork();
    address governance = contracts.celoRegistry("Governance");
    IMentoUpgrade upgrade = IMentoUpgrade(factory.create(_upgrade));
    upgrade.prepare();
    simulateProposal(upgrade.buildProposal(), governance);
    if (upgrade.hasChecks()) {
      IScript checks = IScript(factory.create(string(abi.encodePacked(_upgrade, "Checks"))));
      checks.run();
    }
  }
}




