#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/register-ctrlb-canister.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_LLMS_DEPLOYED=1
# When deploying local, use CANISTER_ID_JUDGE_CTRLB_CANISTER ID from .env
source ../../src/Judge/.env

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ] || [ "$1" = "demo" ]; then
                NETWORK_TYPE=$1
            else
                echo "Invalid network type: $1. Use 'local', 'development' or 'ic' or 'testing' or 'demo'."
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
if [ "$NETWORK_TYPE" = "development" ] || [ "$NETWORK_TYPE" = "demo" ]; then
    NUM_LLMS_DEPLOYED=2
elif [ "$NETWORK_TYPE" = "ic" ] || [ "$NETWORK_TYPE" = "testing" ]; then
    NUM_LLMS_DEPLOYED=3
fi

# go to the src folder to get the canister ID for judge_ctrlb_canister
cd ../../src/Judge/
CANISTER_ID_JUDGE_CTRLB_CANISTER=$(dfx canister --network $NETWORK_TYPE id judge_ctrlb_canister)
# go back to the current folder
cd ../../llms/Judge/

echo "NUM_LLMS_DEPLOYED : $NUM_LLMS_DEPLOYED"
echo " "
echo "CANISTER_ID_JUDGE_CTRLB_CANISTER: $CANISTER_ID_JUDGE_CTRLB_CANISTER"
echo "Making $CANISTER_ID_JUDGE_CTRLB_CANISTER a controller of LLMs"

#######################################################################
llm_id_start=0
llm_id_end=$((NUM_LLMS_DEPLOYED - 1))

for i in $(seq $llm_id_start $llm_id_end)
do
    echo "==================================================="
    echo "Making $CANISTER_ID_JUDGE_CTRLB_CANISTER a controller of llm_$i"
    dfx canister update-settings llm_$i --add-controller $CANISTER_ID_JUDGE_CTRLB_CANISTER  --network $NETWORK_TYPE
done