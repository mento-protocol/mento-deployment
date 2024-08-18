#!/usr/bin/env bash

##############################################################################
# Script for running Governance Proposal Checks on top of a network
# Usage: yarn cgp:check
#               -n <baklava|alfajores|celo>  -- network to submit the proposal to
#               -u <upgrade_name>            -- name of the upgrade (MU01)
#               -g <celo|mento>              -- governance to use
# Example: yarn cgp:check -n baklava -u MU03 -g mento
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
UPGRADE=""
GOVERNANCE=""
while getopts n:u:g:sfr flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        u) UPGRADE=${OPTARG};;
        g) GOVERNANCE=${OPTARG};;
    esac
done

parse_network "$NETWORK"
parse_upgrade "$UPGRADE"
parse_gov "$GOVERNANCE"

echo "👀  Checking $UPGRADE"
forge script $(forge_skip $UPGRADE) --rpc-url $RPC_URL --sig "check(string)"script/bin/SimulateProposal.sol:SimulateProposal $UPGRADE
