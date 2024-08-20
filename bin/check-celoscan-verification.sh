#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../.env"

# Celoscan API endpoint
API_ENDPOINT="https://api.celoscan.io/api"

printf "\n"

# Function to check contract verification status
check_celoscan_verification() {
    local address="$1"

    echo "🌀 Processing address: $address"
    
    # Make API request
    response=$(curl -s "$API_ENDPOINT?module=contract&action=getabi&address=$address&apikey=$CELOSCAN_API_KEY")
    
    # Check response
    if echo "$response" | grep -q '"status":"1"' && echo "$response" | grep -q '"message":"OK"'; then
        echo "✅ Contract $address is verified on Celoscan"
    else
        echo "❌ Contract $address is not verified on CeloScan"
        printf "\n"
        exit 1
    fi
}

# Main script
if [ $# -eq 0 ]; then
    echo "Usage: $0 <contract_address>"
    printf "\n"
    exit 1
fi

check_celoscan_verification "$1"
