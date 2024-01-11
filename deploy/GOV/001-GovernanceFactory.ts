import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, DeployResult } from "hardhat-deploy/types";

// Usage: `yarn deploy:<NETWORK> --tags GOV`
//          e.g. `yarn deploy:localhost --tags GOV`
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers, deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const CELO_REGISTRY = process.env.CELO_REGISTIRY_ADDRESS;
  if (!CELO_REGISTRY) {
    throw new Error("CELO_REGISTRY_ADDRESS is not set");
  }
  const celoRegistiry = await ethers.getContractAt("IRegistry", CELO_REGISTRY);
  const celoGovernance = await celoRegistiry.getAddressForStringOrDie("Governance");

  const AirgrabDeployerLib = await deployments.get("AirgrabDeployerLib");
  const EmissionDeployerLib = await deployments.get("EmissionDeployerLib");
  const LockingDeployerLib = await deployments.get("LockingDeployerLib");
  const MentoGovernorDeployerLib = await deployments.get("MentoGovernorDeployerLib");
  const MentoTokenDeployerLib = await deployments.get("MentoTokenDeployerLib");
  const TimelockControllerDeployerLib = await deployments.get("TimelockControllerDeployerLib");
  const ProxyDeployerLib = await deployments.get("ProxyDeployerLib");

  const chainId = await getChainId();

  console.log("=================================================");
  console.log("*****************************");
  console.log("Deploying Governance Factory");
  console.log("*****************************");
  console.log("\n");

  const owner = chainId === "31337" ? deployer : celoGovernance;

  const GovernanceFactory: DeployResult = await deploy("GovernanceFactory", {
    from: deployer,
    args: [owner],
    log: true,
    autoMine: true,
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

  if (GovernanceFactory.newlyDeployed) {
    console.log(`GovernanceFactory is deployed to: ${GovernanceFactory.address}`);
  } else {
    console.log("GovernanceFactory already deployed at:", GovernanceFactory.address);
  }

  console.log("Verifiying GovernanceFactory on Explorer");
  await hre.run("verify:verify", {
    address: GovernanceFactory.address,
    constructorArguments: [owner],
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
  console.log(" --- ");
  console.log("\n");

  console.log("=================================================");
};

export default func;
func.tags = ["GOV"];
