#!/usr/bin/env bash

# Imperfect but simple script to pass governance proposals on Celo tesnets (staging, baklava or alfajores)
set -euo pipefail

source .env

NETWORK=""
UPGRADE=""
PHASE=""
SIMULATE=false
while getopts n:u:p:s flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        u) UPGRADE=${OPTARG};;
        p) PHASE=${OPTARG};;
        s) SIMULATE=true;;
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
if [ "$SIMULATE" = true ] ; then
    echo "🥸  Simulating $UPGRADE Phase$PHASE CGP"
    forge script --rpc-url $BAKLAVA_RPC_URL --sig "run(uint8)" ${UPGRADE}_CGPSimulation $PHASE
else 
    echo "🔥 Submitting $UPGRADE Phase$PHASE CGP"
    forge script --rpc-url $BAKLAVA_RPC_URL --legacy --broadcast --verify --verifier sourcify ${UPGRADE}_CGP_Phase${PHASE}
fi



