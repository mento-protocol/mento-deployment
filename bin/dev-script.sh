#!/usr/bin/env bash

##############################################################################
# Script for running all deployment tasks for a protocol upgrade
# Usage: ./bin/dev-script.sh 
#               -n <alfajores|celo>  -- network to submit the proposal to
#               -i <script-index>            -- index of the script (optional)
#               -s <script-name>             -- name of the script (optional)
#               -r <run-signature>           -- signature of the run function (optional)
# Example: 
# To pick the script:
# ./bin/deploy.sh -n alfajores 
# To pick the script by index:
# ./bin/deploy.sh -n alfajores -i 1
# To pick the script by name:
# ./bin/deploy.sh -n alfajores -s CreateMockBridgedUSDC
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
INDEX=""
SCRIPT_NAME=""
RUN_SIGNATURE="run()"
while getopts n:i:s:r: flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        i) INDEX=${OPTARG};;
        s) SCRIPT_NAME=${OPTARG};;
        r) RUN_SIGNATURE=${OPTARG};;
    esac
done

shift "$((OPTIND - 1))"

parse_network "$NETWORK"

if ! [ -z "$SCRIPT_NAME" ]; then # Pick the script by name
    SCRIPT_FILE="script/dev/dev-$SCRIPT_NAME.sol"
    if test -f "$SCRIPT_FILE"; then
        echo "🔎  $SCRIPT_FILE found"
        echo "=================================================================="
        echo " Running $SCRIPT_NAME"
        echo "=================================================================="
        confirm_if_celo "$NETWORK"
        forge script $(forge_skip "dev") --rpc-url $RPC_URL --legacy --verify --verifier sourcify --broadcast -s $RUN_SIGNATURE $SCRIPT_FILE "$@"
        exit 0
    else
        echo "🚨 Script $SCRIPT_NAME not found in $SCRIPT_FILE"
        exit 1
    fi
fi

if ! [ -z "$INDEX" ]; then # Pick the script by index
    SCRIPTS_COUNT=$(ls script/dev/* | wc -l)
    if ! [[ "$INDEX" =~ ^[0-9]+$ ]] || [ $INDEX -gt $SCRIPTS_COUNT ] || [ $INDEX -lt "1" ]; then
        echo "🚨 Index $INDEX is out of range or invalid"
        exit 1
    fi
    SCRIPT_FILE=$(ls script/dev/* | head -n $INDEX | tail -n 1)
    echo "=================================================================="
    echo " Running $(basename SCRIPT_FILE)"
    echo "=================================================================="
    confirm_if_celo "$NETWORK"
    forge script $(forge_skip "dev") --rpc-url $RPC_URL --legacy --verify --verifier sourcify --broadcast -s $RUN_SIGNATURE $SCRIPT_FILE "$@"
    exit 0
fi

# Choose script from a selector
SCRIPTS=$(ls script/dev/* | xargs -n 1 basename | sed 's/.sol//g' | sed 's/dev-//g')
echo "=================================================================="
echo "👇 Pick a script to run"
echo "------------------------------------------------------------------"
select SCRIPT in $SCRIPTS
do 
    SCRIPT_FILE="script/dev/dev-$SCRIPT.sol"
    if test -f "$SCRIPT_FILE"; then
        echo "🔎  $SCRIPT_FILE found"
        echo "=================================================================="
        echo " Running $(basename SCRIPT_FILE)"
        echo "=================================================================="
        confirm_if_celo "$NETWORK"
        forge script $(forge_skip "dev") --rpc-url $RPC_URL --legacy --verify --verifier sourcify --broadcast $SCRIPT_FILE
    else
        echo "Invalid option, press Ctrl+C to exit"
    fi
done
