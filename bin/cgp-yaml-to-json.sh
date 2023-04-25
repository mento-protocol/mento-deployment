#!/usr/bin/env bash

##############################################################################
# Format the yaml output you get from running `celocli governance:show` into
# the json format needed to run `celocli governance:propose`.
#
# Usage: ./bin/cgp-yaml-to-json.sh [path to yaml cgp]
# Example: ./bin/cgp-yaml-to-json.sh ./cgp71.yaml
# 📦 Requires: `yq` and `jq`
#
# ℹ️ Why is this needed?
#
# Up until now all CGPs were submitted on-chain via the `celocli` tooling,
# which required a JSON formatted CGP input file to be passed to the
# command line. This same JSON file would then be submitted to the 
# governance github: https://github.com/celo-org/governance.
# Our tooling, however, doesn't use the `celocli` tooling to submit CGPs, 
# so we don't have a JSON formatted CGP input file.
# But we can reconstruct one from the yaml output of the `celocli` tooling.
#
# 📜 Steps:
# 1. Make sure all contracts are deployed to the Celo Network, if not already ran.
#    yarn deploy -n celo -u MU01
# 2. Start a forked node: 
#    anvil --fork-url $CELO_RPC_URL
# 3. Submit the CGP to the forked node, and get the proposal ID:
#    yarn cgp -n celo -u MU01 -p <phase> -f 
# 4. Get the yaml output of the CGP: 
#    celocli governance:show --proposalID <id> --node http://127.0.0.1:8545 > cgp.yaml
# 5. Transform to json input: 
#    yarn cgp:yaml-to-json cgp.yaml > cgp.json
#
# At this point you have a a cgp.json that's compatible with the celocli tooling.
# This json file can be submitted to the governance github, and can be used to 
# submit proposals via the celocli tooling, but it needs workarounds
# because of issues between contractkit and the forked node.
# However if you manage to submit the transaction that's build by celocli you
# can then use the `yarn cgp:diff` command to get the diff between the proposal
# submitted using the forge scripts and the proposal submitted using the celocli.
##############################################################################

yq -o=json eval '(.. | select(tag == "!!int" or tag == "!!float")) tag= "!!str"' $@\
    | jq '
    def arrayifyStruct($s):
        if $s | type == "object" then
            $s | to_entries | map(select(.key | test("^[0-9]+$"))) | map(arrayifyStruct(.value))
        else
            $s
        end;
    
    .proposal | map({ 
        contract: .contract,
        address: .address,
        function,
        args: (
            .args | 
            to_entries | 
            map(arrayifyStruct(.value))
        ),
        value
        })'