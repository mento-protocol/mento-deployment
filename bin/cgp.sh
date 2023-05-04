#!/usr/bin/env bash

##############################################################################
# Script for submitting a Governance Proposal for a protocol upgrade
# Usage: yarn cgp
#               -n <baklava|alfajores|celo>  -- network to submit the proposal to
#               -u <upgrade_name>            -- name of the upgrade (MU01)
#               -p <phase>                   -- phase suffix of the proposal (1, 1_Phase1)
#               -s                           -- simulate the proposal (optional)
#               -f                           -- use forked network (optional)
# Example: yarn cgp -n baklava -u MU01 -p 1
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
UPGRADE=""
PHASE=""
SIMULATE=false
USE_FORK=false
while getopts n:u:p:sf flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        u) UPGRADE=${OPTARG};;
        p) PHASE=${OPTARG};;
        s) SIMULATE=true;;
        f) USE_FORK=true;;
    esac
done

parse_network "$NETWORK"
parse_upgrade "$UPGRADE"

if [ "$USE_FORK" = true ] ; then
    # Make sure you're running a local anvil node:
    # anvil --fork-url ...
    RPC_URL="http://127.0.0.1:8545"
    echo "🍴 Submitting to forked network"
fi

if [ -z "$PHASE" ]; then
    echo "🚨 No phase provided"
    exit 1
fi

if [ "$SIMULATE" = true ] ; then
    echo "🥸  Simulating $UPGRADE Phase$PHASE CGP"
    forge script --rpc-url $RPC_URL --sig "run(uint8)" ${UPGRADE}_CGPSimulation $PHASE
else 
    echo "🔥 Submitting $UPGRADE Phase$PHASE CGP"
    forge script --rpc-url $RPC_URL --legacy --broadcast ${UPGRADE}_CGP_Phase${PHASE}
fi



