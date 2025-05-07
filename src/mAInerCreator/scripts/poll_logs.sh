#!/bin/bash

# Default network type is local
NETWORK_TYPE="local"

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ]; then
                NETWORK_TYPE=$1
            else
                echo "Invalid network type: $1. Use 'local' or 'ic' or 'testing'."
                exit 1
            fi
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 --network [local|ic]"
            exit 1
            ;;
    esac
done


# Function to fetch logs and filter out new lines
fetch_and_filter_logs() {
    # Fetch logs
    new_logs=$(dfx canister logs mainer_creator_canister --network "$NETWORK_TYPE")

    # Compare with previous logs to find new ones
    while IFS= read -r line; do
        if [[ ! "${previous_logs[*]}" =~ "$line" ]]; then
            echo "$line"
        fi
    done <<< "$new_logs"

    # Update previous logs
    previous_logs=("$new_logs")
}

# Initial fetch and filter
fetch_and_filter_logs

# Infinite loop to continuously fetch and filter logs
while true; do
    fetch_and_filter_logs
    sleep 1
done