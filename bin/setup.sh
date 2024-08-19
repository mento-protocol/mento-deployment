set -euo pipefail
source "$(dirname "$0")/../.env"


parse_network () { # $1: network, $2: use_fork
    case $1 in
        "baklava")
            APPROVER=$BAKLAVA_APPROVER
            APPROVER_PK=$BAKLAVA_APPROVER_PK
            SIGNER=$BAKLAVA_SIGNER
            SIGNER_PK=$BAKLAVA_SIGNER_PK
            RPC_URL=$BAKLAVA_RPC_URL
            CHAIN_ID=62320
            export FOUNDRY_PROFILE=baklava-deployment
            ;;
        "alfajores")
            APPROVER=$ALFAJORES_APPROVER
            APPROVER_PK=$ALFAJORES_APPROVER_PK
            SIGNER=$ALFAJORES_SIGNER
            SIGNER_PK=$ALFAJORES_SIGNER_PK
            RPC_URL=$ALFAJORES_RPC_URL
            CHAIN_ID=44787
            export FOUNDRY_PROFILE=alfajores-deployment
            ;;
        "celo")
            RPC_URL=$CELO_RPC_URL
            CHAIN_ID=42220
            export FOUNDRY_PROFILE=celo-deployment
            ;;
        *)
            echo "🚨 Invalid network: '$1'"
            exit 1
    esac
    echo "📠 Network is $NETWORK ($RPC_URL)"
}

parse_proposal () { # $1: proposal
    if [ -z "$1" ]; then
        echo "🚨 No proposal provided"
        exit 1
    fi

    PROPOSAL_DIR=script/proposals/$1
    if test -d "$PROPOSAL_DIR"; then
        if grep -q MentoGovernanceScript "$PROPOSAL_DIR/$1.sol" ; then
            GOVERNANCE="mento"
            BIN_DIR="script/bin/mento"
        elif grep -q CeloGovernanceScript "$PROPOSAL_DIR/$1.sol" ; then
            GOVERNANCE="celo"
            BIN_DIR="script/bin/celo"
        elif grep -q GovernanceScript "$PROPOSAL_DIR/$1.sol" ; then
            # Backwards compatible to v1 scripts
            GOVERNANCE="celo"
            BIN_DIR="script/bin/celo"
        fi
        echo "🔎 Proposal $1 found for $GOVERNANCE governance"
    else
        echo "🚨 Proposal $1 not found in $PROPOSAL_DIR"
        exit 1
    fi
}

forge_skip () { # $1: target
    if [ "dev" = $1 ]; then
        # If target is dev script, skip all proposals
        proposals=$(ls script/proposals | tr '\n' ' ')
        echo "--skip $proposals"
    else
        # if target is a un upgrade, skip dev and other proposals
        other_proposals=$(ls script/proposals | grep -v $1 | tr '\n' ' ')
        echo "--skip dev- $other_proposals"
    fi
}

forge_script () { # $1: script name, $2: script file path
    echo "=================================================================="
    echo "🏃🏼 Running $1"
    echo "=================================================================="
    confirm_if_celo "$NETWORK"
    forge script $3 --rpc-url $RPC_URL --legacy --broadcast --verify --verifier sourcify $2
}

confirm_if_celo () { # $1: network
    if [ "celo" = $1 ]; then
        while true; do
            read -p "  This action will be performed on the Celo mainnet. Are you sure? [y/n]: " answer
            case $answer in
                [Yy]* ) break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
}

countdown() { # $1: seconds
    local seconds=$1
    echo "😴 Sleeping for $seconds seconds"
    for ((i=seconds; i>0; i--)); do
        echo -ne "$i seconds remaining...\033[0K\r"
        sleep 1
    done
}
