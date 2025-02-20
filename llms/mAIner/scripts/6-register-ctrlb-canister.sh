#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/register-ctrlb-canister.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_MAINERS_DEPLOYED=2 # Total number of mainers deployed
NUM_LLMS_DEPLOYED=2 # Total number of LLMs deployed for use by all mainers
NUM_LLMS_PER_MAINER=1 # Number of LLMs registered with each mainer 
NUM_LLMS_ROUND_ROBIN=1 # how many registered LLMs per mainer we actually use
# When deploying local, use CANISTER_ID_MAINER_CTRLB_CANISTER ID from .env
source ../../src/mAIner/.env

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ]; then
                NETWORK_TYPE=$1
                if [ "$NETWORK_TYPE" = "ic" ]; then
                    CANISTER_ID_MAINER_CTRLB_CANISTER_0="qwlb3-eyaaa-aaaaj-az46q-cai"
                    CANISTER_ID_MAINER_CTRLB_CANISTER_1="q7ikh-sqaaa-aaaaj-az47a-cai"
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
for m in $(seq $mainer_id_start $mainer_id_end)
do
    CANISTER_ID_MAINER_CTRLB_CANISTER=${CANISTER_ID_MAINER_CTRLB_CANISTERS[$m]}
    for n in $(seq 0 $((NUM_LLMS_PER_MAINER - 1)));
    do
        echo "==================================================="
        echo "Making mainer_ctrlb_canister_$m ($CANISTER_ID_MAINER_CTRLB_CANISTER) a controller of llm_$i"
        dfx canister update-settings llm_$i --add-controller $CANISTER_ID_MAINER_CTRLB_CANISTER  --network $NETWORK_TYPE
        ((i++)) # next LLM
    done
done