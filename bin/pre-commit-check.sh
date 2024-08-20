#!/bin/bash
set -euo pipefail

printf "\n"

echo "🔍 Checking contract verification status for newly deployed contracts..."

# Check if a file path is provided
if [ $# -eq 0 ]; then
    echo "❌ Error: No file path provided."
    echo "Usage: $0 <path_to_broadcast_json_file>"
    exit 1
fi

# Store the file path from the first argument
broadcast_file="${1}"

# Check if the file exists
if [[ ! -f "${broadcast_file}" ]]; then
    echo "❌ Error: Broadcast file not found: $broadcast_file"
    exit 1
fi

# Fetch addresses of newly deployed contracts from broadcast file
fetch_addresses() {
    cat "${broadcast_file}" |
    jq -r '.transactions[] | select(.transactionType == "CREATE") | .contractAddress' |
    grep -v null
}

# Store addresses in an array
addresses=($(fetch_addresses))

# Check if we deployed any new contracts
if [ ${#addresses[@]} -eq 0 ]; then
    echo "No newly deployed contract addresses found. Nothing to check."
    exit 0
fi

# Loop through each address and check its verification status
for address in "${addresses[@]}"; do
    ./bin/check-celoscan-verification.sh "$address"
    printf "\n"
done