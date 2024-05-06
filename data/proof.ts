import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import treeJson from "./airgrab.alfajores.tree.json";
// import * as Sentry from "@sentry/nextjs";
export type AllocationMap = { [key: string]: string };
// import { getAddress } from "viem";

let tree: StandardMerkleTree<any[]> | null = null;

const MerkleTreeError = new Error(
  `Error: Failed to load merkle tree. Make sure tree.json is present in the src/lib/merkle directory.`,
);

function loadTree() {
  if (!tree) {
    try {
      tree = StandardMerkleTree.load(JSON.parse(JSON.stringify(treeJson)));
    } catch (err) {
      throw MerkleTreeError;
    }
  } else {
    return tree;
  }
}

export function getTree(): StandardMerkleTree<any[]> | null {
  return tree;
}

export function getAllocationList(tree: StandardMerkleTree<any[]> | null): AllocationMap {
  try {
    if (!tree) throw new Error("Tree not found");

    const allocationObject: AllocationMap = {};
    for (let [, [address, allocation]] of tree.entries()) {
      allocationObject[address] = allocation;
    }

    return allocationObject;
  } catch (err) {
    throw MerkleTreeError;
  }
}

export function getProofForAddress(address: string, tree: StandardMerkleTree<any[]> | null): string[] | undefined {
  if (!tree) throw new Error("Tree not found");
  try {
    let proof;
    for (const [i, v] of tree.entries()) {
      if (v[0].toLowerCase() === address.toLowerCase()) {
        proof = tree.getProof(i);
        break;
      }
    }
    return proof;
  } catch (err) {
    // Sentry.captureException(err);
    throw MerkleTreeError;
  }
}

export const getAllocationForAddress = (address: string): string | undefined => {
  // Get the checksummed address
  const searchAddress = address; //getAddress(address);

  // Get the allocation for the address
  const allocation = getAllocationList(getTree())[searchAddress];

  //   Sentry.captureEvent({
  //     message: `Got allocation for address from merkle tree`,
  //     level: "info",
  //     extra: {
  //       Account: searchAddress,
  //       Allocation: !allocation ? "0" : allocation,
  //     },
  //   });
  return allocation;
};

// Intialize tree - load into memory on import
loadTree();
console.log(getAllocationForAddress("0x12860B283318bb73195F22C54d88f094aFc3DF1a"));
console.log(getProofForAddress("0x12860B283318bb73195F22C54d88f094aFc3DF1a", tree));
