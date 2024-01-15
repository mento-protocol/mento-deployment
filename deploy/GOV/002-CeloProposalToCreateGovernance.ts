import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { BigNumberish } from "ethers";
import { ICeloGovernance } from "../../artifacts/types";
import * as fs from "fs";
import { Transaction, createProposal } from "../utils";

/**
 * @title Celo Proposal Creation
 * @dev Creates a proposal on Celo governance to call createGovernance() on the governance factory.
 * @dev On localhost, the deployment is executed directly.
 * Usage: `npx hardhat deploy --network <NETWORK> --tags GOV_DEPLOY`
 */
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
  const celoRegistiry = await ethers.getContractAt("IRegistry", CELO_REGISTRY);
  const celoGovernanceAddress = await celoRegistiry.getAddressForStringOrDie("Governance");
  const celoGovernance = await ethers.getContractAt("ICeloGovernance", celoGovernanceAddress);

  const governanceFactoryDep = await deployments.get("GovernanceFactory");
  const governanceFactory = await ethers.getContractAt("GovernanceFactory", governanceFactoryDep.address);

  const chainId = await getChainId();
  let merkleRoot;

  try {
    const treeData = JSON.parse(fs.readFileSync("scripts/data/out/tree.json", "utf8"));
    merkleRoot = treeData.root;
  } catch (error) {
    console.log({ error });
    throw new Error("Error during json parsing");
  }

  console.log("=================================================");
  console.log("*****************************");
  console.log("Creating Celo Proposal to call createGovernance()");
  console.log("*****************************");
  console.log("\n");

  const data = governanceFactory.interface.encodeFunctionData("createGovernance", [
    MENTO_LABS_MULTISIG,
    WATCHDOG_MULTISIG,
    CELO_COMMUNITY_FUND,
    merkleRoot,
    FRAKTAL_SIGNER,
  ]);

  if (chainId === "31337") {
    console.log("Skipping proposal creation on localhost");
    console.log("createGovernance() will be called directly");
    try {
      await governanceFactory.createGovernance(
        MENTO_LABS_MULTISIG,
        WATCHDOG_MULTISIG,
        CELO_COMMUNITY_FUND,
        merkleRoot,
        FRAKTAL_SIGNER,
        { gasLimit: 20_000_000 },
      );
      console.log(`Governance is sucessfully created for factory at: ${governanceFactoryDep.address}`);
    } catch (error) {
      console.log("Error: ", error);
    }
  } else {
    const createGovernanceTX: Transaction = {
      value: 0n,
      destination: governanceFactoryDep.address,
      data,
    };

    await createProposal([createGovernanceTX], "https://www.google.com", celoGovernance);
  }

  console.log("\n");
  console.log("*****************************");
  console.log("Celo Proposal is created successfully!");
  console.log("*****************************");
  console.log("=================================================");
};

export default func;
func.tags = ["GOV_DEPLOY", "GOV_FORK"];
