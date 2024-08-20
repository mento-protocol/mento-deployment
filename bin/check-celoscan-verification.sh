#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/../.env"

# Function to get the API endpoint and key based on the network
get_api_info() {
    local network="$1"
    case "$network" in
        "celo")
            echo "https://api.celoscan.io/api" "$CELOSCAN_API_KEY"
            ;;
        "alfajores")
            echo "https://api-alfajores.celoscan.io/api" "$CELOSCAN_ALFAJORES_API_KEY"
            ;;
        *)
            echo "Error: Unsupported network: $network" >&2
            exit 1
            ;;
    esac
}

# Function to check contract verification status
check_celoscan_verification() {
    local address="$1"
    local network="$2"

    read -r api_endpoint api_key < <(get_api_info "$network")

    echo "🌀 Processing address: $address on $network"
    
    # Make API request
    response=$(curl -s "$api_endpoint?module=contract&action=getabi&address=$address&apikey=$api_key")
    
    # Check response
    if echo "$response" | grep -q '"status":"1"' && echo "$response" | grep -q '"message":"OK"'; then
        echo "✅ Contract $address is verified on CeloScan on $network"
    else
        echo "❌ Contract $address is not verified on CeloScan on $network"
        exit 1
    fi
}

# Main script
if [ $# -ne 2 ]; then
    printf "\n"
    echo "Usage: $0 <contract_address> <network>"
    echo "Supported networks: celo, alfajores"
    printf "\n"
    exit 1
fi

check_celoscan_verification "$@"