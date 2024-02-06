import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import * as fs from "fs";
import { ok } from "node:assert/strict";

/**
 * @title Post Deployment Checks
 * @dev Makes calls to deployed contracts to verify if the contracts are deployed with a correct state
 * Usage: `npx hardhat deploy --network <NETWORK> --tags GOV_CHECK`
 */
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers, deployments, getNamedAccounts, getChainId } = hre;
  const { deployer } = await getNamedAccounts();

  const CELO_REGISTRY = "0x000000000000000000000000000000000000ce10";

  const MENTO_LABS_MULTISIG = process.env.MENTO_LABS_MULTISIG;
  if (!MENTO_LABS_MULTISIG) {
    throw new Error("MENTO_LABS_MULTISIG is not set");
  }
  const WATCHDOG_MULTISIG = process.env.WATCHDOG_MULTISIG;
  if (!WATCHDOG_MULTISIG) {
    throw new Error("WATCHDOG_MULTISIG is not set");
  }

  const FRAKTAL_SIGNER = process.env.FRAKTAL_SIGNER;
  if (!FRAKTAL_SIGNER) {
    throw new Error("FRAKTAL_SIGNER is not set");
  }

  let merkleRoot;

  try {
    const treeData = JSON.parse(fs.readFileSync("scripts/data/out/tree.json", "utf8"));
    merkleRoot = treeData.root;
  } catch (error) {
    console.log({ error });
    throw new Error("Error during json parsing");
  }

  const celoRegistry = await ethers.getContractAt("IRegistry", CELO_REGISTRY);
  const celoGovernanceAddress = await celoRegistry.getAddressForStringOrDie("Governance");
  const GovernanceFactoryDep = await deployments.get("GovernanceFactory");
  const factory = await ethers.getContractAt("GovernanceFactory", GovernanceFactoryDep.address);
  const chainId = await getChainId();

  console.log("=================================================");
  console.log("*****************************");
  console.log("Performing Post Deployment Checks");
  console.log("*****************************");
  console.log("\n");

  const owner = await factory.owner();
  ok(
    owner === (chainId === "31337" ? deployer : celoGovernanceAddress),
    "Owner of GovernanceFactory is not Celo Governance",
  );

  const mentoTokenAddress = await factory.mentoToken();
  const mentoToken = await ethers.getContractAt("MentoToken", mentoTokenAddress);

  const emissionAddress = await factory.emission();
  const emission = await ethers.getContractAt("Emission", emissionAddress);

  const airgrabAddress = await factory.airgrab();
  const airgrab = await ethers.getContractAt("Airgrab", airgrabAddress);

  const governanceTimelockAddress = await factory.governanceTimelock();
  const governanceTimelock = await ethers.getContractAt("TimelockController", governanceTimelockAddress);

  const mentoGovernorAddress = await factory.mentoGovernor();
  const mentoGovernor = await ethers.getContractAt("MentoGovernor", mentoGovernorAddress);

  const lockingAddress = await factory.locking();
  const locking = await ethers.getContractAt("Locking", lockingAddress);


  // mentoToken checks
  const mentoLabsMultisigBalance = await mentoToken.balanceOf(MENTO_LABS_MULTISIG);
  ok(
    mentoLabsMultisigBalance.toString() === ethers.parseEther("200000000").toString(),
    "MentoLabs multisig balance is incorrect",
  );

  const airgrabBalance = await mentoToken.balanceOf(airgrabAddress);
  ok(airgrabBalance.toString() === ethers.parseEther("50000000").toString(), "Airgrab balance is incorrect");
  const governanceTimelockBalance = await mentoToken.balanceOf(governanceTimelockAddress);
  ok(
    governanceTimelockBalance.toString() === ethers.parseEther("100000000").toString(),
    "Governance Timelock balance is incorrect",
  );

  const emissionSupply = await mentoToken.emissionSupply();
  ok(
    emissionSupply.toString() === ethers.parseEther("650000000").toString(),
    "Emission supply of mentoToken is incorrect",
  );
  const symbol = await mentoToken.symbol();
  ok(symbol === "MENTO", "Symbol of mentoToken is incorrect");
  const name = await mentoToken.name();
  ok(name === "Mento Token", "Name of mentoToken is incorrect");

  const emissionAddressStored = await mentoToken.emission();
  ok(emissionAddressStored === emissionAddress, "Emission address of mentoToken is incorrect");

  // emission checks
  const emissionMentoTokenAddress = await emission.mentoToken();
  ok(emissionMentoTokenAddress === mentoTokenAddress, "MentoToken address in emission is incorrect");

  const emissionTarget = await emission.emissionTarget();
  ok(emissionTarget === governanceTimelockAddress, "Emission target address is incorrect");

  const emissionOwner = await emission.owner();
  ok(emissionOwner === governanceTimelockAddress, "Owner of emission is incorrect");

  // airgrab checks
  const airgrabRoot = await airgrab.root();
  ok(airgrabRoot === merkleRoot, "Airgrab Merkle root is incorrect");

  const airgrabFractalSigner = await airgrab.fractalSigner();
  ok(airgrabFractalSigner === FRAKTAL_SIGNER, "Airgrab fractal signer is incorrect");

  const airgrabFractalMaxAge = await airgrab.fractalMaxAge();
  ok(airgrabFractalMaxAge.toString() === "15552000", "Airgrab fractal max age is incorrect"); // 180 days in seconds

  const airgrabSlopePeriod = await airgrab.slopePeriod();
  ok(airgrabSlopePeriod.toString() === "104", "Airgrab slope period is incorrect");

  const airgrabCliffPeriod = await airgrab.cliffPeriod();
  ok(airgrabCliffPeriod.toString() === "0", "Airgrab cliff period is incorrect");

  const airgrabTokenAddress = await airgrab.token();
  ok(airgrabTokenAddress === mentoTokenAddress, "Token address in airgrab is incorrect");

  const airgrabLockingAddress = await airgrab.locking();
  ok(airgrabLockingAddress === lockingAddress, "Locking address in airgrab is incorrect");

  const airgrabCeloCommunityFundAddress = await airgrab.celoCommunityFund();
  ok(airgrabCeloCommunityFundAddress === celoGovernanceAddress, "Celo Community Fund address in airgrab is incorrect");

  // governanceTimelock checks
  const proposerRole = await governanceTimelock.PROPOSER_ROLE();
  const executorRole = await governanceTimelock.EXECUTOR_ROLE();
  const cancellerRole = await governanceTimelock.CANCELLER_ROLE();

  ok(
    (await governanceTimelock.getMinDelay()).toString() === (2 * 24 * 60 * 60).toString(),
    "MinDelay of governanceTimelock is incorrect",
  );
  ok(
    await governanceTimelock.hasRole(proposerRole, mentoGovernorAddress),
    "governanceTimelock proposer role for mentoGovernor is incorrect",
  );
  ok(
    await governanceTimelock.hasRole(executorRole, ethers.ZeroAddress),
    "governanceTimelock executor role for address(0) is incorrect",
  );
  ok(
    await governanceTimelock.hasRole(cancellerRole, mentoGovernorAddress),
    "governanceTimelock canceller role for mentoGovernor is incorrect",
  );
  ok(
    await governanceTimelock.hasRole(cancellerRole, WATCHDOG_MULTISIG),
    "governanceTimelock canceller role for watchdogMultisig is incorrect",
  );

  // mentoGovernor checks
  ok((await mentoGovernor.token()) === lockingAddress, "Token of mentoGovernor is incorrect");
  ok((await mentoGovernor.votingDelay()).toString() === "0", "Voting delay of mentoGovernor is incorrect");
  const BLOCKS_WEEK = 120_960;
  ok(
    (await mentoGovernor.votingPeriod()).toString() === BLOCKS_WEEK.toString(),
    "Voting period of mentoGovernor is incorrect",
  );
  ok(
    (await mentoGovernor.proposalThreshold()).toString() === ethers.parseEther("1000").toString(),
    "Proposal threshold of mentoGovernor is incorrect",
  );
  ok((await mentoGovernor.quorumNumerator()).toString() === "2", "Quorum numerator of mentoGovernor is incorrect");
  ok((await mentoGovernor.timelock()) === governanceTimelockAddress, "Timelock of mentoGovernor is incorrect");

  // locking checks
  ok((await locking.token()) === mentoTokenAddress, "Token of locking is incorrect");
  ok((await locking.minCliffPeriod()).toString() === "0", "Min cliff period of locking is incorrect");
  ok((await locking.minSlopePeriod()).toString() === "1", "Min slope period of locking is incorrect");
  ok((await locking.owner()) === governanceTimelockAddress, "Owner of locking is incorrect");
  ok((await locking.getWeek()).toString() === "1", "Current week of locking is incorrect");
  ok((await locking.symbol()) === "veMENTO", "Symbol of locking is incorrect");
  ok((await locking.name()) === "Mento Vote-Escrow", "Name of locking is incorrect");

  console.log("\n");
  console.log("*****************************");
  console.log("Post deployment checks passed!");
  console.log("*****************************");
  console.log("=================================================");
};

export default func;
func.tags = ["GOV_CHECK", "GOV_FORK"];
