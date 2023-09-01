#!/usr/bin/env bash

##############################################################################
# Build the contracts for a give upgrade
# Usage: ./bin/build.sh 
#               -u <upgrade_name>               -- name of the upgrade (MU01)
# Example: ./bin/clean.sh -n baklava -u MU01
##############################################################################

source "$(dirname "$0")/setup.sh"

UPGRADE=""
while getopts n:u:d flag
do
    case "${flag}" in
        u) UPGRADE=${OPTARG};;
    esac
done

parse_upgrade "$UPGRADE"
forge clean
forge build $(forge_skip $UPGRADE) 
