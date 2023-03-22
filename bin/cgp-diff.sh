#!/usr/bin/env bash

##############################################################################
# Script for passing a Celo Governance Proposal on a tesnet.
# Usage: ./bin/cgp-diff.sh 
#               -n <baklava|alfajores>  -- network to pass the proposal on
#               -p <proposal_id>        -- proposal ID
# Example: ./bin/cgp-pass.sh -n baklava -p 79
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
PROPOSAL_ID=""
while getopts n:: flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
    esac
done

shift $(($OPTIND - 1))
PROPOSAL_ID_ALPHA=${1-}
PROPOSAL_ID_BETA=${2-}

parse_network "$NETWORK"

if [ -z "$PROPOSAL_ID_ALPHA" ] || [ -z "$PROPOSAL_ID_BETA" ]; then
    echo "🚨 No proposal IDs provided"
    exit 1
fi


CELO_REGISTRY_ADDRESS=0x000000000000000000000000000000000000ce10
GOVERNANCE=$(cast call $CELO_REGISTRY_ADDRESS "getAddressForString(string)(address)" Governance --rpc-url $RPC_URL)
echo "🔗 Using Governance contract at ${GOVERNANCE[@]}"
echo "🕵️ Diffing proposals... $PROPOSAL_ID_ALPHA $PROPOSAL_ID_BETA"

# Get the proposal transactions count
TX_COUNT_ALPHA=$(cast call $GOVERNANCE "getProposal(uint256)(address,uint256,uint256,uint256,string)" $PROPOSAL_ID_ALPHA --rpc-url $RPC_URL | tail -2 | head -1)
TX_COUNT_BETA=$(cast call $GOVERNANCE "getProposal(uint256)(address,uint256,uint256,uint256,string)" $PROPOSAL_ID_BETA --rpc-url $RPC_URL | tail -2 | head -1)

if [ "$TX_COUNT_ALPHA" != "$TX_COUNT_BETA" ]; then
    echo "🚨 Proposal transactions count is different"
    exit 1
fi

echo $TX_COUNT_ALPHA

for ((i = 0; i < $TX_COUNT_ALPHA; ++i)); do
    printf "🕵️ Diffing proposal transaction $i"
    TX_ALPHA=$(cast call $GOVERNANCE "getProposalTransaction(uint256,uint256)" $PROPOSAL_ID_ALPHA $i --rpc-url $RPC_URL)
    TX_BETA=$(cast call $GOVERNANCE "getProposalTransaction(uint256,uint256)" $PROPOSAL_ID_BETA $i --rpc-url $RPC_URL)

    result=$(diff <(echo "$TX_ALPHA") <(echo "$TX_BETA") || true)
    if [ -z "$result" ]; then
        printf "... ✅\n"
        continue
    else
        printf "... ❌\n"
        echo "$result"
    fi

done
