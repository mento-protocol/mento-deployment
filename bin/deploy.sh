#!/usr/bin/env bash

##############################################################################
# Script for running deploy scripts not tied to mento/celo governance proposals
# Usage: ./bin/deploy.sh 
#               -n <baklava|alfajores|celo>  -- network to submit the proposal to
#               -i <script-index>               -- index of the script (optional)
#               -s <script-name>                -- name of the script (optional)
# Example: 
# To pick the script:
# ./bin/deploy.sh -n baklava 
# To pick the script by index:
# ./bin/deploy.sh -n baklava -i 1
# To pick the script by name:
# ./bin/deploy.sh -n baklava -s ChainlinkRelayerFactory
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
INDEX=""
SCRIPT_NAME=""
while getopts n:i:s: flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        i) INDEX=${OPTARG};;
        s) SCRIPT_NAME=${OPTARG};;
    esac
done

parse_network "$NETWORK"

if ! [ -z "$SCRIPT_NAME" ]; then # Pick the script by name
    SCRIPT_FILE="script/deploy/$SCRIPT_NAME.sol"
    if test -f "$SCRIPT_FILE"; then
        echo "🔎  $SCRIPT_FILE found"
        forge_script "Deploy$SCRIPT_NAME" "$SCRIPT_FILE" $(forge_skip "dev")
        exit 0
    else
        echo "🚨 Deploy script $SCRIPT_NAME not found"
        exit 1
    fi
fi

if ! [ -z "$INDEX" ]; then # Pick the script by index
    SCRIPTS_COUNT=$(ls script/deploy/* | wc -l)
    if ! [[ "$INDEX" =~ ^[0-9]+$ ]] || [ $INDEX -gt $SCRIPTS_COUNT ] || [ $INDEX -lt "1" ]; then
        echo "🚨 Index $INDEX is out of range or invalid"
        exit 1
    fi
    SCRIPT=$(ls script/dev/* | head -n $INDEX | tail -n 1)
    forge_script "Deploy$(basename $SCRIPT .sol)" "$SCRIPT" $(forge_skip "dev")
    exit 0
fi

# Choose script from a selector
SCRIPTS=$(ls script/deploy/* | xargs -n 1 basename | sed 's/.sol//g' | sed 's/dev-//g')
echo "=================================================================="
echo "👇 Pick a deploy script to run"
echo "------------------------------------------------------------------"
select SCRIPT in $SCRIPTS
do 
    SCRIPT_FILE="script/deploy/$SCRIPT.sol"
    if test -f "$SCRIPT_FILE"; then
        echo "🔎  $SCRIPT_FILE found"
        forge_script "$SCRIPT" "$SCRIPT_FILE" "$(forge_skip "dev")"
        exit 0
    else
        echo "Invalid option, press Ctrl+C to exit"
    fi
done
