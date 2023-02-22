#!/usr/bin/env bash

# Imperfect but simple script to pass governance proposals on Celo tesnets (staging, baklava or alfajores)
set -euo pipefail

source .env

NETWORK=""
PROPOSAL_ID=""
while getopts n:p: flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        p) PROPOSAL_ID=${OPTARG};;
    esac
done

case $NETWORK in 
    "baklava")
        APPROVER=$BAKLAVA_APPROVER
        APPROVER_PK=$BAKLAVA_APPROVER_PK
        SIGNER=$BAKLAVA_SIGNER
        SIGNER_PK=$BAKLAVA_SIGNER_PK
        RPC_URL=$BAKLAVA_RPC_URL
        ;;
    "alfajores")
        APPROVER=$ALFAJORES_APPROVER
        APPROVER_PK=$ALFAJORES_APPROVER_PK
        SIGNER=$ALFAJORES_SIGNER
        SIGNER_PK=$ALFAJORES_SIGNER_PK
        RPC_URL=$ALFAJORES_RPC_URL
        ;;
    *)
        echo "🚨 Invalid network: '$NETWORK'"
        exit 1
esac

if [ -z "$PROPOSAL_ID" ]; then
    echo "🚨 No proposal ID provided"
    exit 1
fi

echo "📠 Network is $NETWORK"
celocli config:set --node $RPC_URL

echo "😴 31s" &&\
echo -e "\a" && sleep 31 &&\
echo "✅ Approving proposal $PROPOSAL_ID" &&\
echo "==========================================" &&\
celocli governance:approve --proposalID $PROPOSAL_ID --from $APPROVER --useMultiSig --privateKey $APPROVER_PK &&\
echo "😴 301s" &&\
echo -e "\a" && sleep 301 &&\
echo "🗳️ Voting proposal $PROPOSAL_ID" &&\
echo "==========================================" &&\
celocli governance:vote --value=Yes --from=$SIGNER --proposalID=$PROPOSAL_ID --privateKey $SIGNER_PK &&\
echo "😴 301s" &&\
echo "💃 Executing proposal $PROPOSAL_ID" &&\
echo -e "\a" && sleep 301 &&\
celocli governance:execute --from=$SIGNER --proposalID=$PROPOSAL_ID --privateKey $SIGNER_PK

# Proposal passed, make some noise
echo -e "\a"
echo -e "\a"
echo -e "\a"