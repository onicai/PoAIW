#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/register-llms.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_MAINERS_DEPLOYED=3 # Total number of mainers deployed
NUM_LLMS_ROUND_ROBIN=1 # how many registered LLMs per mainer we actually use

# When deploying local, use canister IDs from .env
source ../../llms/mAIner/.env

# none will not use subnet parameter in deploy to ic
SUBNET="none"

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ]; then
                NETWORK_TYPE=$1
                if [ "$NETWORK_TYPE" = "ic" ]; then
                    CANISTER_ID_LLM_0='xflcp-qiaaa-aaaaj-az4nq-cai'
                    CANISTER_ID_LLM_1='xqmtc-raaaa-aaaaj-az4oa-cai'  
                fi
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

#######################################################################
# What LLM is used by each mAIner
# (-) In demo, we have 3 mainers
# (-) First two share an LLM, the third has its own
CANISTER_ID_LLMS=(
    $CANISTER_ID_LLM_0
    $CANISTER_ID_LLM_0
    $CANISTER_ID_LLM_1
)

echo " "
echo "==================================================="
echo "We have $NUM_MAINERS_DEPLOYED mainers"
mainer_id_start=0
mainer_id_end=$((NUM_MAINERS_DEPLOYED - 1))

for m in $(seq $mainer_id_start $mainer_id_end)
do
    MAINER="mainer_ctrlb_canister_$m"

    echo " "
    echo "--------------------------------------------------"
    echo "Checking health endpoint for $MAINER"
    output=$(dfx canister call $MAINER health --network $NETWORK_TYPE)

    if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
        echo "$MAINER is not healthy. Exiting."
        exit 1
    else
        echo "$MAINER is healthy."
    fi

    echo "Calling reset_llm_canisters."
    output=$(dfx canister call $MAINER reset_llm_canisters --network $NETWORK_TYPE)

    if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
        echo "Error calling reset_llm_canisters. Exiting."
        exit 1
    fi

    CANISTER_ID_LLM=${CANISTER_ID_LLMS[$m]}
    echo "registering LLM $CANISTER_ID_LLM with $MAINER"
    output=$(dfx canister call $MAINER add_llm_canister "(record { canister_id = \"$CANISTER_ID_LLM\" })" --network $NETWORK_TYPE)

    if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
        echo "Error calling add_llm_canister for $CANISTER_ID_LLM. Exiting."
        exit 1
    fi

    echo " "
    echo "--------------------------------------------------"
    echo "Setting NUM_LLMS_ROUND_ROBIN to $NUM_LLMS_ROUND_ROBIN"
    output=$(dfx canister call $MAINER setRoundRobinLLMs "($NUM_LLMS_ROUND_ROBIN)" --network $NETWORK_TYPE)

    if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
        echo "setRoundRobinLLMs call failed. Exiting."
        exit 1
    fi
done