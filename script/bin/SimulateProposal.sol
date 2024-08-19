// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable func-name-mixedcase, contract-name-camelcase
pragma solidity ^0.8.18;

import { console } from "forge-std/console.sol";
import { Script } from "mento-std/Script.sol";
import { CVS } from "mento-std/CVS.sol";
import { GovernanceScript } from "script/utils/v2/GovernanceScript.sol";

interface IScript {
  function run() external;
}

contract SimulateProposal is Script {
  function run(string memory _upgrade) public {
    fork();

    GovernanceScript upgrade = GovernanceScript(CVS.deploy(_upgrade));
    upgrade.simulate();

    if (upgrade.hasChecks()) {
      IScript checks = IScript(CVS.deploy(string(abi.encodePacked(_upgrade, "Checks"))));
      checks.run();
    } else {
      console.log("No checks for %s", _upgrade);
    }
  }

  function check(string memory _upgrade) public {
    GovernanceScript upgrade = GovernanceScript(CVS.deploy(_upgrade));
    if (upgrade.hasChecks()) {
      IScript checks = IScript(CVS.deploy(string(abi.encodePacked(_upgrade, "Checks"))));
      checks.run();
    } else {
      console.log("No checks for %s", _upgrade);
    }
  }
}
