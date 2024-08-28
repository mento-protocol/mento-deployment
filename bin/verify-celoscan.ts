/*******************************************************************
 * Verify contracts deployed from a broadcast file on celoscan
 * Will only work with alfajores or mainnet broadcast files as
 * celoscan doesn't support baklava.
 * Command assumes that the contracts are verified on sourcify
 * automatically by foundry.
 * Usage: yarn verify:celoscan <path-to-broadcast-file>
 *******************************************************************/

import { parseArgs } from "node:util";
import fs from "fs";
import * as sourcify from "./utils/sourcify";
import * as etherscan from "./utils/etherscan";
import { Metadata } from "./utils/sourcify";
import { VerificationStatus } from "./utils/etherscan";
import "dotenv/config";
import { keccak256, toUtf8Bytes } from "ethers";

type Sources = Record<string, { content: string }>;

interface BroadcastFile {
  transactions: Array<{
    transactionType: string;
    contractAddress: string;
    additionalContracts: Array<{
      transactionType: string;
      address: string;
      initCode: string;
    }>;
    transaction: {
      data?: string;
      input?: string
    };
  }>;
  chain: number;
}

const {
  positionals,
  values: { contract: filterContracts },
} = parseArgs({
  options: {
    contract: { type: "string", multiple: true, short: "c" },
  },
  allowPositionals: true,
});
const broadcastFile = positionals[0];
if (broadcastFile === undefined) {
  console.error("🚨 Missing path to broadcast file");
  process.exit(1);
}

const fileContent = fs.readFileSync(broadcastFile, "utf8");
const broadcast = JSON.parse(fileContent) as BroadcastFile;

if (!process.env.CELOSCAN_API_KEY) {
  console.error("🚨 Missing CELOSCAN_API_KEY environment variable");
  process.exit(1);
}

const celoscanApiKey = process.env.CELOSCAN_API_KEY;

let chain: "alfajores" | "celo" | null = null;
let celoscanApiUrl: string;
if (broadcast.chain == 44787) {
  chain = "alfajores";
  celoscanApiUrl = "https://api-alfajores.celoscan.io/api";
} else if (broadcast.chain == 42220) {
  chain = "celo";
  celoscanApiUrl = "https://api.celoscan.io/api";
} else {
  console.error("🚨 Unsupported chain");
  process.exit(1);
}

console.log(`Verifying contracts from ${broadcastFile} on ${chain} celoscan...`);

async function run() {
  const contracts = broadcast.transactions
    .map(tx => {
      let createdContracts = [];
      if (tx.transactionType === "CREATE") {
        createdContracts.push({
          contract: tx.contractAddress,
          initCode: tx.transaction.data || tx.transaction.input
        });
      }
      if (tx.additionalContracts && tx.additionalContracts.length > 0) {
        createdContracts = createdContracts.concat(
          tx.additionalContracts.map(c => ({
            contract: c.address,
            initCode: c.initCode,
          })),
        );
      }
      return createdContracts;
    })
    .flat();

  console.log(`Verifying ${contracts.length} contracts...`);
  const successful = [];
  const error = [];
  for (const contract of contracts) {
    if (filterContracts && !filterContracts.includes(contract.contract)) {
      console.log("Skipping: ", contract.contract);
      continue;
    }
    const verified = await verify(contract);
    if (verified) {
      successful.push(contract.contract);
    } else {
      error.push(contract.contract);
    }
  }

  if (successful.length > 0) {
    console.log(`✅ ${successful.length} contracts are verified:`);
    for (const contract of successful) {
      console.log(" - ", contract);
    }
  }

  if (error.length > 0) {
    console.log(`🚨 Failed to verify ${error.length} contracts`);
    for (const contract of error) {
      console.log(" - ", contract);
    }
    console.log(
      "Note: Celoscan doesn't allow you to verify conracts that are identified as equivalent " +
      "bytecode-wise with other contracts. So check the list above on Celoscan to see if they " +
      "fall under this scenario.",
    );
  }
}

