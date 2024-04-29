/*******************************************************************
 * Build the airgrab merkle tree for a given network
 * Usage: yarn merkle-tree:build
 *               -n <baklava|alfajores|celo> -- network to build the tree for
 *******************************************************************
 */

import { parseArgs } from "node:util";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
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

export const generateTree = async (): Promise<any> => {
  const snapshot = parse(fs.readFileSync(`data/airgrab.${network}.csv`, "utf8"), {
    columns: false,
  });

  const tree = StandardMerkleTree.of(snapshot, ["address", "uint256"]);
  console.log("Number of records in snapshot:", snapshot.length);
  console.log("Root:", tree.root);

  fs.writeFileSync(`data/airgrab.${network}.tree.json`, JSON.stringify(tree.dump()));
  fs.writeFileSync(`data/airgrab.${network}.root.json`, JSON.stringify({ root: tree.root }));

  return tree;
};

generateTree();
