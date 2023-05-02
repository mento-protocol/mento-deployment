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
            # For alfajores we don't have access to this,
            # we rely on the signer being unlocked in the node
            SIGNER_PK=""
            RPC_URL=$ALFAJORES_RPC_URL
            CHAIN_ID=44787
            export FOUNDRY_PROFILE=alfajores-deployment
            ;;
        "mainnet")
            RPC_URL=$CELO_RPC_URL
            CHAIN_ID=42220
            export FOUNDRY_PROFILE=celo-deployment
            ;;
        *)
            echo "🚨 Invalid network: '$1'"
            exit 1
    esac
    echo "📠 Network is $NETWORK"
}

parse_upgrade () { # $1: upgrade
    if [ -z "$1" ]; then
        echo "🚨 No upgrade provided"
        exit 1
    fi

    UPGRADE_DIR=script/upgrades/$1
    if test -d "$UPGRADE_DIR"; then
        echo "🔎 Upgrade $1 found"
    else
        echo "🚨 Upgrade $1 not found in $UPGRADE_DIR"
        exit 1
    fi
}

forge_script () { # $1: script name, $2: script file path
    echo "=================================================================="
    echo "🏃🏼 Running $1"
    echo "=================================================================="
    forge script --rpc-url $RPC_URL --legacy --broadcast --verify --verifier sourcify $2
}