async function verify({ contract, initCode }: { contract: string; initCode?: string }) {
  const isVerified = await etherscan.check({
    api: celoscanApiUrl,
    apiKey: celoscanApiKey,
    contract: contract,
  })
  if (isVerified) {
    console.log(`✅ Contract ${contract} verified on celoscan`);
    return true;
  }

  const status = await sourcify.check(broadcast.chain, contract);
  if (!(status == "partial" || status == "full")) {
    console.error(`🚨 Contract ${contract} not found on sourcify`);
    return false;
  }

  console.log(`⌛ Contract ${contract} verified on sourcify, pushing to celoscan...`);
  const files = await sourcify.files(broadcast.chain, contract);
  const {
    target,
    version,
    metadata,
    sources,
    constructorArgs: constructorArgsFromSourcify,
    libraryMap,
  } = sourcify.parseFiles(files);
  const standardJson = makeStandardJson(metadata, sources, libraryMap);

  let constructorArgs = constructorArgsFromSourcify;
  if (constructorArgs === "" && !!initCode) {
    constructorArgs = getConstructorArgs(target, contract, initCode);
  }

  const guid = await etherscan.verify({
    api: celoscanApiUrl,
    apiKey: celoscanApiKey,
    contract: contract,
    source: standardJson,
    target,
    version,
    args: constructorArgs,
  });

  if (guid === VerificationStatus.ALREADY_VERIFIED) {
    console.log("✅ Contract is already verified on Celoscan");
    return true;
  }

  console.log(`⌛ Waiting for the verification job ${guid} to complete`);

  const result = await etherscan.waitFor(celoscanApiUrl, celoscanApiKey, guid);

  if (result === VerificationStatus.SUCCESS) {
    console.log("✅ Successfully verified contract on Celoscan :)");
    return true;
  } else {
    console.error("🚨 Failed to verify :(");
    fs.writeFileSync(`out/${contract}.metadata.json`, JSON.stringify(standardJson));
    console.log(`Wrote metadata to out/${contract}.metadata.json`);
    return false;
  }
}

function getConstructorArgs(target: string, contract: string, initCode: string) {
  // Target can be of the form "filename.sol:ContractName" or just "ContractName.sol"
  // This regexp matches ((...).sol):(...) so:
  //   match[1] is the filename, i.e. the first larger bracket
  //   match[2] is the filename without termination
  //   match[3] is the optional contract name which can be empty
  const match = /(([^\/]*).sol):?(.*)?/.exec(target);
  if (!match) throw Error(`Error extracting filename and contract from: ${target}`)
  const solidityFile = match[1]
  const contractName = match[3] || match[2];

  try {
    const foundryJson = JSON.parse(fs.readFileSync(`out/${solidityFile}/${contractName}.json`, "utf8"));
    let bytecode = foundryJson.bytecode.object;
    if (initCode.length < bytecode.length) {
      console.error("🚨 contract creation data is shorter than bytecode, something is off");
      return "";
    }
    if (initCode.length == bytecode.length) {
      console.error(" -- contract creation data is equal to bytecode, assuming no constructor args");
      return "";
    } else {
      console.log(" -- contract creation data is longer than bytecode, assuming constructor args");
      const diff = initCode.slice(bytecode.length);
      console.log(" -- constructor args: ", diff);
      return diff;
    }
  } catch (e) {
    console.error(e);
    console.error("🚨 Failed to find constructor args for ", contract);
    return "";
  }
}

function makeStandardJson(metadata: Metadata, sources: Sources, libraryMap: Record<string, string> = {}) {
  const libraryNames = Object.keys(metadata.settings.libraries);
  const baseLibraries = libraryNames.reduce<Record<string, Record<string, string>>>((acc, name) => {
    const [source, library] = name.split(":");
    acc[source] = { [library]: metadata.settings.libraries[name] };
    return acc;
  }, {});

  return {
    language: metadata.language,
    sources,
    settings: {
      viaIR: true,
      metadata: {
        appendCBOR: true,
        bytecodeHash: "none",
        useLiteralContent: true,
      },
      optimizer: metadata.settings.optimizer,
      evmVersion: metadata.settings.evmVersion,
      remappings: metadata.settings.remappings,
      libraries: Object.entries(sources).reduce<Record<string, any>>((libraries, [sourceKey, source]) => {
        const matches = /library ([^\s]+)/g.exec(source.content);

        if (matches == null) {
          return libraries;
        }

        const library = matches[1];

        const fullyQualifiedLibrary = sourceKey + ":" + library;
        const identifier = "__$" + keccak256(toUtf8Bytes(fullyQualifiedLibrary)).slice(2, 36) + "$__";
        const address = libraryMap[identifier];
        if (address) {
          libraries[sourceKey] = {
            [library]: `0x${address}`,
          };
        }
        return libraries;
      }, baseLibraries),
    },
  };
}

run().catch(console.error);
