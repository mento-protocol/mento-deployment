#!/usr/bin/env bash

##############################################################################
# Script for running all deployment tasks for a protocol upgrade
# Usage: ./bin/cgp-deploy.sh 
#               -n <baklava|alfajores|celo>  -- network to submit the proposal to
#               -u <upgrade_name>               -- name of the upgrade (MU01)
#               -s                              -- name of the script (optional)
# Example: ./bin/cgp-deploy.sh -n baklava -u MU01
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
UPGRADE=""
SCRIPT=""
while getopts n:u:s: flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        u) UPGRADE=${OPTARG};;
        s) SCRIPT=${OPTARG};;
    esac
done

parse_network "$NETWORK"
parse_upgrade "$UPGRADE"

if ! [ -z "$SCRIPT" ]; then # Pick the script by name
    DEPLOY_SCRIPT="script/upgrades/$UPGRADE/deploy/$SCRIPT"
    if test -f "$DEPLOY_SCRIPT"; then
        echo "🔎 $DEPLOY_SCRIPT found"
        echo "=================================================================="
        echo " Running $(basename $DEPLOY_SCRIPT)"
        echo "=================================================================="
        forge script $(forge_skip $UPGRADE) --rpc-url $RPC_URL --legacy --broadcast $DEPLOY_SCRIPT
        exit 0
    else
        echo "🚨 Script $SCRIPT not found in $DEPLOY_SCRIPT"
        exit 1
    fi
fi

export FOUNDRY_PROFILE=$NETWORK-deployment
for DEPLOY_SCRIPT in $UPGRADE_DIR/deploy/*; do
    echo "=================================================================="
    echo " Running $(basename $DEPLOY_SCRIPT)"
    echo "=================================================================="
    forge script $(forge_skip $UPGRADE) --rpc-url $RPC_URL --legacy --broadcast $DEPLOY_SCRIPT
done
