#!/usr/bin/env bash

##############################################################################
# Script for running Governance Proposal Checks on top of a network
# Usage: yarn cgp:check
#               -n <baklava|alfajores|celo>  -- network to submit the proposal to
#               -u <upgrade_name>            -- name of the upgrade (MU01)
# Example: yarn cgp:check -n baklava -u MU03 
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
UPGRADE=""
while getopts n:u:p:sfr flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        u) UPGRADE=${OPTARG};;
    esac
done

parse_network "$NETWORK"
parse_upgrade "$UPGRADE"

echo "  Checking $UPGRADE"
forge script $(forge_skip $UPGRADE) --rpc-url $RPC_URL --skip .dev.sol --sig "check(string)" script/utils/SimulateUpgrade.sol:SimulateUpgrade $UPGRADE
