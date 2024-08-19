#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../.env"

# Celoscan API endpoint
API_ENDPOINT="https://api.celoscan.io/api"

# Function to check contract verification status
check_celoscan_verification() {
    local contract_address="$1"
    
    # Make API request
    response=$(curl -s "$API_ENDPOINT?module=contract&action=getabi&address=$contract_address&apikey=$CELOSCAN_API_KEY")
    
    # Check response
    if echo "$response" | grep -q '"status":"1"' && echo "$response" | grep -q '"message":"OK"'; then
        echo "Contract $contract_address is verified"
    else
        echo "Contract $contract_address is not verified"
        exit 1
    fi
}

# Main script
if [ $# -eq 0 ]; then
    echo "Usage: $0 <contract_address>"
    exit 1
fi

check_celoscan_verification "$1"
