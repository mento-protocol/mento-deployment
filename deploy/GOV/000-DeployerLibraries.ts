import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, DeployResult } from "hardhat-deploy/types";

/**
 * @title Governance Libraries Deployment Script
 * @dev Deploys several libraries related to governance features in a specified network.
 * Usage: `npx hardhat deploy --network <NETWORK> --tags GOV_DEPLOY`
 */
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  console.log("=================================================");
  console.log("*****************************");
  console.log("Deploying Deployer Libraries");
  console.log("*****************************");
  console.log("\n");

  const AirgrabDeployerLib: DeployResult = await deploy("AirgrabDeployerLib", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });

  if (AirgrabDeployerLib.newlyDeployed) {
    console.log(`AirgrabDeployerLib is deployed to: ${AirgrabDeployerLib.address}`);
  } else {
    console.log("AirgrabDeployerLib already deployed at:", AirgrabDeployerLib.address);
  }

  console.log("\n");
  console.log(" --- ");
  console.log("\n");

  const EmissionDeployerLib: DeployResult = await deploy("EmissionDeployerLib", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });

  if (EmissionDeployerLib.newlyDeployed) {
    console.log(`EmissionDeployerLib is deployed to: ${EmissionDeployerLib.address}`);
  } else {
    console.log("EmissionDeployerLib already deployed at:", EmissionDeployerLib.address);
  }

  console.log("\n");
  console.log(" --- ");
  console.log("\n");

  const LockingDeployerLib: DeployResult = await deploy("LockingDeployerLib", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });

  if (LockingDeployerLib.newlyDeployed) {
    console.log(`LockingDeployerLib is deployed to: ${LockingDeployerLib.address}`);
  } else {
    console.log("LockingDeployerLib already deployed at:", LockingDeployerLib.address);
  }

  console.log("\n");
  console.log(" --- ");
  console.log("\n");

  const MentoGovernorDeployerLib: DeployResult = await deploy("MentoGovernorDeployerLib", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });

  if (MentoGovernorDeployerLib.newlyDeployed) {
    console.log(`MentoGovernorDeployerLib is deployed to: ${MentoGovernorDeployerLib.address}`);
  } else {
    console.log("MentoGovernorDeployerLib already deployed at:", MentoGovernorDeployerLib.address);
  }

  console.log("\n");
  console.log(" --- ");
  console.log("\n");

  const MentoTokenDeployerLib: DeployResult = await deploy("MentoTokenDeployerLib", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });

  if (MentoTokenDeployerLib.newlyDeployed) {
    console.log(`MentoTokenDeployerLib is deployed to: ${MentoTokenDeployerLib.address}`);
  } else {
    console.log("MentoTokenDeployerLib already deployed at:", MentoTokenDeployerLib.address);
  }

  console.log("\n");
  console.log(" --- ");
  console.log("\n");

  const TimelockControllerDeployerLib: DeployResult = await deploy("TimelockControllerDeployerLib", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });

  if (TimelockControllerDeployerLib.newlyDeployed) {
    console.log(`TimelockControllerDeployerLib is deployed to: ${TimelockControllerDeployerLib.address}`);
  } else {
    console.log("TimelockControllerDeployerLib already deployed at:", TimelockControllerDeployerLib.address);
  }

  console.log("\n");
  console.log(" --- ");
  console.log("\n");

  const ProxyDeployerLib: DeployResult = await deploy("ProxyDeployerLib", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });

  if (ProxyDeployerLib.newlyDeployed) {
    console.log(`ProxyDeployerLib is deployed to: ${ProxyDeployerLib.address}`);
  } else {
    console.log("ProxyDeployerLib already deployed at:", ProxyDeployerLib.address);
  }

  console.log("\n");
  console.log("*****************************");
  console.log("Deployer Libraries deployed successfully! ");
  console.log("*****************************");
  console.log("=================================================");
};

export default func;
func.tags = ["GOV_DEPLOY", "GOV_FORK"];
