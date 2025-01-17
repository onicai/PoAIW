#!/bin/sh

#######################################################################
# run from parent folder as:
# scripts/whitelist.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_LLMS_DEPLOYED=2
# local...
CTRLB_PRINCIPAL="bw4dl-smaaa-aaaaa-qaacq-cai"

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ]; then
                NETWORK_TYPE=$1
                if [ "$NETWORK_TYPE" = "ic" ]; then
                    CTRLB_PRINCIPAL="....TODO...."
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
llm_id_start=0
llm_id_end=$((NUM_LLMS_DEPLOYED - 1))

for i in $(seq $llm_id_start $llm_id_end)
do
    echo "==================================================="
    echo "Making challenger_ctrlb_canister a controller of llm_$i"
    dfx canister update-settings llm_$i --add-controller $CTRLB_PRINCIPAL
done