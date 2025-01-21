# Mento Deployment

This repo contains scripts for deploying & proposing upgrades to the Mento protocol. It can be used for both Mento and Celo governance proposals.
Deployments for the core contracts are done using [Foundry solidity scripting](https://book.getfoundry.sh/tutorials/solidity-scripting).

## Getting Started

```bash
# Get the latest code
git clone git@github.com:mento-protocol/mento-deployment.git

# Change directory to the the newly cloned repo
cd mento-deployment

# Install the project dependencies & build the contracts
yarn install && forge install && forge build

# Create your .env file (Replace the PK for deployer account)
cp .env.example .env

# Pull secrets from GCP
yarn secrets:get

# Execute scripts using forge script command
forge script DeployCircuitBreaker --rpc-url $ALFAJORES_RPC_URL --broadcast --legacy --verify --verifier sourcify
```

## Deployment Structure

The deployment scripts are organized in the following structure:

- `contracts/`: Contains helper contracts that aren't core, for example a DummyERC20 contract used on testnets
- `script/`: Contains all the Foundry deployment scripts
  - `script/upgrades/`: Contains all the upgrade scripts, which serve as a migration from one version of mento to another
    - `script/upgrades/MU01/`: Contains all the upgrade scripts to migrate from version v1.0.0. to v2.0.0
  - `script/dev/`: Contains dev scripts that are used in the deployment process, especially on testnets, but aren't central to the upgrade.
  - `script/utils/`: Contains helpers and utilities used in the deployment and governance operations using Celo Governance.
  - `script/utils/mento`: Contains helpers and utilities used in the deployment and governance operations using Mento Governance.
- `bin/`: Contains bash/typescript scripts that are used to execute the deployment process.
- `broadcast/`: Contains the broadcasted transactions for the deployment process.

## Scripts

The scripts tend to follow a similar structure, and are either simple helpers or wrappers for the `forge script` command.

General options will include:

- `-n`: The network to run on, e.g. `celo` or `alfajores`
- `-u`: The upgrade number, e.g. `MU01`
- `-g`: The governance that will be used, e.g. `celo` or `mento`

Check the script file for more details on usage but here's a quick overview:

```bash
# Clean the broadcast folder, will remove all broadcast files pertaining to that network and upgrade combination
> yarn clean -n alfajores -u MU01

# Show the list of deployed contracts and their addresses
> yarn show -n alfajores -u MU01
{"name":"BreakerBoxProxy","address":"0xB881aF21C5A9ff8e8d5E4C900F67F066C6CB7936"}
{"name":"BiPoolManagerProxy","address":"0xFF9a3da00F42839CD6D33AD7adf50bCc97B41411"}
{"name":"BrokerProxy","address":"0x6723749339e320E1EFcd9f1B0D997ecb45587208"}
{"name":"PartialReserveProxy","address":"0x5186f2871b81F057E249c4f4c940a20D2"}
# ...

# Run a development script, with no selector
> yarn script:dev -n alfajores
 Network is alfajores
==================================================================
👇 Pick a script to run
------------------------------------------------------------------
1) AddOtherReserveAddress        4) CreateMockBridgedUSDC
2) ChangeTestnetMockBridgedUSDC  5) DrainPartialReserve
3) CreateMockBridgedEUROC        6) FundPartialReserve
#?

# Run a development script by index
> yarn script:dev -n alfajores -i 2
📠 Network is alfajores
==================================================================
🔥 Running CreateMockBridgedUSDC
==================================================================

# Run a development script by name
> yarn script:dev -n alfajores -s CreateMockBridgedUSDC
📠 Network is alfajores
==================================================================
🔥 Running CreateMockBridgedUSDC
==================================================================

# Run an upgrade deployment, will run all deploy scripts in an upgrade
> yarn deploy -n alfajores -u MU01

# Submit an upgrade proposal, will output the proposal ID
> yarn cgp -n alfajores -u MU01 -g celo

# Pass a CGP on testnets
> yarn cgp:pass -n alfajores -g celo -p <proposal-id>
```

## Governance Coordination

The repository includes a script for coordinating voting between Celo Governance Proposals (CGPs) and Mento Governance Proposals (MGPs). This script ensures that the Celo Community's votes on MGPs through their 50M mento allocation are properly reflected based on CGP outcomes.

### Prerequisites

Before using the coordination script, you need to have:

1. An existing Mento Governance Proposal (MGP)
   - Created through the [Mento Governance UI](https://governance.mento.org)
   - Must follow the [Mento governance process](https://docs.mento.org/mento/protocol/governance)
2. A corresponding Celo Governance Proposal (CGP)
   - Created through the [Celo Governance UI](https://celo.stake.id/#/governance)
   - Must follow the [Celo governance process](https://docs.celo.org/protocol/governance)
3. The Celo CLI tool installed and configured
   - Install: `npm install -g @celo/celocli`
   - Configure: Follow the [Celo CLI setup guide](https://docs.celo.org/cli)

### Usage

```bash
yarn governance:coordinate-vote \
  --mento-proposal <MGP-ID> \
  --celo-proposal <CGP-ID> \
  --celo-governance <CELO-GOV-ADDRESS> \
  --mento-governor <MENTO-GOV-ADDRESS> \
  --address <MULTISIG-ADDRESS> \
  --derivation-path <PATH>
```

Options:

- `-m, --mento-proposal`: Mento Governance Proposal ID
- `-c, --celo-proposal`: Celo Governance Proposal ID
- `-g, --celo-governance`: Celo Governance contract address
- `-v, --mento-governor`: Mento Governor contract address
- `-r, --rpc-url`: RPC URL (defaults to https://forno.celo.org)
- `-a, --address`: Multisig address
- `-d, --derivation-path`: Derivation path for Celo CLI compatibility

The script will:

1. Verify the CGP result
2. If the CGP is executed:
   - Queue a YES vote on the MGP if CGP passed
   - Queue a NO vote on the MGP if CGP failed
3. The queued vote requires 2 additional approvers within 24 hours using:
   ```bash
   celocli multisig:approve --tx-id <id>
   ```

### For Approvers

When reviewing a transaction queued by this script, verify:

1. The target address matches the Mento Governor contract
2. The vote (YES/NO) matches the corresponding CGP result
3. The MGP ID is correct
4. Approve within 24 hours to prevent transaction expiration

### Governance Process Flow

1. Create MGP first through the Mento Governance UI
2. Create corresponding CGP through the Celo Governance UI
   - Include MGP ID in the title/description
   - Set CGP duration to 5 days
   - MGP duration should be 6 days
3. After CGP execution, use this script to coordinate the MGP vote
4. Ensure multisig approvers are ready to review and sign within 24 hours
