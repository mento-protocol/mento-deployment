import "dotenv/config";
import "hardhat-deploy";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-verify";

import { HardhatUserConfig } from "hardhat/config";

const accounts = [process.env.MENTO_DEPLOYER_PK || "0x00"];
const CELOSCAN_API_KEY = process.env.CELOSCAN_API_KEY;
if (!CELOSCAN_API_KEY) {
  throw new Error("CELOSCAN_API_KEY is not set");
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  networks: {
    localhost: {
      live: false,
      saveDeployments: true, // Best set to false but keeping true to illustrate features.
    },
    hardhat: {
      forking: {
        enabled: true,
        url: `https://forno.celo.org`,
      },
      allowUnlimitedContractSize: true,
      live: false,
      saveDeployments: true,
      tags: ["fork", "local"],
      hardfork: "berlin",
    },
    celo: {
      url: "https://forno.celo.org",
      chainId: 42220,
      live: true,
      accounts,
      saveDeployments: true,
    },
    alfajores: {
      url: "https://alfajores-forno.celo-testnet.org",
      chainId: 44787,
      accounts,
      live: true,
      saveDeployments: true,
    },
    baklava: {
      url: "https://baklava-forno.celo-testnet.org",
      chainId: 62320,
      accounts,
      live: true,
      saveDeployments: true,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.5.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.5.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.5.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.18",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  etherscan: {
    apiKey: {
      alfajores: CELOSCAN_API_KEY,
      baklava: CELOSCAN_API_KEY,
      celo: CELOSCAN_API_KEY,
    },
    customChains: [
      {
        network: "alfajores",
        chainId: 44787,
        urls: {
          apiURL: "https://api-alfajores.celoscan.io/api",
          browserURL: "https://alfajores.celoscan.io",
        },
      },
      {
        network: "baklava",
        chainId: 62320,
        urls: {
          apiURL: "https://explorer.celo.org/baklava/api",
          browserURL: "https://explorer.celo.org/baklava",
        },
      },
      {
        network: "celo",
        chainId: 42220,
        urls: {
          apiURL: "https://api.celoscan.io/api",
          browserURL: "https://celoscan.io/",
        },
      },
    ],
  },
  sourcify: {
    enabled: true,
  },
  paths: {
    // This value cannot be an array, so we can only compile one folder.
    // This means that contracts, such as the PartialReserveProxy, must be moved to mento-core
    // if we want to include them in the deployment.
    sources: "./lib/mento-core-gov/contracts",
  },
};

export default config;
