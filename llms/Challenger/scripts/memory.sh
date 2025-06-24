#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/memory.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_LLMS_DEPLOYED=1
# When deploying local, use CANISTER_ID_CHALLENGER_CTRLB_CANISTER ID from .env
# source ../../src/Challenger/.env

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ] || [ "$1" = "demo" ] || [ "$1" = "prd" ]; then
                NETWORK_TYPE=$1
            else
                echo "Invalid network type: $1. Use 'local' or 'ic' or 'testing' or 'demo' or 'prd'."
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
if [ "$NETWORK_TYPE" = "prd" ]; then
    NUM_LLMS_DEPLOYED=2
fi

cd ../../src/Challenger/
CANISTER_ID_CHALLENGER_CTRLB_CANISTER=$(dfx canister --network $NETWORK_TYPE id challenger_ctrlb_canister)
# go back
cd ../../llms/Challenger/

echo "NUM_LLMS_DEPLOYED : $NUM_LLMS_DEPLOYED"
echo " "

#######################################################################
llm_id_start=0
llm_id_end=$((NUM_LLMS_DEPLOYED - 1))

echo " "
echo "- dfx identity"
dfx identity whoami

for i in $(seq $llm_id_start $llm_id_end)
do
    echo " "
	echo "- llm_$i "
    dfx canister status llm_$i --network $NETWORK_TYPE 2>&1 | grep "Memory Size: "
done

echo " "
echo "- CANISTER_ID_CHALLENGER_CTRLB_CANISTER: $CANISTER_ID_CHALLENGER_CTRLB_CANISTER"
dfx canister status $CANISTER_ID_CHALLENGER_CTRLB_CANISTER --network $NETWORK_TYPE 2>&1 | grep "Memory Size: "

echo " "