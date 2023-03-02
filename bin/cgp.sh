#!/usr/bin/env bash

##############################################################################
# Script for submitting a Governance Proposal for a protocol upgrade
# Usage: ./bin/cgp.sh 
#               -n <baklava|alfajores|mainnet>  -- network to submit the proposal to
#               -u <upgrade_name>               -- name of the upgrade (MU01)
#               -p <phase_number>               -- phase number of the upgrade (1)
#               -s                              -- simulate the proposal (optional)
# Example: ./bin/cgp.sh -n baklava -u MU01 -p 1 
##############################################################################

source "$(dirname "$0")/setup.sh"

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



