#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/register-ctrlb-canister.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_MAINERS_DEPLOYED=3 # Total number of mainers deployed
MAINER_CANISTER_TYPES=("ShareAgent" "ShareAgent" "Own" )
NUM_LLMS_PER_MAINER_OWN=1
NUM_LLMS_PER_MAINER_SHARE_SERVICE=1
NUM_LLMS_ROUND_ROBIN=1 # how many registered LLMs per mainer/service we actually use
# When deploying local, get from src/mAIner/.env:
# (-) CANISTER_ID_MAINER_CTRLB_CANISTER     #Own
# (-) CANISTER_ID_MAINER_SERVICE_CANISTER   #ShareService
source ../../src/mAIner/.env

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ]; then
                NETWORK_TYPE=$1
                if [ "$NETWORK_TYPE" = "ic" ]; then
                    CANISTER_ID_MAINER_SERVICE_CANISTER='TODO: ic CANISTER_ID_MAINER_SERVICE_CANISTER'
                    CANISTER_ID_MAINER_CTRLB_CANISTER_0="qwlb3-eyaaa-aaaaj-az46q-cai"
                    CANISTER_ID_MAINER_CTRLB_CANISTER_1="q7ikh-sqaaa-aaaaj-az47a-cai"
                elif [ "$NETWORK_TYPE" = "testing" ]; then
                    CANISTER_ID_MAINER_SERVICE_CANISTER='TODO: testing CANISTER_ID_MAINER_SERVICE_CANISTER'
                    CANISTER_ID_MAINER_CTRLB_CANISTER_0='TODO: testing CANISTER_ID_MAINER_CTRLB_CANISTER_0'
                    CANISTER_ID_MAINER_CTRLB_CANISTER_1='TODO: testing CANISTER_ID_MAINER_CTRLB_CANISTER_1'
                fi
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
echo "NUM_LLMS_DEPLOYED : $NUM_LLMS_DEPLOYED"
echo " "
echo "--------------------------------------------------"
echo "We have deployed a total of $NUM_MAINERS_DEPLOYED mainer canisters"


CANISTER_ID_MAINER_CTRLB_CANISTERS=(
    $CANISTER_ID_MAINER_CTRLB_CANISTER_0
    $CANISTER_ID_MAINER_CTRLB_CANISTER_1
    $CANISTER_ID_MAINER_CTRLB_CANISTER_2
    $CANISTER_ID_MAINER_CTRLB_CANISTER_3
    $CANISTER_ID_MAINER_CTRLB_CANISTER_4
    $CANISTER_ID_MAINER_CTRLB_CANISTER_5
    $CANISTER_ID_MAINER_CTRLB_CANISTER_6
    $CANISTER_ID_MAINER_CTRLB_CANISTER_7
    $CANISTER_ID_MAINER_CTRLB_CANISTER_8
    $CANISTER_ID_MAINER_CTRLB_CANISTER_9
    $CANISTER_ID_MAINER_CTRLB_CANISTER_10
    $CANISTER_ID_MAINER_CTRLB_CANISTER_11
)
mainer_id_start=0
mainer_id_end=$((NUM_MAINERS_DEPLOYED - 1))

i=0 # LLM index

# Make the mainer_service_canister a controller of its LLMs
for j in $(seq 0 $((NUM_LLMS_PER_MAINER_SHARE_SERVICE - 1)));
do
    echo " "
    echo "Making mainer_service_canister ($CANISTER_ID_MAINER_SERVICE_CANISTER) a controller of llm_$i"
    dfx canister update-settings llm_$i --add-controller $CANISTER_ID_MAINER_SERVICE_CANISTER  --network $NETWORK_TYPE
    ((i++)) # next LLM
done

# Make the `Own` type mainers controllers of their LLMs
for m in $(seq $mainer_id_start $mainer_id_end)
do
    CANISTER_ID_MAINER_CTRLB_CANISTER=${CANISTER_ID_MAINER_CTRLB_CANISTERS[$m]}
    MAINER_CANISTER_TYPE=${MAINER_CANISTER_TYPES[$m]}
    if [ "$MAINER_CANISTER_TYPE" = "Own" ]; then
        for n in $(seq 0 $((NUM_LLMS_PER_MAINER_OWN - 1)));
        do
            echo " "
            echo "Making mainer_ctrlb_canister_$m ($CANISTER_ID_MAINER_CTRLB_CANISTER) a controller of llm_$i"
            dfx canister update-settings llm_$i --add-controller $CANISTER_ID_MAINER_CTRLB_CANISTER  --network $NETWORK_TYPE
            ((i++)) # next LLM
        done
    fi
done