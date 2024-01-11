#!/usr/bin/env bash

##############################################################################
# Script for passing a Celo Governance Proposal on a tesnet.
# Usage: yarn cgp:pass 
#               -n <baklava|alfajores>  -- network to pass the proposal on
#               -p <proposal_id>        -- proposal ID
# Example: yarn cgp:pass -n baklava -p 79
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
PROPOSAL_ID=""
while getopts n:p: flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        p) PROPOSAL_ID=${OPTARG};;
    esac
done

parse_network "$NETWORK"

if [ -z "$PROPOSAL_ID" ]; then
    echo "🚨 No proposal ID provided"
    exit 1
fi

celocli config:set --node $RPC_URL

SIGNER_PK_PARAM="--privateKey $SIGNER_PK"
if [ -z "$SIGNER_PK" ]; then
    # If there's no private key, we assume the signer 
    # is unlocked in the node and we don't need to pass it in.
    SIGNER_PK_PARAM=""
fi

echo "😴 31s"
echo -e "\a" && sleep 31
echo "✅ Approving proposal $PROPOSAL_ID"
echo "=========================================="
celocli governance:approve --proposalID $PROPOSAL_ID --from $APPROVER --useMultiSig --privateKey $APPROVER_PK
echo -e "\a"
echo "🗳️ Voting proposal $PROPOSAL_ID"
echo "=========================================="
celocli governance:vote --value=Yes --from=$SIGNER --proposalID=$PROPOSAL_ID $SIGNER_PK_PARAM
echo "😴 301s"
echo -e "\a" && sleep 301
echo "💃 Executing proposal $PROPOSAL_ID"
celocli governance:execute --from=$SIGNER --proposalID=$PROPOSAL_ID $SIGNER_PK_PARAM

# Proposal passed, make some noise
echo -e "\a"
echo -e "\a"
echo -e "\a"
