/*******************************************************************
 * One-off script used to reproduce the mainned Mento Governance
 * deployment broadcast files. This was needed because two things
 * happened in quick succession:
 * (1) Bogdan didn't commit the broadcast files to git
 * (2) Bogdan's laptop died and he lost all the data
 *
 * This script uses QuickNode's tracing to reconstruct minimal
 * broadcast files for the contract creations and governance
 * execution.
 *******************************************************************/

import { Core } from '@quicknode/sdk'
import fs from "node:fs"
import "dotenv/config";

const QUICKNODE_URL = process.env.QUICKNODE_URL!

const CGP_EXECUTION_TX = "0x0e77668a41d618030e61abe91dc2bd5ff17e2c2b27736f6f91f61b8688034f66"

const core = new Core({
  endpointUrl: QUICKNODE_URL
})

// Extracted from CeloScan:
const deploymentTransactions: Array<{ contractName: string, txHash: string, arguments: string[] | null }> = [
  {
    contractName: "GovernanceFactory",
    txHash: "0x3fc1a40a09b2e5aab3ced201e083a3b963a50e42f601679b843b3dd343644da0",
    arguments: [
      "0xD533Ca259b330c7A88f74E000a3FaEa2d63B7972"
    ],
  },
  {
    contractName: "AigrabDeployerLib",
    txHash: "0xe879a0aaa0f85bcb62337ca4974c2416d069ef24825d8d5fc708bfd995b76cee",
    arguments: null
  },
  {
    contractName: "EmissionDeployerLib",
    txHash: "0x623bdcb1cd7f8bf1205399df6566008ff767945f6c862f6ce86dc6341d966219",
    arguments: null
  },
  {
    contractName: "LockingDeployerLib",
    txHash: "0xa899cc83486b8ba4da4e6fbaa8eeb5468c07c03fb736f7460c705865456798de",
    arguments: null
  },
  {
    contractName: "MentoGovernorDeployerLib",
    txHash: "0xc9ac93ddf2eb364067891ca31244f10b3e0cdb3a94b821b55ef4281c88bb9d00",
    arguments: null
  },
  {
    contractName: "MentoTokenDeployerLib",
    txHash: "0x73f07f462e599b6e2051bbe7fd807090c41cf519d8de619fc17e0e9165af9981",
    arguments: null
  },
  {
    contractName: "ProxyDeployerLib",
    txHash: "0x446e79b9693a02c8caeecb1990326d7d321494a6fe940f99d1ce0e30dd66771b",
    arguments: null
  },
  {
    contractName: "TimelockControllerDeployerLib",
    txHash: "0x1f362b24a1ab01c327fe8d9c33a3016f020348846b1588268cf54e05f125ea1a",
    arguments: null
  }
]

type Output = {
  transactions: Array<{
    hash: string,
    transactionType: string,
    contractName: string | null,
    contractAddress: string,
    function: null,
    arguments: Array<string> | null,
    transaction: {
      type: string,
      from: string,
      gas: string,
      value: string,
      data: string,
      nonce: string
    },
    additionalContracts?: Array<{
      transactionType: "CREATE",
      address: string,
      initCode: string
    }>,
    isFixedGasLimit: boolean
  }>,
  receipts: Array<{
    transactionHash: string,
    transactionIndex: string,
    blockHash: string,
    blockNumber: string,
    from: string,
    to: string | null,
    cumulativeGasUsed: string,
    gasUsed: string,
    contractAddress: string
    logs: Array<any>
    status: string,
    logsBloom: string,
    type: string,
    effectiveGasPrice: string
  }>
  libraries: string[],
  pending: [],
  returns: {},
  timestamp: number,
  chain: number,
  commit: string
}

async function fetchCallTrace(txHash: string) {
  const headers = new Headers();
  headers.append("Content-Type", "application/json");

  var raw = JSON.stringify({
    "method": "debug_traceTransaction",
    "params": [
      txHash,
      {
        "tracer": "callTracer"
      }
    ],
    "id": 1,
    "jsonrpc": "2.0"
  });

  const resp = await fetch(QUICKNODE_URL, {
    headers,
    method: "POST",
    body: raw,
    redirect: "follow"
  })

  return resp.json()
}

