#!/bin/bash
set -euo pipefail

printf "\n"

# Extract the network ID from a broadcast file path
get_network_id() {
    local file_path="$1"
    local network_id=$(echo "$file_path" | sed -E 's/.*\/([0-9]+)\/.*/\1/')
    if [ -z "$network_id" ]; then
        echo "Error: Could not extract network ID from file path: $file_path" >&2
        return 1
    fi
    echo "$network_id"
}

# Map network ID to network name
get_network_name() {
    local network_id="$1"
    case "$network_id" in
        "42220")
            echo "celo"
            ;;
        "44787")
            echo "alfajores"
            ;;
        "62320")
            echo "baklava"
            ;;
        *)
            echo "Error: Unsupported network ID: $network_id" >&2
            exit 1
            ;;
    esac
}

# Fetch addresses of newly deployed contracts from broadcast file
fetch_addresses() {
    cat "${broadcast_file}" |
    # This jq expression should find both normal contract deployments AND contracts deployed via factory
    jq -r '
        [
            .transactions[] |
            select(.transactionType == "CREATE") |
            .contractAddress
        ] + [
            .transactions[].additionalContracts[]? |
            select(.transactionType == "CREATE") |
            .address
        ] | .[]
    ' |
    grep -v null
}

# Check one individual broadcast file
process_file() {
    local broadcast_file="$1"
    local exit_status=0

    echo "🔍 Checking $broadcast_file..."
    printf "\n"

    # Check if the file exists
    if [[ ! -f "${broadcast_file}" ]]; then
        echo "❌ Error: Broadcast file not found: $broadcast_file"
        return 1
    fi

    # Extract network ID from the file path
    network_id=$(get_network_id "$broadcast_file")
    if [ $? -ne 0 ]; then
        echo "$network_id"  # This will print the error message
        return 1
    fi

    # Get network name
    network=$(get_network_name "$network_id")

    # Skip checks for Baklava as CeloScan isn't available there
    if [ "$network" == "baklava" ]; then
        echo "ℹ️ Skipping verification check for Baklava network."
        return 0
    fi

    # Find newly deployed addresses and store them in an array
    addresses=($(fetch_addresses "$broadcast_file"))

    # Check if we deployed any new contracts
    if [ ${#addresses[@]} -eq 0 ]; then
        echo "No newly deployed contract addresses found in $broadcast_file. Nothing to check."
        return 0
    fi

    # Loop through each address and check its verification status
    for address in "${addresses[@]}"; do
        if ! ./bin/check-celoscan-verification.sh "$address" "$network"; then
            exit_status=1
        fi
        printf "\n"
    done

    return $exit_status
}

main() {
    local overall_exit_status=0
    echo "------------------------------------------------------------------------"
    echo "🌀 Checking contract verification status for newly deployed contracts..."
    echo "------------------------------------------------------------------------"
    printf "\n"

    # Check if any file paths are provided
    if [ $# -eq 0 ]; then
        echo "❌ Error: No file paths provided."
        echo "Usage: $0 <path_to_broadcast_json_file1> [<path_to_broadcast_json_file2> ...]"
        exit 1
    fi

    # Process each file
    for file in "$@"; do
        if ! process_file "$file"; then
            overall_exit_status=1
        fi
        echo "-----------------------------------"
        printf "\n"
    done

    if [ $overall_exit_status -eq 0 ]; then
        echo "✅ All checked contracts are verified on CeloScan."
    else
        echo "❌ Some contracts are not verified on CeloScan."
    fi

    exit $overall_exit_status
}

main "$@"
exit 1