#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/register-check.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_MAINERS_DEPLOYED=3

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ]; then
                NETWORK_TYPE=$1
            else
                echo "Invalid network type: $1. Use 'local' or 'ic'."
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

echo "Using network type: $NETWORK_TYPE"

############################################################################

mainer_id_start=0
mainer_id_end=$((NUM_MAINERS_DEPLOYED - 1))

for m in $(seq $mainer_id_start $mainer_id_end)
do
    MAINER="mainer_ctrlb_canister_$m"
    echo " "
    echo "--------------------------------------------------"
    echo "Checking if $MAINER is a controller of the LLM canisters"
    output=$(dfx canister call $MAINER checkAccessToLLMs --network $NETWORK_TYPE)

    if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
        echo "ERROR: $MAINER is not a controller of all LLMs. Make sure to update the LLMs."
        exit 1
    else
        echo "$MAINER is a controller of all LLMs."
    fi
done