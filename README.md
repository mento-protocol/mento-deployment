# Mento Deployment

This repo contains scripts for deploying & proposing upgrades to the Mento protocol. It can be used for both Mento and Celo governance proposals.
Deployments for the core contracts are done using [Foundry solidity scripting](https://book.getfoundry.sh/tutorials/solidity-scripting).

## Getting Started

```bash
# Get the latest code
git clone git@github.com:mento-protocol/mento-deployment.git

# Change directory to the the newly cloned repo
cd mento-deployment

# Install the project dependencies & build the contracts
forge install && forge build

# Create your .env file (Replace the PK for deployer account)
cp .env.example .env

# Pull secrets from GCP
yarn secrets:get

# Execute scripts using forge script command
forge script DeployCircuitBreaker --rpc-url $BAKLAVA_RPC_URL --broadcast --legacy --verify --verifier sourcify
```

## Deployment Structure

The deployment scripts are organized in the following structure:

- `contracts/`: Contains helper contracts that aren't core, for example a DummyERC20 contract used on testnets
- `script/`: Contains all the Foundry deployment scripts
  - `script/bin`: Contains `bin` type Solidity scripts for interacting with Celo and Mento Governance proposals.
  - `script/dev/`: Contains dev scripts that are used in the deployment process, especially on testnets, but aren't central to the upgrade.
  - `script/proposals/`: Contains all the governance proposal scripts, which serve as protocol upgrades.
  - `script/utils/`: Contains helpers and utilities used in the deployment and governance operations.
- `bin/`: Contains bash/typescript scripts that are used to execute the deployment process.
- `broadcast/`: Contains the broadcasted transactions for the deployment process.

## Scripts

The scripts tend to follow a similar structure, and are either simple helpers or wrappers for the `forge script` command.

General options will include:

- `-n`: The network to run on, e.g. `baklava` or `alfajores`
- `-p`: The proposal ID, e.g. `MU01`

Check the script file for more details on usage but here's a quick overview:

```bash
# Clean the broadcast folder, will remove all broadcast files pertaining to that network and upgrade combination
> yarn clean -n baklava -p MU01

# Show the list of deployed contracts and their addresses
> yarn show -n baklava -p MU01
{"name":"BreakerBoxProxy","address":"0xB881aF21C5A9ff8e8d5E4C900F67F066C6CB7936"}
{"name":"BiPoolManagerProxy","address":"0xFF9a3da00F42839CD6D33AD7adf50bCc97B41411"}
{"name":"BrokerProxy","address":"0x6723749339e320E1EFcd9f1B0D997ecb45587208"}
{"name":"PartialReserveProxy","address":"0x5186f2871b81F057E249c4f4c940a20D2"}
# ...

# Run a development script, with no selector
> yarn script:dev -n baklava
 Network is baklava
==================================================================
👇 Pick a script to run
------------------------------------------------------------------
1) AddOtherReserveAddress        4) CreateMockBridgedUSDC
2) ChangeTestnetMockBridgedUSDC  5) DrainPartialReserve
3) CreateMockBridgedEUROC        6) FundPartialReserve
#?

# Run a development script by index
> yarn script:dev -n baklava -i 2
📠 Network is baklava
==================================================================
🔥 Running CreateMockBridgedUSDC
==================================================================

# Run a development script by name
> yarn script:dev -n baklava -s CreateMockBridgedUSDC
📠 Network is baklava
==================================================================
🔥 Running CreateMockBridgedUSDC
==================================================================

# Run an upgrade deployment, will run all deploy scripts in an upgrade
> yarn deploy -n baklava -p MU01

# Submit an upgrade proposal, will output the proposal ID
> yarn cgp -n baklava -p MU01

# Pass a CGP on testnets
> yarn cgp:pass -n baklava -p <proposal-id>
```
