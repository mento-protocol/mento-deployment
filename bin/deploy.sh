#!/usr/bin/env bash

##############################################################################
# Script for running all deployment tasks for a protocol upgrade
# Usage: ./bin/deploy.sh 
#               -n <baklava|alfajores|mainnet>  -- network to submit the proposal to
#               -u <upgrade_name>               -- name of the upgrade (MU01)
# Example: ./bin/deploy.sh -n baklava -u MU01
##############################################################################

set -euo pipefail

source .env

NETWORK=""
UPGRADE=""
while getopts n:u: flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        u) UPGRADE=${OPTARG};;
    esac
done

case $NETWORK in 
    "baklava")
        RPC_URL=$BAKLAVA_RPC_URL
        ;;
    "alfajores")
        RPC_URL=$ALFAJORES_RPC_URL
        ;;
    *)
        echo "🚨 Invalid network: '$NETWORK'"
        exit 1
esac

if [ -z "$UPGRADE" ]; then
    echo "🚨 No upgrade provided"
    exit 1
fi

echo "📠 Network is $NETWORK"

UPGRADE_DIR=script/upgrades/$UPGRADE
if test -d "$UPGRADE_DIR"; then
    echo "✅ Upgrade $UPGRADE found"
else
    echo "🚨 Upgrade $UPGRADE not found in $UPGRADE_DIR"
    exit 1
fi

for DEPLOY_SCRIPT in $UPGRADE_DIR/deploy/*; do
    echo "=================================================================="
    echo "🔥 Running $DEPLOY_SCRIPT"
    echo "=================================================================="
    forge script --rpc-url $RPC_URL --legacy --broadcast --verify --verifier sourcify $DEPLOY_SCRIPT
done