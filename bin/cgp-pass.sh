#!/usr/bin/env bash

##############################################################################
# Script for passing a Celo Governance Proposal on a tesnet.
# Usage: yarn cgp:pass 
#               -n <baklava|alfajores>  -- network to pass the proposal on
#               -p <proposal_id>        -- proposal ID
#               -g <celo|mento>         -- governance to use
# Example: yarn cgp:pass -n baklava -p 79 -g mento
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
PROPOSAL_ID=""
GOVERNANCE=""
while getopts n:p:g: flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        p) PROPOSAL_ID=${OPTARG};;
        g) GOVERNANCE=${OPTARG};;
    esac
done

parse_network "$NETWORK"
parse_gov "$GOVERNANCE"

if [ -z "$PROPOSAL_ID" ]; then
    echo "🚨 No proposal ID provided"
    exit 1
fi


SIGNER_PK_PARAM="--privateKey $SIGNER_PK"
if [ -z "$SIGNER_PK" ]; then
    # If there's no private key, we assume the signer 
    # is unlocked in the node and we don't need to pass it in.
    SIGNER_PK_PARAM=""
fi

if [ "$GOVERNANCE" = "celo" ]; then
    celocli config:set --node $RPC_URL
    echo "✅ Approving proposal $PROPOSAL_ID"
    echo "=========================================="
    celocli governance:approve --proposalID $PROPOSAL_ID --from $APPROVER --useMultiSig --privateKey $APPROVER_PK
    echo -e "\a"
    echo "🗳️ Voting proposal $PROPOSAL_ID"
    echo "=========================================="
    celocli governance:vote --value=Yes --from=$SIGNER --proposalID=$PROPOSAL_ID $SIGNER_PK_PARAM
    countdown 301
    # celocli governance:execute --from=$SIGNER --proposalID=$PROPOSAL_ID $SIGNER_PK_PARAM
elif [ "$GOVERNANCE" = "mento" ]; then
    echo "🗳️ Voting proposal: $PROPOSAL_ID"
    echo "=========================================="
    forge script --rpc-url $RPC_URL --sig "run(uint256)" $UTILS_DIR/PassProposal.sol:PassProposal $PROPOSAL_ID --broadcast --no-cache
    countdown 301 # wait for voting period to end
    echo "✅ Queuing proposal: $PROPOSAL_ID"
    echo "=========================================="
    forge script --rpc-url $RPC_URL --sig "run(uint256)" $UTILS_DIR/QueueProposal.sol:QueueProposal $PROPOSAL_ID --broadcast --no-cache
    countdown 601 # wait for queue period to end
else
    echo "❌ Unknown governance: $GOVERNANCE"
    exit 1
fi

echo "💃 Executing proposal $PROPOSAL_ID"
yarn cgp:execute -n $NETWORK -p $PROPOSAL_ID -g $GOVERNANCE
# Proposal passed, make some noise
echo -e "\a"
echo -e "\a"
echo -e "\a"
