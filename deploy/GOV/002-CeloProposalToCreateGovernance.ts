import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { BigNumberish } from "ethers";
import { ICeloGovernance } from "../../artifacts/types";

// Usage: `yarn deploy:<NETWORK> --tags GOV`
//          e.g. `yarn deploy:localhost --tags GOV`

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers, deployments, getNamedAccounts } = hre;

  const CELO_REGISTRY = process.env.CELO_REGISTIRY_ADDRESS;
  if (!CELO_REGISTRY) {
    throw new Error("CELO_REGISTRY_ADDRESS is not set");
  }
  const celoRegistiry = await ethers.getContractAt("IRegistry", CELO_REGISTRY);
  const celoGovernanceAddress = await celoRegistiry.getAddressForStringOrDie("Governance");
  const celoGovernance = await ethers.getContractAt("ICeloGovernance", celoGovernanceAddress);

  const governanceFactoryDep = await deployments.get("GovernanceFactory");
  const governanceFactory = await ethers.getContractAt("GovernanceFactory", governanceFactoryDep.address);

  const mentoLabsMultisig = "0xfCf982bb4015852e706100B14E21f947a5Bb718E";
  const watchdogMultisig = "0xfCf982bb4015852e706100B14E21f947a5Bb718E";
  const celoCommunityFund = "0xfCf982bb4015852e706100B14E21f947a5Bb718E";
  const merkleRoot = "0x945d83ced94efc822fed712b4c4694b4e1129607ec5bbd2ab971bb08dca4d809";
  const fraktalSigner = "0xfCf982bb4015852e706100B14E21f947a5Bb718E";

  console.log("=================================================");
  console.log("*****************************");
  console.log("Creating Celo Proposal to call createGovernance()");
  console.log("*****************************");
  console.log("\n");

  // try {
  //   const own = await governanceFactory.owner();

  //   console.log({ own });
  //   await governanceFactory.createGovernance(
  //     mentoLabsMultisig,
  //     watchdogMultisig,
  //     celoCommunityFund,
  //     merkleRoot,
  //     fraktalSigner,
  //     { gasLimit: 25_000_000 },
  //   );
  // } catch (error) {
  //   console.log("Error: ", error);
  // }

  const data = governanceFactory.interface.encodeFunctionData("createGovernance", [
    mentoLabsMultisig,
    watchdogMultisig,
    celoCommunityFund,
    merkleRoot,
    fraktalSigner,
  ]);

  // const gas = await ethers.provider.estimateGas({
  //   // Wrapped ETH address
  //   to: governanceFactory.getAddress(),

  //   // `function deposit() payable`
  //   data: data,

  //   // 1 ether
  //   value: 0,
  // });
  // console.log({ gas });

  const createGovernanceTX: Transaction = {
    value: 0n,
    destination: governanceFactoryDep.address,
    data,
  };

  await createProposal([createGovernanceTX], "https://www.google.com", celoGovernance);

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

  console.log("Proposal was successfully created. ID: ", receipt!.logs[0].topics[1]);
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
func.tags = ["GOV", "GOV_CREATE"];
