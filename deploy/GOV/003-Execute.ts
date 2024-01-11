import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, DeployResult } from "hardhat-deploy/types";

// Usage: `yarn deploy:<NETWORK> --tags EXE`
//          e.g. `yarn deploy:localhost --tags EXE`
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers, deployments, getNamedAccounts, getUnnamedAccounts } = hre;

  const CELO_REGISTRY = process.env.CELO_REGISTIRY_ADDRESS;
  if (!CELO_REGISTRY) {
    throw new Error("CELO_REGISTRY_ADDRESS is not set");
  }

  const celoRegistiry = await ethers.getContractAt("IRegistry", CELO_REGISTRY);
  const celoGovernanceAddress = await celoRegistiry.getAddressForStringOrDie("Governance");
  const celoGovernance = await ethers.getContractAt("ICeloGovernance", celoGovernanceAddress);

  console.log("=================================================");
  console.log("*****************************");
  console.log("Executing Celo Proposal to call createGovernance()");
  console.log("*****************************");
  console.log("\n");

  const proposalId = 192;
  const index = 99;

  // for (let i = 95; i < 110; i++) {
  //   try {
  //     const a = await celoGovernance.dequeued(i);
  //     console.log(a, i);
  //   } catch (error) {
  //     // console.log(error);
  //   }
  // }

  try {
    // const data = celoGovernance.interface.encodeFunctionData("execute", [proposalId, index]);
    // const gas = await ethers.provider.estimateGas({
    //   // Wrapped ETH address
    //   to: celoGovernance.getAddress(),
    //   // `function deposit() payable`
    //   data: data,
    //   // 1 ether
    //   value: 0,
    // });
    // console.log({ gas });
    await celoGovernance.execute(proposalId, index, { gasLimit: 25_000_000 });
  } catch (error) {
    console.log(error);
  }

  console.log("\n");
  console.log(" --- ");
  console.log("\n");

  console.log("=================================================");
};

export default func;
func.tags = ["EXE"];
