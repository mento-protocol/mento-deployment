import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { BigNumberish } from "ethers";
import { ICeloGovernance } from "../../artifacts/types";
import * as fs from "fs";

// Usage: `yarn deploy:<NETWORK> --tags GOV`
//          e.g. `yarn deploy:localhost --tags GOV`

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
    console.log("Error during json parsing");
    console.log("Error: ", error);
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
  console.log(" --- ");
  console.log("\n");

  console.log("=================================================");
};

type Transaction = {
  value: BigNumberish;
  destination: string;
  data: string;
};

type SerializedTransactions = {
  values: BigNumberish[];
  destinations: string[];
  data: string;
  dataLengths: number[];
};

async function createProposal(
  transactions: Transaction[],
  descriptionURL: string,
  celoGovernance: ICeloGovernance,
): Promise<void> {
  const serTxs = serializeTransactions(transactions);

  const depositAmount = await celoGovernance.minDeposit();
  console.log("Celo governance proposal required deposit amount: ", depositAmount.toString());

  const tx = await celoGovernance.propose(
    serTxs.values,
    serTxs.destinations,
    serTxs.data,
    serTxs.dataLengths,
    descriptionURL,
    { value: depositAmount },
  );

  const receipt = await tx.wait();
  if (!receipt || !receipt.status) {
    console.log("Transaction failed:", receipt);
    throw new Error("Failed to create proposal");
  }
  const hexId = receipt!.logs[0].topics[1];
  console.log("Proposal was successfully created. ID: ", parseInt(hexId, 16));
}

function serializeTransactions(transactions: Transaction[]): SerializedTransactions {
  const values: BigNumberish[] = [];
  const destinations: string[] = [];
  let dataConcatenated: string = "0x";
  const dataLengths: number[] = [];

  for (const transaction of transactions) {
    values.push(transaction.value);
    destinations.push(transaction.destination);

    // Append the encoded data to the dataConcatenated string
    dataConcatenated += transaction.data.slice(2); // Remove the '0x' prefix
    dataLengths.push(getByteLength(transaction.data));
  }

  return {
    values,
    destinations,
    data: dataConcatenated,
    dataLengths,
  };
}

function getByteLength(hexString: string): number {
  // Remove the '0x' prefix and divide by 2 (since 2 hex characters represent 1 byte)
  return (hexString.startsWith("0x") ? hexString.slice(2) : hexString).length / 2;
}

function verifyDescription(descriptionURL: string): void {
  const requiredPrefix = "https://";

  if (!descriptionURL.startsWith(requiredPrefix)) {
    throw new Error("Description URL must start with https://");
  }
}

export default func;
func.tags = ["GOV_DEPLOY", "GOV_LOCAL"];
