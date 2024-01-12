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

  const EmissionDeployerLib = await deployments.get("EmissionDeployerLib");
  const AirgrabDeployerLib = await deployments.get("AirgrabDeployerLib");
  const LockingDeployerLib = await deployments.get("LockingDeployerLib");
  const MentoGovernorDeployerLib = await deployments.get("MentoGovernorDeployerLib");
  const MentoTokenDeployerLib = await deployments.get("MentoTokenDeployerLib");
  const TimelockControllerDeployerLib = await deployments.get("TimelockControllerDeployerLib");
  const ProxyDeployerLib = await deployments.get("ProxyDeployerLib");
  const GovernanceFactory = await deployments.get("GovernanceFactory");

  const factory = await ethers.getContractAt("GovernanceFactory", GovernanceFactory.address);
  const proxyAdminAddress = await factory.proxyAdmin();
  const proxyAdmin = await ethers.getContractAt("ProxyAdmin", proxyAdminAddress);
  const mentoToken = await factory.mentoToken();
  const mentoLabsTreasuryTimelock = await factory.mentoLabsTreasuryTimelock();
  const mentoLabsMultiSig = await factory.mentoLabsMultiSig();
  const governanceTimelock = await factory.governanceTimelock();
  const mentoGovernor = await factory.mentoGovernor();
  const locking = await factory.locking();
  const airgrab = await factory.airgrab();
  const emission = await factory.emission();

  const airgrabEnds = await factory.airgrabEnds();
  const fractalMaxAge = await factory.FRACTAL_MAX_AGE();
  const lockCliff = await factory.AIRGRAB_LOCK_CLIFF();
  const lockSlope = await factory.AIRGRAB_LOCK_SLOPE();

  console.log("=================================================");
  console.log("*****************************");
  console.log("Verifying Governance Contracts");
  console.log("*****************************");
  console.log("\n");

  console.log("Verifiying EmissionDeployerLib on Explorer");
  await hre.run("verify:verify", {
    address: EmissionDeployerLib.address,
    constructorArguments: [],
  });
  console.log("\n");
  console.log("Verifiying AirgrabDeployerLib on Explorer");
  await hre.run("verify:verify", {
    address: AirgrabDeployerLib.address,
    constructorArguments: [],
  });
  console.log("\n");
  console.log("Verifiying LockingDeployerLib on Explorer");
  await hre.run("verify:verify", {
    address: LockingDeployerLib.address,
    constructorArguments: [],
  });
  console.log("\n");
  console.log("Verifiying MentoGovernorDeployerLib on Explorer");
  await hre.run("verify:verify", {
    address: MentoGovernorDeployerLib.address,
    constructorArguments: [],
  });
  console.log("\n");
  console.log("Verifiying MentoTokenDeployerLib on Explorer");
  await hre.run("verify:verify", {
    address: MentoTokenDeployerLib.address,
    constructorArguments: [],
  });
  console.log("\n");
  console.log("Verifiying TimelockControllerDeployerLib on Explorer");
  await hre.run("verify:verify", {
    address: TimelockControllerDeployerLib.address,
    constructorArguments: [],
  });
  console.log("\n");
  console.log("Verifiying ProxyDeployerLib on Explorer");
  await hre.run("verify:verify", {
    address: ProxyDeployerLib.address,
    constructorArguments: [],
  });

  console.log("\n");
  console.log("Verifiying Governance Factory on Explorer");
  await hre.run("verify:verify", {
    address: GovernanceFactory.address,
    constructorArguments: [celoGovernanceAddress],
    libraries: {
      AirgrabDeployerLib: AirgrabDeployerLib.address,
      EmissionDeployerLib: EmissionDeployerLib.address,
      LockingDeployerLib: LockingDeployerLib.address,
      MentoGovernorDeployerLib: MentoGovernorDeployerLib.address,
      MentoTokenDeployerLib: MentoTokenDeployerLib.address,
      TimelockControllerDeployerLib: TimelockControllerDeployerLib.address,
      ProxyDeployerLib: ProxyDeployerLib.address,
    },
  });
  console.log("\n");
  console.log("Verifiying Proxy Admin on Explorer");
  await hre.run("verify:verify", {
    address: proxyAdminAddress,
    constructorArguments: [],
  });
  console.log("\n");
  console.log("Verifiying Mento Token on Explorer");
  await hre.run("verify:verify", {
    address: mentoToken,
    constructorArguments: [mentoLabsMultiSig, mentoLabsTreasuryTimelock, airgrab, governanceTimelock, emission],
  });
  console.log("\n");
  console.log("Verifiying Emission on Explorer");
  await hre.run("verify:verify", {
    address: emission,
    constructorArguments: [mentoToken, governanceTimelock],
  });
  console.log("\n");
  console.log("Verifiying Airgrab on Explorer");
  await hre.run("verify:verify", {
    address: airgrab,
    constructorArguments: [
      merkleRoot,
      FRAKTAL_SIGNER,
      fractalMaxAge,
      airgrabEnds,
      lockCliff,
      lockSlope,
      mentoToken,
      locking,
      CELO_COMMUNITY_FUND,
    ],
  });

  const mentoLabsTreasuryTimelockImp = await proxyAdmin.getProxyImplementation(mentoLabsTreasuryTimelock);
  console.log("\n");
  console.log("Verifiying MentoLabs Treasury Timelock  on Explorer");
  await hre.run("verify:verify", {
    address: mentoLabsTreasuryTimelockImp,
    constructorArguments: [],
  });

  const mentoGovernorImp = await proxyAdmin.getProxyImplementation(mentoGovernor);
  console.log("\n");
  console.log("Verifiying Mento Governor on Explorer");
  await hre.run("verify:verify", {
    address: mentoGovernorImp,
    constructorArguments: [],
  });

  const governanceTimelockImp = await proxyAdmin.getProxyImplementation(governanceTimelock);
  console.log("\n");
  console.log("Verifiying Governance Timelock  on Explorer");
  await hre.run("verify:verify", {
    address: governanceTimelockImp,
    constructorArguments: [],
  });

  const lockingImp = await proxyAdmin.getProxyImplementation(locking);
  console.log("\n");
  console.log("Verifiying Locking on Explorer");
  await hre.run("verify:verify", {
    address: lockingImp,
    constructorArguments: [],
  });

  console.log("Contract Verification completed");
  console.log("=================================================");
};

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

export default func;
func.tags = ["GOV_VERIFY"];
