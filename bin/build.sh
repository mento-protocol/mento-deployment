#!/usr/bin/env bash

##############################################################################
# Build the contracts for a give proposal.
# Usage: ./bin/build.sh 
#               -p <proposal_name>        -- name of the proposal (MU01)
# Example: ./bin/clean.sh -n baklava -p MU01
##############################################################################

source "$(dirname "$0")/setup.sh"

PROPOSAL=""
while getopts p: flag
do
    case "${flag}" in
        p) PROPOSAL=${OPTARG};;
    esac
done

parse_upgrade "$PROPOSAL"
forge clean
forge build $(forge_skip $PROPOSAL) 
