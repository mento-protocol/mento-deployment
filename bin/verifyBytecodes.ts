import { execSync } from "node:child_process";
import fs from "node:fs";
import process from "node:process";
import { providers } from "ethers";

const broadcastFiles = [
  "broadcast/MU01-00-Create-Proxies.sol",
  "broadcast/MU01-01-Create-Nonupgradeable-Contracts.sol",
  "broadcast/MU01-02-Create-Implementations.sol",
];

const providerByNetworkId = {
  62320: "https://baklava-forno.celo-testnet.org",
  44787: "https://alfajores-forno.celo-testnet.org",
  42220: "https://forno.celo.org",
};

function readAddresses(addressesPath: string): string[] {
  const data = fs.readFileSync(addressesPath, "utf8");
  return data.split("\n").filter(line => line.length > 0);
}

function getKnownContracts(network: string): Map<string, string> {
  const contractAddressToName = new Map<string, string>();

  for (const file of broadcastFiles) {
    const path = `${file}/${network}/run-latest.json`;
    const data = JSON.parse(fs.readFileSync(path, "utf8"));

    for (const transaction of data.transactions) {
      if (transaction.transactionType == "CREATE") {
        contractAddressToName.set(transaction.contractAddress, transaction.contractName);
      }
    }
  }
  return contractAddressToName;
}

async function getOnChainBytecode(address: string, networkId: Number): Promise<string> {
  const provider = new providers.JsonRpcProvider(providerByNetworkId[networkId as keyof typeof providerByNetworkId]);
  return await provider.getCode(address);
}

function getBytecodeFromArtifacts(contractName: string): string {
  const artifactPath = `out/${contractName}.sol/${contractName}.json`;
  const data = JSON.parse(fs.readFileSync(artifactPath, "utf8"));

  return data.deployedBytecode.object;
}

function executeAndFailOnError(command: string) {
  try {
    execSync(command);
  } catch (error) {
    console.log(`Error executing ${command}: ${error}`);
    process.exit(1);
  }
}

async function fun() {
  if (process.argv.length != 5) {
    console.log("Usage: yarn run verifyBytecodes <networkId> <commit> <addressesFile>");
    process.exit(1);
  }

  const network = process.argv[2];
  if (!Object.keys(providerByNetworkId).includes(network)) {
    console.log(`Unknown network id: ${network}`);
    process.exit(1);
  }

  const commit = process.argv[3];
  const addressesFilePath = process.argv[4];

  const knownContracts: Map<string, string> = getKnownContracts(network);
  const addressesToVerify = readAddresses(addressesFilePath);

  for (const address of addressesToVerify) {
    if (!knownContracts.has(address)) {
      console.log(`Unknown contract address: ${address}`);
      process.exit(1);
    }
  }

  console.log(`Checking out lib/mento-core submodule @ ${commit}...`);
  executeAndFailOnError(`git -C lib/mento-core checkout ${commit} -q`);

  console.log("Cleaning old artifacts and building new ones...");
  executeAndFailOnError("forge clean && forge build");

  console.log("\n========================================");
  console.log("Verifying provided contract addresses...\n");

  let misMatches = 0;
  for (const address of addressesToVerify) {
    const contractName = knownContracts.get(address)!;

    const onChainBytecode = await getOnChainBytecode(address, parseInt(network));
    const bytecodeFromArtifacts = getBytecodeFromArtifacts(contractName);

    if (onChainBytecode === bytecodeFromArtifacts) {
      console.log(`${contractName} @ ${address} ✅`);
    } else {
      misMatches = misMatches + 1;
      console.log(`${contractName} @ ${address} ❌`);
    }
  }

  if (misMatches === 0) {
    console.log(`\nAll ${addressesToVerify.length} contracts bytecodes match 🚀`);
  } else {
    console.log(`\nFound ${misMatches}/${addressesToVerify.length} contracts mismatches ❌`);
  }
}

fun();
