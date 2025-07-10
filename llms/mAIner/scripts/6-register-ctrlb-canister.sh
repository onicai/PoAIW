#!/bin/bash

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
                echo "Invalid network type: $1. Use 'local' or 'ic' or 'testing' or 'development' or 'demo' or 'prd'."
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
elif [ "$NETWORK_TYPE" = "prd" ]; then
    NUM_LLMS_DEPLOYED=13
fi

echo "Using network type: $NETWORK_TYPE"
echo "NUM_LLMS_DEPLOYED : $NUM_LLMS_DEPLOYED"
echo " "
echo "--------------------------------------------------"
echo "We have deployed a total of $NUM_MAINERS_DEPLOYED mainer canisters"

# go to the src folder to get the canister ID for mainer_service_canister
cd ../../src/mAIner/
CANISTER_ID_MAINER_SERVICE_CANISTER=$(dfx canister --network $NETWORK_TYPE id mainer_service_canister)
# go back to the current folder
cd ../../llms/mAIner/

echo "NUM_LLMS_DEPLOYED : $NUM_LLMS_DEPLOYED"
echo " "
echo "CANISTER_ID_MAINER_SERVICE_CANISTER: $CANISTER_ID_MAINER_SERVICE_CANISTER"
echo "Making $CANISTER_ID_MAINER_SERVICE_CANISTER a controller of LLMs"

#######################################################################
llm_id_start=0
llm_id_end=$((NUM_LLMS_DEPLOYED - 1))

for i in $(seq $llm_id_start $llm_id_end)
do
    echo "==================================================="
    echo "Making $CANISTER_ID_MAINER_SERVICE_CANISTER a controller of llm_$i"
    dfx canister update-settings llm_$i --add-controller $CANISTER_ID_MAINER_SERVICE_CANISTER  --network $NETWORK_TYPE
done