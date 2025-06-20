#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/register-ctrlb-canister.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_LLMS_DEPLOYED=1

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ] || [ "$1" = "demo" ] || [ "$1" = "prd" ]; then
                NETWORK_TYPE=$1
            else
                echo "Invalid network type: $1. Use 'local', 'development' or 'ic' or 'testing' or 'demo' or 'prd'."
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
# Switching to 1 LLM for the Challenger
# if [ "$NETWORK_TYPE" = "ic" ] || [ "$NETWORK_TYPE" = "testing" ] || [ "$NETWORK_TYPE" = "development" ] || [ "$NETWORK_TYPE" = "demo" ] || [ "$NETWORK_TYPE" = "prd" ]; then
#     NUM_LLMS_DEPLOYED=2
# fi

cd ../../src/Challenger/
CANISTER_ID_CHALLENGER_CTRLB_CANISTER=$(dfx canister --network $NETWORK_TYPE id challenger_ctrlb_canister)
# go back
cd ../../llms/Challenger/

echo "NUM_LLMS_DEPLOYED : $NUM_LLMS_DEPLOYED"
echo " "
echo "CANISTER_ID_CHALLENGER_CTRLB_CANISTER: $CANISTER_ID_CHALLENGER_CTRLB_CANISTER"
echo "Making $CANISTER_ID_CHALLENGER_CTRLB_CANISTER a controller of LLMs"
# read -p "Proceed? (yes/no): " confirm
# if [[ $confirm != "yes" ]]; then
#     echo "Aborting script."
#     exit 1
# fi

#######################################################################
llm_id_start=0
llm_id_end=$((NUM_LLMS_DEPLOYED - 1))

for i in $(seq $llm_id_start $llm_id_end)
do
    echo "==================================================="
    echo "Making $CANISTER_ID_CHALLENGER_CTRLB_CANISTER a controller of llm_$i"
    dfx canister update-settings llm_$i --add-controller $CANISTER_ID_CHALLENGER_CTRLB_CANISTER  --network $NETWORK_TYPE
done