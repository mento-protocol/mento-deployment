#!/usr/bin/env bash

##############################################################################
# Script for cleaning the broadcast file for a proposal. 
# Usage: ./bin/clean.sh 
#               -n <baklava|alfajores|celo>  -- network to submit the proposal to
#               -p <proposal_name>           -- name of the proposal (MU01)
# Example: ./bin/clean.sh -n baklava -p MU01
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

for BROADCAST_FOLDER in broadcast/$PROPOSAL*; do
    echo "🧹 Cleaning $BROADCAST_FOLDER/$CHAIN_ID"
done

read -p "🚨 Continue? (y/n) " yn
case $yn in 
    [Yy]*) ;;
    *) echo "🛑 Operation stopped."
       exit;;
esac

for BROADCAST_FOLDER in broadcast/$PROPOSAL*; do
    rm -rf $BROADCAST_FOLDER/$CHAIN_ID
done

echo "✅ Done"
