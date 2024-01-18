import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, DeployResult } from "hardhat-deploy/types";

/**
 * @title Governance Factory Deployment Script
 * @dev Deploys the governance factory contract and links the required libraries.
 * Usage: `npx hardhat deploy --network <NETWORK> --tags GOV_DEPLOY`
 */
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers, deployments, getNamedAccounts, getChainId } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const CELO_REGISTRY = "0x000000000000000000000000000000000000ce10";

  const celoRegistry = await ethers.getContractAt("IRegistry", CELO_REGISTRY);
  const celoGovernance = await celoRegistry.getAddressForStringOrDie("Governance");

  const AirgrabDeployerLib = await deployments.get("AirgrabDeployerLib");
  const EmissionDeployerLib = await deployments.get("EmissionDeployerLib");
  const LockingDeployerLib = await deployments.get("LockingDeployerLib");
  const MentoGovernorDeployerLib = await deployments.get("MentoGovernorDeployerLib");
  const MentoTokenDeployerLib = await deployments.get("MentoTokenDeployerLib");
  const TimelockControllerDeployerLib = await deployments.get("TimelockControllerDeployerLib");
  const ProxyDeployerLib = await deployments.get("ProxyDeployerLib");

  const chainId = await getChainId();
  const owner = chainId === "31337" ? deployer : celoGovernance;

  console.log("=================================================");
  console.log("*****************************");
  console.log("Deploying Governance Factory");
  console.log("*****************************");
  console.log("\n");

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

  console.log("\n");
  console.log("*****************************");
  console.log("Governance Factory deployed successfully!");
  console.log("*****************************");
  console.log("=================================================");
};

export default func;
func.tags = ["GOV_DEPLOY", "GOV_FORK"];
