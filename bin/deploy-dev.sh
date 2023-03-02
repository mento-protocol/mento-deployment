#!/usr/bin/env bash

##############################################################################
# Script for running all deployment tasks for a protocol upgrade
# Usage: ./bin/deploy.sh 
#               -n <baklava|alfajores|mainnet>  -- network to submit the proposal to
#               -u <upgrade_name>               -- name of the upgrade (MU01)
# Example: ./bin/deploy.sh -n baklava -u MU01
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
UPGRADE=""
while getopts n:u: flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        u) UPGRADE=${OPTARG};;
    esac
done

parse_network "$NETWORK"
parse_upgrade "$UPGRADE"

for DEPLOY_SCRIPT in $UPGRADE_DIR/dev/*; do
    echo "=================================================================="
    echo "🔥 Running $DEPLOY_SCRIPT"
    echo "=================================================================="
    forge script --rpc-url $RPC_URL --legacy --broadcast --verify --verifier sourcify $DEPLOY_SCRIPT
done