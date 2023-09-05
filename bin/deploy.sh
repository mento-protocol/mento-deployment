#!/usr/bin/env bash

##############################################################################
# Script for running all deployment tasks for a protocol upgrade
# Usage: ./bin/deploy.sh 
#               -n <baklava|alfajores|celo>  -- network to submit the proposal to
#               -u <upgrade_name>               -- name of the upgrade (MU01)
#               -s                              -- name of the script (optional)
# Example: ./bin/deploy.sh -n baklava -u MU01
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
    SCRIPT_FILE="script/upgrades/$UPGRADE/deploy/$SCRIPT"
    if test -f "$SCRIPT_FILE"; then
        echo "🔎 $SCRIPT_FILE found"
        forge_script "$SCRIPT" "$SCRIPT_FILE" "$(forge_skip $UPGRADE)"
        exit 0
    else
        echo "🚨 Script $SCRIPT not found in $SCRIPT_FILE"
        exit 1
    fi
fi

export FOUNDRY_PROFILE=$NETWORK-deployment
for DEPLOY_SCRIPT in $UPGRADE_DIR/deploy/*; do
    DEPLOY_FILE=$(basename $DEPLOY_SCRIPT)
    forge_script "$DEPLOY_FILE" "$DEPLOY_SCRIPT" "$(forge_skip $UPGRADE)"
done
