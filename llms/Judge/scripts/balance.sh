#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/balance.sh --network [local|ic]
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
if [ "$NETWORK_TYPE" = "development" ] || [ "$NETWORK_TYPE" = "demo" ]; then
    NUM_LLMS_DEPLOYED=2
elif [ "$NETWORK_TYPE" = "ic" ] || [ "$NETWORK_TYPE" = "testing" ]; then
    NUM_LLMS_DEPLOYED=3
elif [ "$NETWORK_TYPE" = "prd" ]; then
    NUM_LLMS_DEPLOYED=14
fi

echo "NUM_LLMS_DEPLOYED : $NUM_LLMS_DEPLOYED"
echo " "

#######################################################################
llm_id_start=0
llm_id_end=$((NUM_LLMS_DEPLOYED - 1))

for i in $(seq $llm_id_start $llm_id_end)
do
	echo " "
    echo "- llm_$i "
    dfx canister status llm_$i --network $NETWORK_TYPE 2>&1 | grep "Balance:"; echo " "
done