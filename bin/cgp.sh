#!/usr/bin/env bash

##############################################################################
# Script for submitting a Governance Proposal for a protocol upgrade
# Usage: yarn cgp
#               -n <baklava|alfajores|celo>  -- network to submit the proposal to
#               -u <upgrade_name>            -- name of the upgrade (MU01)
#               -g <celo|mento>              -- governance to use
#               -s                           -- simulate the proposal (optional)
#               -r                           -- revert (optional)
#               -f                           -- use forked network (optional)
# Example: yarn cgp -n baklava -u MU01 -g mento
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
UPGRADE=""
GOVERNANCE=""
SIMULATE=false
USE_FORK=false
REVERT=false
while getopts n:u:g:sfr flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        u) UPGRADE=${OPTARG};;
        g) GOVERNANCE=${OPTARG};;
        s) SIMULATE=true;;
        f) USE_FORK=true;;
        r) REVERT=true;;
    esac
done

parse_network "$NETWORK"
parse_upgrade "$UPGRADE"
parse_gov "$GOVERNANCE"

if [ "$USE_FORK" = true ] ; then
    # Make sure you're running a local anvil node:
    # anvil --fork-url ...
    RPC_URL="http://127.0.0.1:8545"
    echo "🍴 Submitting to forked network"
fi


if [ "$REVERT" = true ] ; then
    CONTRACT=$UPGRADE'Revert'
    echo "🔄 Reverting $UPGRADE via $CONTRACT"
else
    CONTRACT=$UPGRADE
    echo "🔥 Submitting $UPGRADE via $CONTRACT"
fi

if [ "$SIMULATE" = true ] ; then
    echo "🥸  Simulating $CONTRACT"
    yarn build -u $UPGRADE
    forge script $(forge_skip $UPGRADE) --rpc-url $RPC_URL --skip .dev.sol --sig "run(string)" $UTILS_DIR/SimulateUpgrade.sol:SimulateUpgrade $CONTRACT
else 
    echo "🔥 Submitting $CONTRACT"
    confirm_if_celo "$NETWORK"
    forge script $(forge_skip $UPGRADE) --rpc-url $RPC_URL --legacy --broadcast ${CONTRACT}
fi



