#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/register-check.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_MAINERS_DEPLOYED=3
MAINER_CANISTER_TYPES=("ShareAgent" "ShareAgent" "Own" )

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

echo "Using network type: $NETWORK_TYPE"

############################################################################
MAINER="mainer_service_canister"
echo " "
echo "Checking if $MAINER is a controller of its registered LLM canisters"
output=$(dfx canister call $MAINER checkAccessToLLMs --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "ERROR: $MAINER is not a controller of all its LLMs. Make sure to update the LLMs."
    exit 1
else
    echo "$MAINER is a controller of all its LLMs."
fi


mainer_id_start=0
mainer_id_end=$((NUM_MAINERS_DEPLOYED - 1))

for m in $(seq $mainer_id_start $mainer_id_end)
do
    MAINER="mainer_ctrlb_canister_$m"
    MAINER_CANISTER_TYPE=${MAINER_CANISTER_TYPES[$m]}
    if ($MAINER_CANISTER_TYPE == "Own"); then
        echo " "
        echo "Checking if $MAINER is a controller of its registered LLM canisters"
        output=$(dfx canister call $MAINER checkAccessToLLMs --network $NETWORK_TYPE)

        if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
            echo "ERROR: $MAINER is not a controller of all its LLMs. Make sure to update the LLMs."
            exit 1
        else
            echo "$MAINER is a controller of all its LLMs."
        fi
    fi
done