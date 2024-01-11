import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, DeployResult } from "hardhat-deploy/types";
import * as fs from "fs";
// Usage: `yarn deploy:<NETWORK> --tags CHECK`
//          e.g. `yarn deploy:localhost --tags CHECK`
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers, deployments, getChainId } = hre;

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
    console.log("Error during json parsing");
    console.log("Error: ", error);
  }

  const celoRegistiry = await ethers.getContractAt("IRegistry", CELO_REGISTRY);
  const celoGovernanceAddress = await celoRegistiry.getAddressForStringOrDie("Governance");

  const chainId = await getChainId();

  console.log("=================================================");
  console.log("*****************************");
  console.log("Verifying Governance Contracts");
  console.log("*****************************");
  console.log("\n");

  const GovernanceFactoryDep = await deployments.get("GovernanceFactory");
  const factory = await ethers.getContractAt("GovernanceFactory", GovernanceFactoryDep.address);

  const mentoToken = await factory.mentoToken();
  const mentoLabsTreasuryTimelock = await factory.mentoLabsTreasuryTimelock();
  const mentoLabsMultiSig = await factory.mentoLabsMultiSig();
  const governanceTimelock = await factory.governanceTimelock();
  const mentoGovernor = await factory.mentoGovernor();
  const locking = await factory.locking();
  const airgrab = await factory.airgrab();
  const emission = await factory.emission();

  console.log("Verifiying Mento Token on Explorer");
  await hre.run("verify:verify", {
    address: mentoToken,
    constructorArguments: [mentoLabsMultiSig, mentoLabsTreasuryTimelock, airgrab, governanceTimelock, emission],
  });

  console.log("Verifiying Emission on Explorer");
  await hre.run("verify:verify", {
    address: emission,
    constructorArguments: [mentoToken, governanceTimelock],
  });

  // TODO: update airgrab ends
  // const airgrabEnds =
  // const fractalMaxAge = await factory.FRACTAL_MAX_AGE();
  // const lockCliff = await factory.AIRGRAB_LOCK_CLIFF();
  // const lockSlope = await factory.AIRGRAB_LOCK_SLOPE();

  // console.log("Verifiying Airgrab on Explorer");
  // await hre.run("verify:verify", {
  //   address: airgrab,
  //   constructorArguments: [merkleRoot, FRAKTAL_SIGNER, fractalMaxAge, airgrabEnds, lockCliff, lockSlope, mentoToken],
  // });

  console.log("Contract Verification completed");

  console.log("=================================================");
};

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

export default func;
func.tags = ["CHECKA"];
