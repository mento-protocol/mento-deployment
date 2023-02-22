#!/usr/bin/env bash

# Imperfect but simple script to pass governance proposals on Celo tesnets (staging, baklava or alfajores)
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