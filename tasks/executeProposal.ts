import { task } from "hardhat/config";

/**
 * @title Execute Celo Proposal Task
 * @dev Celo proposal to create governance is a big one and default gas limit on cli is not enough.
 * @dev This task is used to execute any proposal with a higher gas limit.
 * Usage: npx hardhat executeProposal --pid 90 --index 50 --network <NETWORK>
 */

task("executeProposal", "Executes the Celo Proposal using higher gas limit")
  .addParam("pid", "The Celo proposalId of the proposal")
  .addParam("index", "The Celo dequeued index of the proposal")
  .setAction(async (taskArgs, hre) => {
    const { ethers } = hre;
    const { pid, index } = taskArgs;

    const CELO_REGISTRY = "0x000000000000000000000000000000000000ce10";

    const celoRegistiry = await ethers.getContractAt("IRegistry", CELO_REGISTRY);
    const celoGovernanceAddress = await celoRegistiry.getAddressForStringOrDie("Governance");
    const celoGovernance = await ethers.getContractAt("ICeloGovernance", celoGovernanceAddress);

    console.log("=================================================");
    console.log("*****************************");
    console.log("Executing Celo Proposal");
    console.log("*****************************");
    console.log("\n");

    try {
      await celoGovernance.execute(pid, index, { gasLimit: 20_000_000 });
    } catch (error) {
      console.log(error);
    }
  });
