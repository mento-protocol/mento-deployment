// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.5.13;

import { PrecompileHandler } from "celo-foundry/PrecompileHandler.sol";
import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console2 as console } from "forge-std/Script.sol";

import { Chain } from "script/utils/Chain.sol";
import { GovernanceScript } from "script/utils/Script.sol";
import { IGovernanceFactory } from "script/interfaces/IGovernanceFactory.sol";
import { IMentoToken, IEmission, IAirgrab, ITimelock, IMentoGovernor, ILocking } from "./interfaces.sol";

contract MUGOVChecks is GovernanceScript, Test {
  constructor() public {
    new PrecompileHandler();
    setUp();
  }

  bytes32 public airgrabMerkleRoot;
  IGovernanceFactory public governanceFactory;

  address mentoLabsMultisig;
  address watchdogMultisig;
  address fractalSigner;

  IMentoToken mentoToken;
  IEmission emission;
  IAirgrab airgrab;
  ITimelock governanceTimelock;
  IMentoGovernor mentoGovernor;
  ILocking locking;

  function setUp() public {
    contracts.load("MUGOV-04-Create-Factory", "latest");
    airgrabMerkleRoot = readAirgrabMerkleRoot();
    governanceFactory = IGovernanceFactory(contracts.deployed("GovernanceFactory"));

    mentoToken = IMentoToken(governanceFactory.mentoToken());
    emission = IEmission(governanceFactory.emission());
    airgrab = IAirgrab(governanceFactory.airgrab());
    governanceTimelock = ITimelock(governanceFactory.governanceTimelock());
    mentoGovernor = IMentoGovernor(governanceFactory.mentoGovernor());
    locking = ILocking(governanceFactory.locking());

    mentoLabsMultisig = contracts.dependency("MentoLabsMultisig");
    watchdogMultisig = contracts.dependency("WatchdogMultisig");
    fractalSigner = contracts.dependency("FractalSigner");
  }

  function run() public {
    // Balances:
    assertEq(mentoToken.balanceOf(mentoLabsMultisig), 100000000 * 1e18, "MentoLabs multisig balance is incorrect");
    assertEq(mentoToken.balanceOf(address(airgrab)), 100000000 * 1e18, "Airgrab balance is incorrect");
    assertEq(
      mentoToken.balanceOf(address(governanceTimelock)),
      100000000 * 1e18,
      "Governance timelock balance is incorrect"
    );
    assertEq(mentoToken.emissionSupply(), 693000000 * 1e18, "Emission supply is incorrect");
    console.log("🟢 Mento Token initial allocation minted correctly");

    // Mento Token:
    assertEq(mentoToken.symbol(), "MENTO", "Token symbol is incorrect");
    assertEq(mentoToken.name(), "Mento Token", "Token name is incorrect");
    assertEq(uint256(mentoToken.decimals()), 18, "Token decimals is incorrect");
    assertEq(mentoToken.emission(), address(emission), "Emission address is incorrect");
    console.log("🟢 Mento Token setup correctly");

    // Emission checks:
    assertEq(emission.owner(), address(governanceTimelock), "Emission owner is incorrect");
    assertEq(emission.mentoToken(), address(mentoToken), "Emission Mento Token is incorrect");
    assertEq(emission.emissionTarget(), address(governanceTimelock), "Emission target is incorrect");
    console.log("🟢 Emission setup correctly");

    // Airgrab checks:
    assertEq(airgrab.root(), airgrabMerkleRoot, "Airgrab root is incorrect");
    assertEq(airgrab.fractalSigner(), fractalSigner, "Airgrab fractal signer is incorrect");
    assertEq(airgrab.fractalMaxAge(), 15552000, "Airgrab fractal max age is incorrect");
    assertEq(uint256(airgrab.slopePeriod()), 104, "Airgrab slope period is incorrect");
    assertEq(uint256(airgrab.cliffPeriod()), 0, "Airgrab cliff period is incorrect");
    assertEq(airgrab.token(), address(mentoToken), "Airgrab token is incorrect");
    assertEq(airgrab.locking(), address(locking), "Airgrab locking is incorrect");
    assertEq(
      airgrab.celoCommunityFund(),
      contracts.celoRegistry("Governance"),
      "Airgrab celo community fund is incorrect"
    );
    console.log("🟢 Airgrab setup correctly");

    // Timelock Checks
    assertEq(governanceTimelock.getMinDelay(), 2 * 24 * 60 * 60, "Timelock min delay is incorrect");
    assertTrue(
      governanceTimelock.hasRole(governanceTimelock.PROPOSER_ROLE(), address(mentoGovernor)),
      "governanceTimelock proposer role for mentoGovernor is incorrect"
    );

    assertTrue(
      governanceTimelock.hasRole(governanceTimelock.EXECUTOR_ROLE(), address(0)),
      "governanceTimelock executor role for address(0) is incorrect"
    );

    assertTrue(
      governanceTimelock.hasRole(governanceTimelock.CANCELLER_ROLE(), address(mentoGovernor)),
      "governanceTimelock canceller role for mentoGovernor is incorrect"
    );

    assertTrue(
      governanceTimelock.hasRole(governanceTimelock.CANCELLER_ROLE(), watchdogMultisig),
      "governanceTimelock canceller role for mentoGovernor is incorrect"
    );

    console.log("🟢 Governance Timelock setup correctly");

    // Mento Governor checks:
    assertEq(mentoGovernor.token(), address(locking), "MentoGovernor token is incorrect");
    assertEq(mentoGovernor.votingDelay(), 0, "MentoGovernor voting delay is incorrect");
    assertEq(mentoGovernor.votingPeriod(), 120960, "MentoGovernor voting period is incorrect");
    assertEq(mentoGovernor.proposalThreshold(), 1000 * 1e18, "MentoGovernor proposal threshold is incorrect");
    assertEq(mentoGovernor.quorumNumerator(), 2, "MentoGovernor quorum numerator is incorrect");
    assertEq(mentoGovernor.timelock(), address(governanceTimelock), "MentoGovernor timelock is incorrect");

    console.log("🟢 Mento Governor setup correctly");

    // Locking checks:
    assertEq(locking.token(), address(mentoToken), "Locking token is incorrect");
    assertEq(locking.minCliffPeriod(), 0, "Locking min cliff period is incorrect");
    assertEq(locking.minSlopePeriod(), 1, "Locking max cliff period is incorrect");
    assertEq(locking.owner(), address(governanceTimelock), "Locking owner is incorrect");
    assertEq(locking.getWeek(), 1, "Locking week is incorrect");
    assertEq(locking.symbol(), "veMENTO", "Locking symbol is incorrect");
    assertEq(locking.name(), "Mento Vote-Escrow", "Locking name is incorrect");

    console.log("🟢 Locking setup correctly");
  }

  function readAirgrabMerkleRoot() internal view returns (bytes32) {
    string memory network = Chain.rpcToken(); // celo | baklava | alfajores
    string memory root = vm.projectRoot();
    string memory path = string(abi.encodePacked(root, "/data/airgrab.", network, ".tree.json"));
    string memory json = vm.readFile(path);
    return stdJson.readBytes32(json, ".root");
  }
}
