/*******************************************************************
 * Build the airgrab merkle tree for a given network
 * Usage: yarn merkle-tree:build
 *               -n <baklava|alfajores|celo> -- network to build the tree for
 *******************************************************************
 */

import { parseArgs } from "node:util";
import { MerkleTree } from "merkletreejs";
import { keccak256, AbiCoder, parseEther } from "ethers";
import * as fs from "fs";
import { parse } from "csv-parse/sync";
import assert from "assert";

interface DistributionRecord {
  Address: string;
  "MENTO based on locked CELO": string;
  "MENTO based on cStables balances": string;
  "MENTO based on cStables volumes": string;
  total_distributed: string;
}

const {
  values: { network },
} = parseArgs({
  options: {
    network: { type: "string", short: "n" },
  },
});

if (network !== "baklava" && network !== "alfajores" && network !== "celo") {
  throw new Error("Invalid network");
}

export const generateTree = async (): Promise<MerkleTree> => {
  const abicoder = new AbiCoder();
  const fileContent = fs.readFileSync(`data/airgrab.${network}.csv`, "utf8");
  const records = parse(fileContent, {
    columns: true,
    skipEmptyLines: true,
  });

  const leaves = records.map((row: DistributionRecord) => {
    const address = row.Address;
    const totalDistributed = row.total_distributed;

    const fromLockedCelo = parseFloat(row["MENTO based on locked CELO"] || "0");
    const fromStablesBalances = parseFloat(row["MENTO based on cStables balances"] || "0");
    const fromStablesVolumes = parseFloat(row["MENTO based on cStables volumes"] || "0");
    assert(
      fromLockedCelo + fromStablesBalances + fromStablesVolumes === parseFloat(totalDistributed),
      "Invalid distribution",
    );

    const encoded = abicoder.encode(["address", "uint256"], [address, parseEther(totalDistributed)]);
    const leafHash = keccak256(encoded);
    const leaf = keccak256(Buffer.concat([Buffer.from(leafHash.slice(2), "hex")])); // Remove '0x' and convert to Buffer
    return leaf;
  });

  const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });

  console.log("Merkle root: ", merkleTree.getHexRoot());

  const treeData = {
    root: merkleTree.getHexRoot(),
    leaves: merkleTree.getHexLeaves(),
    layers: merkleTree.getHexLayers(),
  };

  fs.writeFileSync(`data/airgrab.${network}.tree.json`, JSON.stringify(treeData, null, 2));

  return merkleTree;
};

generateTree();