async function generate_MUGOV_Create_Factory() {
  const traces = await Promise.all(deploymentTransactions.map(({ txHash }) => fetchCallTrace(txHash)))

  const transactions: Output["transactions"] = await Promise.all(deploymentTransactions.map(async (dt, index) => {
    const trace = traces[index];
    // @ts-ignore
    const tx = await core.client.getTransaction({
      hash: dt.txHash
    })

    const entry = {
      hash: dt.txHash,
      transactionType: trace["result"]["type"],
      contractName: dt.contractName,
      contractAddress: trace["result"]["to"],
      function: null,
      arguments: dt.arguments,
      transaction: {
        type: tx["typeHex"],
        from: tx["from"],
        gas: `0x${tx["gas"].toString(16)}`,
        value: `0x${tx["value"].toString(16)}`,
        data: trace["result"]["input"],
        nonce: tx["nonce"]
      },
      isFixedGasLimit: false
    }
    return entry
  }))


  const receipts: Output["receipts"] = await Promise.all(deploymentTransactions.map(async (dt) => {
    // @ts-ignore
    const receipt = await core.client.getTransactionReceipt({ hash: dt.txHash })
    return {
      ...receipt,
      blockNumber: `0x${receipt["blockNumber"].toString(16)}`,
      cumulativeGasUsed: `0x${receipt["cumulativeGasUsed"].toString(16)}`,
      effectiveGasPrice: `0x${receipt["effectiveGasPrice"].toString(16)}`,
      gasUsed: `0x${receipt["gasUsed"].toString(16)}`,
      logs: receipt["logs"].map((log: any) => ({
        ...log,
        blockNumber: `0x${log["blockNumber"].toString(16)}`,
      }))
    }
  }))

  console.log(receipts.map(t => t.logs))

  const output: Output = {
    transactions,
    receipts,
    libraries: [
      "lib/mento-core-2.0.0/contracts/common/linkedlists/AddressLinkedList.sol:AddressLinkedList:0x3e2cc57f83093Ce1Ee03482c1590E3B5f4225bd7",
      "lib/mento-core-2.0.0/contracts/common/linkedlists/AddressSortedLinkedListWithMedian.sol:AddressSortedLinkedListWithMedian:0x99EDce8143FF8AeFA1fBB6C2103B349Add2B9519",
      "lib/mento-core-2.3.1/contracts/governance/deployers/LockingDeployerLib.sol:LockingDeployerLib:0x92D29a6F03f5079789E7017646e15b29fA4304C2",
      "lib/mento-core-2.3.1/contracts/governance/deployers/MentoGovernorDeployerLib.sol:MentoGovernorDeployerLib:0xBba91F588d031469ABCCA566FE80fB1Ad8Ee3287",
      "lib/mento-core-2.3.1/contracts/governance/deployers/MentoTokenDeployerLib.sol:MentoTokenDeployerLib:0x2Dc038ea8f8BF797571FE83cAeef7238e6Fb8064",
      "lib/mento-core-2.3.1/contracts/governance/deployers/ProxyDeployerLib.sol:ProxyDeployerLib:0x915167582Dc79D27c464b05dB9f9363478F645a1",
      "lib/mento-core-2.3.1/contracts/governance/deployers/TimelockControllerDeployerLib.sol:TimelockControllerDeployerLib:0x6776f5333e61340b260b163F977C355563B06329"
    ],
    pending: [],
    returns: {},
    timestamp: 1716470208,
    chain: 42220,
    commit: "974edfe"
  }

  fs.writeFileSync("create-factory.json", JSON.stringify(output, null, 2));
}

async function generate_MUGOV_Execution() {
  const trace = await fetchCallTrace(CGP_EXECUTION_TX);
  // @ts-ignore
  const tx = await core.client.getTransaction({
    hash: CGP_EXECUTION_TX
  })
  // @ts-ignore
  let receipt = await core.client.getTransactionReceipt({
    hash: CGP_EXECUTION_TX
  })

  let calls: any[] = [trace.result]
  for (let i = 0; i < calls.length; i++) {
    calls = [...calls, ...(calls[i].calls || [])]
  }
  const createCalls = calls.filter(c => c.type == 'CREATE')
  receipt = {
    ...receipt,
    blockNumber: `0x${receipt["blockNumber"].toString(16)}`,
    cumulativeGasUsed: `0x${receipt["cumulativeGasUsed"].toString(16)}`,
    effectiveGasPrice: `0x${receipt["effectiveGasPrice"].toString(16)}`,
    gasUsed: `0x${receipt["gasUsed"].toString(16)}`,
    logs: receipt["logs"].map((log: any) => ({
      ...log,
      blockNumber: `0x${log["blockNumber"].toString(16)}`,
    }))
  }


  const transaction: Output["transactions"][0] = {
    hash: CGP_EXECUTION_TX,
    transactionType: trace["result"]["type"],
    contractName: null,
    contractAddress: trace["result"]["to"],
    function: null,
    arguments: null,
    transaction: {
      type: tx["typeHex"],
      from: tx["from"],
      gas: `0x${tx["gas"].toString(16)}`,
      value: `0x${tx["value"].toString(16)}`,
      data: trace["result"]["input"],
      nonce: tx["nonce"]
    },
    additionalContracts: createCalls.map(cc => ({
      transactionType: "CREATE",
      initCode: cc["input"],
      address: cc["to"]
    })),
    isFixedGasLimit: false
  }

  const output: Output = {
    transactions: [transaction],
    receipts: [receipt],
    libraries: [
      "lib/mento-core-2.0.0/contracts/common/linkedlists/AddressLinkedList.sol:AddressLinkedList:0x3e2cc57f83093Ce1Ee03482c1590E3B5f4225bd7",
      "lib/mento-core-2.0.0/contracts/common/linkedlists/AddressSortedLinkedListWithMedian.sol:AddressSortedLinkedListWithMedian:0x99EDce8143FF8AeFA1fBB6C2103B349Add2B9519",
    ],
    pending: [],
    returns: {},
    timestamp: 1717178813,
    chain: 42220,
    commit: "974edfe"
  }

  fs.writeFileSync("deploy-gov.json", JSON.stringify(output, null, 2));
}

async function run() {
  // await generate_MUGOV_Create_Factory()
  await generate_MUGOV_Execution()

}

run()


