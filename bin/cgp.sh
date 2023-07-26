#!/usr/bin/env bash

##############################################################################
# Script for submitting a Governance Proposal for a protocol upgrade
# Usage: yarn cgp
#               -n <baklava|alfajores|celo>  -- network to submit the proposal to
#               -u <upgrade_name>            -- name of the upgrade (MU01)
#               -s                           -- simulate the proposal (optional)
#               -f                           -- use forked network (optional)
# Example: yarn cgp -n baklava -u MU01 -p 1
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
UPGRADE=""
SIMULATE=false
USE_FORK=false
while getopts n:u:p:sf flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        u) UPGRADE=${OPTARG};;
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

if [ "$SIMULATE" = true ] ; then
    echo "🥸 Simulating $UPGRADE"
    forge script $(forge_skip $UPGRADE) --rpc-url $RPC_URL --skip .dev.sol --sig "run(string)" script/utils/SimulateUpgrade.sol:SimulateUpgrade $UPGRADE
else 
    echo "🔥 Submitting $UPGRADE"
    confirm_if_celo "$NETWORK"
    forge script $(forge_skip $UPGRADE) --rpc-url $RPC_URL --legacy --broadcast ${UPGRADE}
fi



