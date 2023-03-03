#!/usr/bin/env bash

##############################################################################
# Script for running all deployment tasks for a protocol upgrade
# Usage: ./bin/deploy.sh 
#               -n <baklava|alfajores|mainnet>  -- network to submit the proposal to
#               -u <upgrade_name>               -- name of the upgrade (MU01)
# Example: ./bin/deploy.sh -n baklava -u MU01
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

if ! [ -z "$SCRIPT_NAME" ]; then
    SCRIPT_FILE="script/dev/dev-$SCRIPT_NAME.sol"
    if test -f "$SCRIPT_FILE"; then
        echo "🔎  $SCRIPT_FILE found"
        forge_script "$SCRIPT_NAME" "$SCRIPT_FILE"
        exit 0
    else
        echo "🚨 Script $SCRIPT_NAME not found in $SCRIPT_FILE"
        exit 1
    fi
fi

if ! [ -z "$INDEX" ]; then
    SCRIPTS_COUNT=$(ls script/dev/* | wc -l)
    if ! [[ "$INDEX" =~ ^[0-9]+$ ]] || [ $INDEX -gt $SCRIPTS_COUNT ] || [ $INDEX -lt "1" ]; then
        echo "🚨 Index $INDEX is out of range or invalid"
        exit 1
    fi
    SCRIPT=$(ls script/dev/* | head -n $INDEX | tail -n 1) 
    forge_script "$(basename $SCRIPT .sol | sed 's/dev-//g')" "$SCRIPT"
    exit 0
fi

# Choose script
SCRIPTS=$(ls script/dev/* | xargs -n 1 basename | sed 's/.sol//g' | sed 's/dev-//g')
# echo "${SCRIPTS[@]}"

echo "=================================================================="
echo "👇 Pick a script to run"
echo "------------------------------------------------------------------"
select SCRIPT in $SCRIPTS
do 
    SCRIPT_FILE="script/dev/dev-$SCRIPT.sol"
    if test -f "$SCRIPT_FILE"; then
        echo "🔎  $SCRIPT_FILE found"
        forge_script "$SCRIPT" "$SCRIPT_FILE"
        exit 0
    else
        echo "Invalid option, press Ctrl+C to exit"
    fi
done