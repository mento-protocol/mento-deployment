#!/usr/bin/env bash

# Imperfect but simple script to pass governance proposals on Celo tesnets (staging, baklava or alfajores)
set -euo pipefail

# Variables to be defined
# PROPOSAL_JSON_PATH= # Path for json of the proposal
# DESCRIPTION_URL= # Path for the URL containing the proposal
SIGNER=0xfCf982bb4015852e706100B14E21f947a5Bb718E # address that will send the tx
# APPROVER=0xfCf982bb4015852e706100B14E21f947a5Bb718E # approver address
APPROVER=0xb04778c00A8e30F59bFc91DD74853C4f32F34E54 # approver address
# PRIVATE_KEY= # Private key of the approver, safer to define in the command line with `export`

# celocli governance:withdraw --from=$SIGNER || echo "There were no pending refunds" # Optional step, getting some deposits back

PROPOSAL_ID=90

echo "Proposal has ID=$PROPOSAL_ID"

echo -e "\a" && sleep 31 &&\
celocli governance:approve --proposalID $PROPOSAL_ID --from $APPROVER --useMultiSig --privateKey $APPROVER_PRIVATE_KEY &&\
echo -e "\a" && sleep 301 &&\
celocli governance:vote --value=Yes --from=$SIGNER --proposalID=$PROPOSAL_ID --privateKey $SIGNER_PRIVATE_KEY &&\
echo -e "\a" && sleep 301 &&\
celocli governance:execute --from=$SIGNER --proposalID=$PROPOSAL_ID --privateKey $SIGNER_PRIVATE_KEY

# Proposal passed, make some noise
echo -e "\a"
echo -e "\a"
echo -e "\a"

#celocli governance:vote --value=Yes --from=0x456f41406B32c45D59E539e4BBA3D7898c3584dA --proposalID=79