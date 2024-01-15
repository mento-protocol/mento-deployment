import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import * as fs from "fs";
import { assert } from "../utils";

/**
 * @title Post Deployment Checks
 * @dev Makes calls to deployed contracts to verify if the contracts are deployed with a correct state
 * Usage: `npx hardhat deploy --network <NETWORK> --tags GOV_CHECK`
 */
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers, deployments, getNamedAccounts, getChainId } = hre;
  const { deployer } = await getNamedAccounts();

  const CELO_REGISTRY = process.env.CELO_REGISTIRY_ADDRESS;
  if (!CELO_REGISTRY) {
    throw new Error("CELO_REGISTRY_ADDRESS is not set");
  }

  const MENTO_LABS_MULTISIG = process.env.MENTO_LABS_MULTISIG;
  if (!MENTO_LABS_MULTISIG) {
    throw new Error("MENTO_LABS_MULTISIG is not set");
  }
  const WATCHDOG_MULTISIG = process.env.WATCHDOG_MULTISIG;
  if (!WATCHDOG_MULTISIG) {
    throw new Error("WATCHDOG_MULTISIG is not set");
  }
  const CELO_COMMUNITY_FUND = process.env.CELO_COMMUNITY_FUND;
  if (!CELO_COMMUNITY_FUND) {
    throw new Error("CELO_COMMUNITY_FUND is not set");
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

  const celoRegistiry = await ethers.getContractAt("IRegistry", CELO_REGISTRY);
  const celoGovernanceAddress = await celoRegistiry.getAddressForStringOrDie("Governance");
  const GovernanceFactoryDep = await deployments.get("GovernanceFactory");
  const factory = await ethers.getContractAt("GovernanceFactory", GovernanceFactoryDep.address);
  const chainId = await getChainId();

  console.log("=================================================");
  console.log("*****************************");
  console.log("Performing Post Deployment Checks");
  console.log("*****************************");
  console.log("\n");

  const owner = await factory.owner();
  assert(
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

  const mentoLabsTreasuryAddress = await factory.mentoLabsTreasuryTimelock();
  const mentoLabsTreasury = await ethers.getContractAt("TimelockController", mentoLabsTreasuryAddress);

  // factory config checks
  const mentoLabsMultisigBalance = await mentoToken.balanceOf(MENTO_LABS_MULTISIG);
  assert(
    mentoLabsMultisigBalance.toString() === ethers.parseEther("80000000").toString(),
    "MentoLabs multisig balance is incorrect",
  );
  const mentoLabsTreasuryBalance = await mentoToken.balanceOf(mentoLabsTreasuryAddress);
  assert(
    mentoLabsTreasuryBalance.toString() === ethers.parseEther("120000000").toString(),
    "MentoLabs treasury balance is incorrect",
  );
  const airgrabBalance = await mentoToken.balanceOf(airgrabAddress);
  assert(airgrabBalance.toString() === ethers.parseEther("50000000").toString(), "Airgrab balance is incorrect");
  const governanceTimelockBalance = await mentoToken.balanceOf(governanceTimelockAddress);
  assert(
    governanceTimelockBalance.toString() === ethers.parseEther("100000000").toString(),
    "Airgrab balance is incorrect",
  );

  const emissionSuplly = await mentoToken.emissionSupply();
  assert(emissionSuplly.toString() === ethers.parseEther("650000000").toString(), "Airgrab balance is incorrect");
  const emissionAddressStored = await mentoToken.emission();
  assert(emissionAddressStored === emissionAddress, "Emission address of mentoToken is incorrect");
  const symbol = await mentoToken.symbol();
  assert(symbol === "MENTO", "Symbol of mentoToken is incorrect");
  const name = await mentoToken.name();
  assert(name === "Mento Token", "Name of mentoToken is incorrect");

  const emissionMentoTokenAddress = await emission.mentoToken();
  assert(emissionMentoTokenAddress === mentoTokenAddress, "MentoToken address in emission is incorrect");

  const emissionTarget = await emission.emissionTarget();
  assert(emissionTarget === governanceTimelockAddress, "Emission target address is incorrect");

  const emissionOwner = await emission.owner();
  assert(emissionOwner === governanceTimelockAddress, "Owner of emission is incorrect");

  const airgrabRoot = await airgrab.root();
  assert(airgrabRoot === merkleRoot, "Airgrab Merkle root is incorrect");

  const airgrabFractalSigner = await airgrab.fractalSigner();
  assert(airgrabFractalSigner === FRAKTAL_SIGNER, "Airgrab fractal signer is incorrect");

  const airgrabFractalMaxAge = await airgrab.fractalMaxAge();
  assert(airgrabFractalMaxAge.toString() === "15552000", "Airgrab fractal max age is incorrect"); // 180 days in seconds

  const airgrabSlopePeriod = await airgrab.slopePeriod();
  assert(airgrabSlopePeriod.toString() === "104", "Airgrab slope period is incorrect");

  const airgrabCliffPeriod = await airgrab.cliffPeriod();
  assert(airgrabCliffPeriod.toString() === "0", "Airgrab cliff period is incorrect");

  const airgrabTokenAddress = await airgrab.token();
  assert(airgrabTokenAddress === mentoTokenAddress, "Token address in airgrab is incorrect");

  const airgrabLockingAddress = await airgrab.locking();
  assert(airgrabLockingAddress === lockingAddress, "Locking address in airgrab is incorrect");

  const airgrabCeloCommunityFundAddress = await airgrab.celoCommunityFund();
  assert(
    airgrabCeloCommunityFundAddress === CELO_COMMUNITY_FUND,
    "Celo Community Fund address in airgrab is incorrect",
  );

  // governanceTimelock checks
  const proposerRole = await governanceTimelock.PROPOSER_ROLE();
  const executorRole = await governanceTimelock.EXECUTOR_ROLE();
  const cancellerRole = await governanceTimelock.CANCELLER_ROLE();

  assert(
    (await governanceTimelock.getMinDelay()).toString() === (2 * 24 * 60 * 60).toString(),
    "MinDelay of governanceTimelock is incorrect",
  );
  assert(
    await governanceTimelock.hasRole(proposerRole, mentoGovernorAddress),
    "governanceTimelock proposer role for mentoGovernor is incorrect",
  );
  assert(
    await governanceTimelock.hasRole(executorRole, ethers.ZeroAddress),
    "governanceTimelock executor role for address(0) is incorrect",
  );
  assert(
    await governanceTimelock.hasRole(cancellerRole, mentoGovernorAddress),
    "governanceTimelock canceller role for mentoGovernor is incorrect",
  );
  assert(
    await governanceTimelock.hasRole(cancellerRole, WATCHDOG_MULTISIG),
    "governanceTimelock canceller role for watchdogMultisig is incorrect",
  );

  // mentoLabsTreasury checks
  assert(
    (await mentoLabsTreasury.getMinDelay()).toString() === (13 * 24 * 60 * 60).toString(),
    "MinDelay of mentoLabsTreasury is incorrect",
  );
  assert(
    await mentoLabsTreasury.hasRole(proposerRole, MENTO_LABS_MULTISIG),
    "mentoLabsTreasury proposer role for mentoLabsMultisig is incorrect",
  );
  assert(
    await mentoLabsTreasury.hasRole(executorRole, ethers.ZeroAddress),
    "mentoLabsTreasury executor role for address(0) is incorrect",
  );
  assert(
    await mentoLabsTreasury.hasRole(cancellerRole, governanceTimelockAddress),
    "mentoLabsTreasury canceller role for governanceTimelockAddress is incorrect",
  );

  // mentoGovernor checks
  assert((await mentoGovernor.token()) === lockingAddress, "Token of mentoGovernor is incorrect");
  assert((await mentoGovernor.votingDelay()).toString() === "0", "Voting delay of mentoGovernor is incorrect");
  const BLOCKS_WEEK = 120_960;
  assert(
    (await mentoGovernor.votingPeriod()).toString() === BLOCKS_WEEK.toString(),
    "Voting period of mentoGovernor is incorrect",
  );
  assert(
    (await mentoGovernor.proposalThreshold()).toString() === ethers.parseEther("1000").toString(),
    "Proposal threshold of mentoGovernor is incorrect",
  );
  assert((await mentoGovernor.quorumNumerator()).toString() === "2", "Quorum numerator of mentoGovernor is incorrect");
  assert((await mentoGovernor.timelock()) === governanceTimelockAddress, "Timelock of mentoGovernor is incorrect");

  // locking checks
  assert((await locking.token()) === mentoTokenAddress, "Token of locking is incorrect");
  assert((await locking.minCliffPeriod()).toString() === "0", "Min cliff period of locking is incorrect");
  assert((await locking.minSlopePeriod()).toString() === "1", "Min slope period of locking is incorrect");
  assert((await locking.owner()) === governanceTimelockAddress, "Owner of locking is incorrect");
  assert((await locking.getWeek()).toString() === "1", "Current week of locking is incorrect");
  assert((await locking.symbol()) === "veMENTO", "Symbol of locking is incorrect");
  assert((await locking.name()) === "Mento Vote-Escrow", "Name of locking is incorrect");

  console.log("\n");
  console.log("*****************************");
  console.log("Post deployment checks passed!");
  console.log("*****************************");
  console.log("=================================================");
};

export default func;
func.tags = ["GOV_CHECK", "GOV_FORK"];
