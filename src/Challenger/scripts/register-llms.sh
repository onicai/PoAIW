#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/register-llms.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_LLMS_DEPLOYED=1
NUM_LLMS_ROUND_ROBIN=1 # how many LLMs we actually use

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ]; then
                NETWORK_TYPE=$1
            else
                echo "Invalid network type: $1. Use 'local', 'development' or 'ic' or 'testing."
                exit 1
            fi
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 --network [local|ic|testing]"
            exit 1
            ;;
    esac
done

echo "Using network type: $NETWORK_TYPE"
# Switching to 1 LLM for the Challenger
# if [ "$NETWORK_TYPE" = "ic" ] || [ "$NETWORK_TYPE" = "testing" ] || [ "$NETWORK_TYPE" = "development" ]; then
#     NUM_LLMS_DEPLOYED=2
#     NUM_LLMS_ROUND_ROBIN=2
# fi

#######################################################################
echo " "
echo "--------------------------------------------------"
echo "Checking health endpoint"
output=$(dfx canister call challenger_ctrlb_canister health --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "challenger_ctrlb_canister is not healthy. Exiting."
    exit 1
else
    echo "challenger_ctrlb_canister is healthy."
fi

echo " "
echo "--------------------------------------------------"
echo "Registering $NUM_LLMS_DEPLOYED llm canisterIDs with the challenger_ctrlb_canister"

llm_id_start=0
llm_id_end=$((NUM_LLMS_DEPLOYED - 1))

echo "Calling reset_llm_canisters."
output=$(dfx canister call challenger_ctrlb_canister reset_llm_canisters --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "Error calling reset_llm_canisters. Exiting."
    exit 1
else
    echo "Successfully called reset_llm_canisters."
fi

for i in $(seq $llm_id_start $llm_id_end)
do    
    # go to the llm folder to get the canister ID for llm_$i
    cd ../../llms/Challenger/
    CANISTER_ID_LLM=$(dfx canister --network $NETWORK_TYPE id llm_$i)
    # go back to the current folder
    cd ../../src/Challenger/

    echo "Calling add_llm_canister for llm_$i - $CANISTER_ID_LLM."
    output=$(dfx canister call challenger_ctrlb_canister add_llm_canister "(record { canister_id = \"$CANISTER_ID_LLM\" })" --network $NETWORK_TYPE)

    if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
        echo "Error calling add_llm_canister for $CANISTER_ID_LLM. Exiting."
        exit 1
    else
        echo "Successfully called add_llm_canister for $CANISTER_ID_LLM."
    fi
done

echo " "
echo "--------------------------------------------------"
echo "Setting NUM_LLMS_ROUND_ROBIN to $NUM_LLMS_ROUND_ROBIN"
output=$(dfx canister call challenger_ctrlb_canister setRoundRobinLLMs "($NUM_LLMS_ROUND_ROBIN)" --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "setRoundRobinLLMs call failed. Exiting."
    exit 1
else
    echo "setRoundRobinLLMs was successful."
fi