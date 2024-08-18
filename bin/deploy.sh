#!/usr/bin/env bash

##############################################################################
# Script for running all deployment tasks for a governance proposal.
# Usage: ./bin/deploy.sh 
#               -n <baklava|alfajores|celo>  -- network to submit the proposal to
#               -p <proposal_name>           -- name of the proposal (MU01)
#               -s                           -- name of the script (optional)
# Example: ./bin/deploy.sh -n baklava -p MU01
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
PROPOSAL=""
SCRIPT=""
while getopts n:p:s: flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        p) PROPOSAL=${OPTARG};;
        s) SCRIPT=${OPTARG};;
    esac
done

parse_network "$NETWORK"
parse_proposal "$PROPOSAL"

if ! [ -z "$SCRIPT" ]; then # Pick the script by name
    SCRIPT_FILE="script/proposals/$PROPOSAL/deploy/$SCRIPT"
    if test -f "$SCRIPT_FILE"; then
        echo "🔎 $SCRIPT_FILE found"
        forge_script "$SCRIPT" "$SCRIPT_FILE" "$(forge_skip $PROPOSAL)"
        exit 0
    else
        echo "🚨 Script $SCRIPT not found in $SCRIPT_FILE"
        exit 1
    fi
fi

export FOUNDRY_PROFILE=$NETWORK-deployment
for DEPLOY_SCRIPT in $PROPOSAL_DIR/deploy/*; do
    DEPLOY_FILE=$(basename $DEPLOY_SCRIPT)
    forge_script "$DEPLOY_FILE" "$DEPLOY_SCRIPT" "$(forge_skip $PROPOSAL)"
done
