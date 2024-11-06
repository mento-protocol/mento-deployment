#!/bin/bash

##############################################################################
# This script will show the addresses of all contracts deployed in a given upgrade
# Usage: ./bin/show.sh 
#               -n <alfajores|celo>  -- network to target
#               -u <upgrade_name>            -- name of the upgrade (MU01)
# Example: ./bin/show.sh -n alfajores -u MU01
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
UPGRADE=""
while getopts n:u:d flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        u) UPGRADE=${OPTARG};;
    esac
done

parse_network "$NETWORK"
parse_upgrade "$UPGRADE"

NETWORK_URL_SEGMENT=$NETWORK
if [ "$NETWORK" == "celo" ]; then
    NETWORK_URL_SEGMENT="mainnet"
fi

ls broadcast/$UPGRADE-*/$CHAIN_ID/run-latest.json | \
    xargs cat | \
    jq "
    .transactions[] | 
    select(.transactionType == \"CREATE\") | 
    {
        name: .contractName, 
        address: .contractAddress,
        url: \"https://explorer.celo.org/$NETWORK_URL_SEGMENT/address/\(.contractAddress)\"
    }
    "