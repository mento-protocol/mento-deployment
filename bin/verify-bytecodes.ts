import { execSync } from "node:child_process";
import fs from "node:fs";
import { parseArgs } from "node:util";
import process from "node:process";
import { providers } from "ethers";

enum Network {
  Baklava = "baklava",
  Alfajores = "alfajores",
  Celo = "celo"
}

enum Upgrade {
  MU01 = "MU01"
}

type NetworkInfo = {
  id: number;
  rpcUrl: string;
}

const networkInfoByName: Record<Network, NetworkInfo> = {
  [Network.Baklava]: {
    id: 62320,
    rpcUrl: "https://baklava-forno.celo-testnet.org",
  },
  [Network.Alfajores]: {
    id: 44787,
    rpcUrl: "https://alfajores-forno.celo-testnet.org",
  },
  [Network.Celo]: {
    id: 42220,
    rpcUrl: "https://forno.celo.org",
  },
};

const parseNetwork = (network: string | undefined): Network => {
  if (network && Object.values(Network).find((n) => n === network)) {
    return network as Network
  }
  console.error(`🚨 Invalid network ${network}`);
  process.exit(1)
}

const parseUpgrade = (upgrade: string | undefined): Upgrade => {
  if (upgrade && upgrade in Upgrade) {
    return upgrade as Upgrade
  }
  console.error(`🚨 Invalid upgrade ${upgrade}`);
  process.exit(1)
}

function getContractsForUpgrade(network: Network, upgrade: Upgrade): Map<string, string> {
  const broadcastFolders = fs
    .readdirSync("broadcast/", { withFileTypes: true })
    .filter(dirent => dirent.isDirectory())
    .filter(dirent => dirent.name.startsWith(upgrade));

  if (broadcastFolders.length === 0) {
    throw new Error(`No broadcast folders found for upgrade ${upgrade}`);
  }

  const networkId = networkInfoByName[network].id;
  const contractNameToAddress = new Map<string, string>();
  for (const folder of broadcastFolders) {
    const runFile = `broadcast/${folder.name}/${networkId}/run-latest.json`;
    if (fs.existsSync(runFile) === false) {
      console.log("ℹ️ Skipping broadcast folder", folder.name, "as it does not contain a run file for network", network);
      continue
    }
    const data = JSON.parse(fs.readFileSync(runFile, "utf8"));

    for (const transaction of data.transactions) {
      if (transaction.transactionType == "CREATE") {
        contractNameToAddress.set(transaction.contractName, transaction.contractAddress);
      }
    }
  }

  return contractNameToAddress;
}

async function getOnChainBytecode(address: string, network: Network): Promise<string> {
  const provider = new providers.JsonRpcProvider(networkInfoByName[network].rpcUrl);
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

async function main() {
  const { values } = parseArgs({
    options: {
      network: {
        type: "string",
        short: "n",
      },
      upgrade: {
        type: "string",
        short: "u",
      },
      commit: {
        type: "string",
        short: "c",
      },
    },
  });

  if (Object.keys(values).length != 3) {
    console.log("Usage: yarn run verifyBytecodes -n <network> -u <upgrade> -c <commit>");
    process.exit(1);
  }

  const network = parseNetwork(values.network);
  const upgrade = parseUpgrade(values.upgrade);
  const commit = values.commit!;

  console.log(`🎣 Checking out lib/mento-core submodule @ ${commit}...`);
  executeAndFailOnError(`git -C lib/mento-core checkout ${commit} -q`);

  console.log("🧹 Cleaning old artifacts and building new ones...");
  executeAndFailOnError(`forge clean && env FOUNDRY_PROFILE=${network}-deployment forge build`);

  console.log("\n========================================");
  console.log("🕵️  Verifying contract addresses...");

  const contractsByName: Map<string, string> = getContractsForUpgrade(network, upgrade);
  const nOfContracts = contractsByName.size;
  const tableOutput: Array<object> = [];

  let misMatches = 0;
  let checked = 0;
  for (const [contractName, contractAddress] of contractsByName) {
    checked = checked + 1;
    process.stdout.clearLine(0);
    process.stdout.cursorTo(0);
    process.stdout.write(`${contractName} (${checked}/${nOfContracts})...`);

    const onChainBytecode = await getOnChainBytecode(contractAddress, network);
    const bytecodeFromArtifacts = getBytecodeFromArtifacts(contractName);

    if (onChainBytecode === bytecodeFromArtifacts) {
      tableOutput.push({ contract: contractName, address: contractAddress, match: "✅" });
    } else {
      misMatches = misMatches + 1;
      tableOutput.push({ contract: contractName, address: contractAddress, match: "❌" });
    }
  }

  process.stdout.clearLine(0);
  console.log("\n");
  console.table(tableOutput);

  if (misMatches === 0) {
    console.log(`\nAll ${nOfContracts} contracts bytecodes match 🚀`);
  } else {
    console.log(`\nFound ${misMatches}/${nOfContracts} contracts mismatches ❌`);
  }
}

main()
  .then(() => process.exit(0))
  .catch(e => console.error("Error:", e));
