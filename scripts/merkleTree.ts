import { MerkleTree } from "merkletreejs";
import { keccak256, AbiCoder } from "ethers";
import * as fs from "fs";
import { parse } from "csv-parse/sync";

export const generateTree = async (): Promise<MerkleTree> => {
  const abicoder = new AbiCoder();
  const fileContent = fs.readFileSync("scripts/data/in/list.csv", "utf8");
  const records = parse(fileContent, {
    columns: false,
    skipEmptyLines: true,
  });

  const leaves = records.map((row: any) => {
    const encoded = abicoder.encode(["address", "uint256"], [row[0], row[1]]);
    const leafHash = keccak256(encoded);
    const leaf = keccak256(Buffer.concat([Buffer.from(leafHash.slice(2), "hex")])); // Remove '0x' and convert to Buffer
    return leaf;
  });

  const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });

  console.log("Merkle root: ", merkleTree.getHexRoot());
  console.log(merkleTree.toString());

  const treeData = {
    root: merkleTree.getHexRoot(),
    leaves: merkleTree.getHexLeaves(),
    layers: merkleTree.getHexLayers(),
  };

  fs.writeFileSync("scripts/data/out/tree.json", JSON.stringify(treeData, null, 2));

  return merkleTree;
};

generateTree();
