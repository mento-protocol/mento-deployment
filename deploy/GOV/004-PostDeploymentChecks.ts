import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, DeployResult } from "hardhat-deploy/types";
import { CodedEthersError, assert } from "ethers";

// Usage: `yarn deploy:<NETWORK> --tags GOV`
//          e.g. `yarn deploy:localhost --tags GOV`
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers, deployments, getNamedAccounts, getUnnamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const accs = await getUnnamedAccounts();

  const CELO_REGISTRY = process.env.CELO_REGISTIRY_ADDRESS;
  if (!CELO_REGISTRY) {
    throw new Error("CELO_REGISTRY_ADDRESS is not set");
  }

  const celoRegistiry = await ethers.getContractAt("IRegistry", CELO_REGISTRY);
  const celoGovernanceAddress = await celoRegistiry.getAddressForStringOrDie("Governance");
  console.log("=================================================");
  console.log("*****************************");
  console.log("Performing Post Deployment Checks");
  console.log("*****************************");
  console.log("\n");

  const GovernanceFactoryDep = await deployments.get("GovernanceFactory");
  const factory = await ethers.getContractAt("GovernanceFactory", GovernanceFactoryDep.address);
  // TODO: Update to celo governance address
  const owner = await factory.owner();
  if (owner !== deployer) {
    throw new Error("Owner of GovernanceFactory is not Celo Governance");
  }

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

  const mentoLabsMultisigBalance = await mentoToken.balanceOf(accs[4]);
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

  const emissionStartTime = await emission.emissionStartTime();
  assert(
    emissionStartTime.toString() === (await ethers.provider.getBlock("latest"))!.timestamp.toString(),
    "Emission start time is incorrect",
  );

  const emissionMentoTokenAddress = await emission.mentoToken();
  assert(emissionMentoTokenAddress === mentoTokenAddress, "MentoToken address in emission is incorrect");

  const emissionTarget = await emission.emissionTarget();
  assert(emissionTarget === governanceTimelockAddress, "Emission target address is incorrect");

  const emissionOwner = await emission.owner();
  assert(emissionOwner === governanceTimelockAddress, "Owner of emission is incorrect");

  // TODO: Update the airgrab
  const airgrabRoot = await airgrab.root();
  assert(
    airgrabRoot === "0x945d83ced94efc822fed712b4c4694b4e1129607ec5bbd2ab971bb08dca4d809",
    "Airgrab Merkle root is incorrect",
  );

  const airgrabFractalSigner = await airgrab.fractalSigner();
  assert(airgrabFractalSigner === accs[7], "Airgrab fractal signer is incorrect");

  const airgrabFractalMaxAge = await airgrab.fractalMaxAge();
  assert(airgrabFractalMaxAge.toString() === "15552000", "Airgrab fractal max age is incorrect"); // 180 days in seconds

  const airgrabEndTimestamp = await airgrab.endTimestamp();
  const expectedEndTimestamp = (await ethers.provider.getBlock("latest"))!.timestamp + 365 * 24 * 60 * 60; // 365 days in seconds
  assert(airgrabEndTimestamp.toString() === expectedEndTimestamp.toString(), "Airgrab end timestamp is incorrect");

  const airgrabSlopePeriod = await airgrab.slopePeriod();
  assert(airgrabSlopePeriod.toString() === "104", "Airgrab slope period is incorrect");

  const airgrabCliffPeriod = await airgrab.cliffPeriod();
  assert(airgrabCliffPeriod.toString() === "0", "Airgrab cliff period is incorrect");

  const airgrabTokenAddress = await airgrab.token();
  assert(airgrabTokenAddress === mentoTokenAddress, "Token address in airgrab is incorrect");

  const airgrabLockingAddress = await airgrab.locking();
  assert(airgrabLockingAddress === lockingAddress, "Locking address in airgrab is incorrect");

  const airgrabCeloCommunityFundAddress = await airgrab.celoCommunityFund();
  assert(airgrabCeloCommunityFundAddress === accs[6], "Celo Community Fund address in airgrab is incorrect");

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
    await governanceTimelock.hasRole(cancellerRole, accs[5]),
    "governanceTimelock canceller role for watchdogMultisig is incorrect",
  );

  // mentoLabsTreasury checks
  assert(
    (await mentoLabsTreasury.getMinDelay()).toString() === (13 * 24 * 60 * 60).toString(),
    "MinDelay of mentoLabsTreasury is incorrect",
  );
  assert(
    await mentoLabsTreasury.hasRole(proposerRole, accs[4]),
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

  console.log("Post deployment checks passed");
  console.log("Everything looks good!");

  console.log("=================================================");
};

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

export default func;
func.tags = ["GOV"];
