#!/usr/bin/env bash

##############################################################################
# Script for executing a Governance Proposal for a protocol upgrade
# Usage: yarn cgp:execute
#               -p                           -- proposalId
#               -n <baklava|alfajores|celo>  -- network to submit the proposal to
#               -s                           -- simulate the proposal (optional)
# Example: yarn cgp -n baklava -u MU01 -p 1
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
PROPOSAL_ID=""
SIMULATE=false
while getopts n:p:sfr flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        p) PROPOSAL_ID=${OPTARG};;
        s) SIMULATE=true;;
    esac
done

parse_network "$NETWORK"

if [ -z "$PROPOSAL_ID" ]; then
    echo "🚨 No proposal ID provided"
    exit 1
fi

if [ "$SIMULATE" = true ] ; then
    echo "🥸 Simulating execution of proposal $PROPOSAL_ID on $NETWORK"
    forge script --rpc-url $RPC_URL --sig "run(uint256)" script/utils/ExecuteProposal.sol:ExecuteProposal $PROPOSAL_ID -vvvv
else 
    echo "🔥 Executing proposal $PROPOSAL_ID on $NETWORK"
    confirm_if_celo "$NETWORK"
    forge script --rpc-url $RPC_URL --sig "run(uint256)" script/utils/ExecuteProposal.sol:ExecuteProposal $PROPOSAL_ID --broadcast -vvvv --verify --verifier sourcify
fi
