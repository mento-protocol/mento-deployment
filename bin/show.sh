#!/bin/bash

##############################################################################
# This script will show the addresses of all contracts deployed in a given upgrade
# Usage: ./bin/show.sh 
#               -n <baklava|alfajores|celo>  -- network to target
#               -p <proposal_name>           -- name of the proposal (MU01)
# Example: ./bin/show.sh -n baklava -p MU01
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
PROPOSAL=""
while getopts n:p:d flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        p) PROPOSAL=${OPTARG};;
    esac
done

parse_network "$NETWORK"
parse_proposal "$PROPOSAL"

NETWORK_URL_SEGMENT=$NETWORK
if [ "$NETWORK" == "celo" ]; then
    NETWORK_URL_SEGMENT="mainnet"
fi

ls broadcast/$PROPOSAL-*/$CHAIN_ID/run-latest.json | \
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
