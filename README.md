# Mento Deployment

This repo contains scripts for deploying & proposing upgrades to the Mento protocol.
Deployments for the core contracts are done using [Foundry solidity scripting](https://book.getfoundry.sh/tutorials/solidity-scripting).

## Getting Started

```bash
# Get the latest code
git clone git@github.com:mento-protocol/mento-deployment.git

# Change directory to the the newly cloned repo
cd mento-deployment

# Install the project dependencies & build the contracts
forge install && forge build

# Create your .env file(Replace the PK for deployer account)
cp .env.example .env

# Pull secrets from GCP
./bin/get_secrets.sh

# Execute scripts using forge script command
forge script DeployCircuitBreaker --rpc-url $BAKLAVA_RPC_URL --broadcast --legacy --verify --verifier sourcify

```
