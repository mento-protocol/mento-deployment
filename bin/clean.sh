#!/usr/bin/env bash

##############################################################################
# Script for cleaning the broadcast file for an upgrade + networ combo
# Usage: ./bin/deploy.sh 
#               -n <baklava|alfajores|mainnet>  -- network to submit the proposal to
#               -u <upgrade_name>               -- name of the upgrade (MU01)
# Example: ./bin/clean.sh -n baklava -u MU01
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

for BROADCAST_FOLDER in broadcast/$UPGRADE*; do
    echo "🧹 Cleaning $BROADCAST_FOLDER/$CHAIN_ID"
done

read -p "🚨 Continue? (y/n) " yn
case $yn in 
    [Yy]*) ;;
    *) echo "🛑 Operation stopped."
       exit;;
esac

for BROADCAST_FOLDER in broadcast/$UPGRADE*; do
    rm -rf $BROADCAST_FOLDER/$CHAIN_ID
done

echo "✅ Done"

