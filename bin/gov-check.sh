#!/usr/bin/env bash

##############################################################################
# Script for running Governance Proposal Checks on top of a network
# Usage: yarn gov:check
#               -n <baklava|alfajores|celo>  -- network to submit the proposal to
#               -p <proposal_name>           -- name of the proposal (MU01)
#               -g <celo|mento>              -- governance to use
# Example: yarn cgp:check -n baklava -p MU03
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
PROPOSAL=""
while getopts n:p:g:sfr flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        p) PROPOSAL=${OPTARG};;
    esac
done

parse_network "$NETWORK"
parse_proposal "$PROPOSAL"

echo "👀  Checking $PROPOSAL"
forge script $(forge_skip $PROPOSAL) --rpc-url $RPC_URL --sig "check(string)"script/bin/SimulateProposal.sol:SimulateProposal $PROPOSAL
