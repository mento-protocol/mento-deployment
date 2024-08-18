#!/usr/bin/env bash

##############################################################################
# Script for submitting Governance Proposals for a protocol upgrade.
# Usage: yarn gov
#               -n <baklava|alfajores|celo>  -- network to submit the proposal to
#               -p <proposal_name>           -- name of the proposal (MU01)
#               -s                           -- simulate the proposal (optional)
#               -r                           -- revert (optional)
#               -f                           -- use forked network (optional)
# Example: yarn gov -n baklava -p MU01
##############################################################################

source "$(dirname "$0")/setup.sh"

NETWORK=""
PROPOSAL=""
SIMULATE=false
USE_FORK=false
REVERT=false
while getopts n:p:g:sfr flag
do
    case "${flag}" in
        n) NETWORK=${OPTARG};;
        p) PROPOSAL=${OPTARG};;
        s) SIMULATE=true;;
        f) USE_FORK=true;;
        r) REVERT=true;;
    esac
done

parse_network "$NETWORK"
parse_proposal "$PROPOSAL"

if [ "$USE_FORK" = true ] ; then
    # Make sure you're running a local anvil node:
    # anvil --fork-url ...
    RPC_URL="http://127.0.0.1:8545"
    echo "🍴 Submitting to forked network"
fi


if [ "$REVERT" = true ] ; then
    CONTRACT=$PROPOSAL'Revert'
    echo "🔄 Reverting $PROPOSAL via $CONTRACT"
else
    CONTRACT=$PROPOSAL
    echo "🔥 Submitting $PROPOSAL via $CONTRACT"
fi

if [ "$SIMULATE" = true ] ; then
    echo "🥸 Simulating $CONTRACT"
    ./bin/build.sh -u $PROPOSAL
    forge script $(forge_skip $PROPOSAL) --rpc-url $RPC_URL --sig "run(string)" script/bin/SimulateProposal.sol:SimulateProposal $CONTRACT -vvvv
else 
    echo "🔥 Submitting $CONTRACT"
    confirm_if_celo "$NETWORK"
    forge script $(forge_skip $PROPOSAL) --rpc-url $RPC_URL --legacy --broadcast ${CONTRACT}
fi



