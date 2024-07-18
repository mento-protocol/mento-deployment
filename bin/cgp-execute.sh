#!/usr/bin/env bash

##############################################################################
# Script for executing a Governance Proposal for a protocol upgrade
# Usage: yarn cgp:execute
#               -p                           -- proposalId
#               -n <baklava|alfajores|celo>  -- network to submit the proposal to
#               -g <celo|mento>              -- governance to use
#               -s                           -- simulate the proposal (optional)
# Example: yarn cgp -n baklava -p 1 -g mento
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
PROPOSAL_ID=""
GOVERNANCE=""
SIMULATE=false
while getopts n:p:g:sfr flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        p) PROPOSAL_ID=${OPTARG};;
        g) GOVERNANCE=${OPTARG};;
        s) SIMULATE=true;;
    esac
done

parse_network "$NETWORK"
parse_gov "$GOVERNANCE"

if [ -z "$PROPOSAL_ID" ]; then
    echo "🚨 No proposal ID provided"
    exit 1
fi

if [ "$SIMULATE" = true ] ; then
    echo "🥸 Simulating execution of proposal $PROPOSAL_ID on $NETWORK"
    forge script --rpc-url $RPC_URL --sig "run(uint256)" $UTILS_DIR/ExecuteProposal.sol:ExecuteProposal $PROPOSAL_ID -vvvv
else 
    echo "🔥 Executing proposal $PROPOSAL_ID on $NETWORK"
    confirm_if_celo "$NETWORK"
    forge script --rpc-url $RPC_URL --sig "run(uint256)" $UTILS_DIR/ExecuteProposal.sol:ExecuteProposal $PROPOSAL_ID --broadcast -vvvv --verify --verifier sourcify
fi
