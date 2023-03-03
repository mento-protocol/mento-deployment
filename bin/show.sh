#!/bin/bash

##############################################################################
# This script will show the addresses of all contracts deployed in a given upgrade
# Usage: ./bin/show.sh 
#               -n <baklava|alfajores>  -- network to pass the proposal on
#               -u <upgrade_name>       -- name of the upgrade (MU01)
# Example: ./bin/show.sh -n baklava -p 79
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

ls broadcast/$UPGRADE-*/$CHAIN_ID/run-latest.json | \
    xargs cat | \
    jq -c ".transactions[] | select(.transactionType == \"CREATE\") | {name: .contractName, address: .contractAddress} "