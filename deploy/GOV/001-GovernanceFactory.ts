import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, DeployResult } from "hardhat-deploy/types";

// Usage: `yarn deploy:<NETWORK> --tags GOV`
//          e.g. `yarn deploy:localhost --tags GOV`
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const AirgrabDeployerLib = await deployments.get("AirgrabDeployerLib");
  const EmissionDeployerLib = await deployments.get("EmissionDeployerLib");
  const LockingDeployerLib = await deployments.get("LockingDeployerLib");
  const MentoGovernorDeployerLib = await deployments.get("MentoGovernorDeployerLib");
  const MentoTokenDeployerLib = await deployments.get("MentoTokenDeployerLib");
  const TimelockControllerDeployerLib = await deployments.get("TimelockControllerDeployerLib");
  const ProxyDeployerLib = await deployments.get("ProxyDeployerLib");

  console.log("=================================================");
  console.log("*****************************");
  console.log("Deploying Governance Factory");
  console.log("*****************************");
  console.log("\n");

  const GovernanceFactory: DeployResult = await deploy("GovernanceFactory", {
    from: deployer,
    args: ["0x000000000000000000000000000000000000ce10"],
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
  console.log(" --- ");
  console.log("\n");

  console.log("=================================================");
};

export default func;
func.tags = ["GOV"];
