/*******************************************************************
 * Build the airgrab merkle tree for a given network
 * Usage: yarn merkle-tree:build
 *               -n <baklava|alfajores|celo> -- network to build the tree for
 *******************************************************************
 */

import { parseArgs } from "node:util";
import { MerkleTree } from "merkletreejs";
import { keccak256, AbiCoder } from "ethers";
import * as fs from "fs";
import { parse } from "csv-parse/sync";

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
    columns: false,
    skipEmptyLines: true,
  });

  console.log("Records: ", records.length);

  const leaves = records.map((row: any) => {
    const encoded = abicoder.encode(["address", "uint256"], [row[0], row[1]]);
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
