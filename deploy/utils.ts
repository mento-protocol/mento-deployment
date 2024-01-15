import { BigNumberish } from "ethers";
import { ICeloGovernance } from "../artifacts/types";

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
  verifyDescription(descriptionURL);

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
function assert(condition: boolean, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}
export {
  Transaction,
  SerializedTransactions,
  createProposal,
  serializeTransactions,
  getByteLength,
  verifyDescription,
  assert,
};
