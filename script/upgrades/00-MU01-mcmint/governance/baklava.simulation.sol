// SPDX-License-Identifier: UNLICENSED
// solhint-disable func-name-mixedcase, contract-name-camelcase
pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import { GovernanceScript } from "script/utils/Script.sol";
import { console2 } from "forge-std/Script.sol";
import { MentoUpgrade1_baklava } from "./baklava.sol";
import { ICeloGovernance } from "mento-core/contracts/governance/interfaces/ICeloGovernance.sol";

import { SwapTest } from "script/test/Swap.sol";
import { Chain } from "script/utils/Chain.sol";
import { Contracts } from "script/utils/Contracts.sol";

// forge script {file} --rpc-url $BAKLAVA_RPC_URL
contract MentoUpgrade1_baklava_simulation is GovernanceScript {
  using Contracts for Contracts.Cache;

  address public governance;

  function run() public {
    Chain.fork();
    governance = contracts.celoRegistry("Governance");
    simulate();
  }

  function simulate() internal {
    MentoUpgrade1_baklava rev = new MentoUpgrade1_baklava();
    rev.prepare();
    simulateProposal(rev.buildProposal(), governance);
    SwapTest test = new SwapTest();
    test.run();
  }
}
