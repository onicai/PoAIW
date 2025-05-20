#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/register-llms-or-mainer-service.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_MAINERS_DEPLOYED=3 # Total number of mainers deployed
MAINER_CANISTER_TYPES=("ShareAgent" "ShareAgent" "Own" )
NUM_LLMS_PER_MAINER_OWN=1
NUM_LLMS_PER_MAINER_SHARE_SERVICE=1
NUM_LLMS_ROUND_ROBIN=1 # how many registered LLMs per mainer/service we actually use

# When deploying local, use canister IDs from .env
source ../../llms/mAIner/.env
source .env # to get CANISTER_ID_MAINER_SERVICE_CANISTER

# none will not use subnet parameter in deploy to ic
SUBNET="none"

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ]; then
                NETWORK_TYPE=$1
                if [ "$NETWORK_TYPE" = "ic" ]; then
                    CANISTER_ID_MAINER_SERVICE_CANISTER='TODO'
                    CANISTER_ID_LLM_0='xflcp-qiaaa-aaaaj-az4nq-cai'
                    CANISTER_ID_LLM_1='xqmtc-raaaa-aaaaj-az4oa-cai'  
                elif [ "$NETWORK_TYPE" = "testing" ]; then
                    CANISTER_ID_MAINER_SERVICE_CANISTER='TODO: testing CANISTER_ID_MAINER_SERVICE_CANISTER'
                    CANISTER_ID_LLM_0='TODO: testing CANISTER_ID_LLM_0'
                    CANISTER_ID_LLM_1='TODO: testing CANISTER_ID_LLM_1'
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

CANISTER_ID_LLMS=(
    $CANISTER_ID_LLM_0
    $CANISTER_ID_LLM_1
    $CANISTER_ID_LLM_2
    $CANISTER_ID_LLM_3
    $CANISTER_ID_LLM_4
    $CANISTER_ID_LLM_5
    $CANISTER_ID_LLM_6
    $CANISTER_ID_LLM_7
    $CANISTER_ID_LLM_8
    $CANISTER_ID_LLM_9
    $CANISTER_ID_LLM_10
    $CANISTER_ID_LLM_11
)

i=0 # LLM index

#######################################################################
echo " "
MAINER="mainer_service_canister"
MAINER_CANISTER_TYPE="ShareService"

echo " "
echo "--------------------------------------------------"
echo "$MAINER of type $MAINER_CANISTER_TYPE with id $CANISTER_ID_MAINER_SERVICE_CANISTER"

echo " "
echo "Checking health endpoint for $MAINER"
output=$(dfx canister call $MAINER health --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "$MAINER is not healthy. Exiting."
    exit 1
else
    echo "$MAINER is healthy."
fi

echo " "
echo "Calling reset_llm_canisters."
output=$(dfx canister call $MAINER reset_llm_canisters --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "Error calling reset_llm_canisters. Exiting."
    exit 1
fi

for n in $(seq 0 $((NUM_LLMS_PER_MAINER_SHARE_SERVICE - 1)));
do
    CANISTER_ID_LLM=${CANISTER_ID_LLMS[$i]}
    echo " "
    echo "registering LLM $i ($CANISTER_ID_LLM) with $MAINER"
    output=$(dfx canister call $MAINER add_llm_canister "(record { canister_id = \"$CANISTER_ID_LLM\" })" --network $NETWORK_TYPE)

    if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
        echo "Error calling add_llm_canister for $CANISTER_ID_LLM. Exiting."
        exit 1
    fi
    ((i++)) # next LLM
done

echo " "
echo "Setting NUM_LLMS_ROUND_ROBIN to $NUM_LLMS_ROUND_ROBIN for $MAINER"
output=$(dfx canister call $MAINER setRoundRobinLLMs "($NUM_LLMS_ROUND_ROBIN)" --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "setRoundRobinLLMs call failed. Exiting."
    exit 1
fi

#######################################################################
echo " "
echo "==================================================="
echo "We have $NUM_MAINERS_DEPLOYED mAIner Agents"
mainer_id_start=0
mainer_id_end=$((NUM_MAINERS_DEPLOYED - 1))

for m in $(seq $mainer_id_start $mainer_id_end)
do
    MAINER="mainer_ctrlb_canister_$m"
    MAINER_CANISTER_ID=${CANISTER_ID_MAINER_CTRLB_CANISTERS[$m]}
    MAINER_CANISTER_TYPE=${MAINER_CANISTER_TYPES[$m]}

    echo " "
    echo "--------------------------------------------------"
    echo "$MAINER ($MAINER_CANISTER_ID) of type $MAINER_CANISTER_TYPE"

    echo " "
    echo "Checking health endpoint for $MAINER"
    output=$(dfx canister call $MAINER health --network $NETWORK_TYPE)

    if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
        echo "$MAINER is not healthy. Exiting."
        exit 1
    else
        echo "$MAINER is healthy."
    fi

    if [ "$MAINER_CANISTER_TYPE" = "Own" ]; then
        echo "Calling reset_llm_canisters."
        output=$(dfx canister call $MAINER reset_llm_canisters --network $NETWORK_TYPE)

        if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
            echo "Error calling reset_llm_canisters. Exiting."
            exit 1
        fi

        for n in $(seq 0 $((NUM_LLMS_PER_MAINER_OWN - 1)));
        do
            CANISTER_ID_LLM=${CANISTER_ID_LLMS[$i]}
            echo "registering LLM $i ($CANISTER_ID_LLM) with $MAINER"
            output=$(dfx canister call $MAINER add_llm_canister "(record { canister_id = \"$CANISTER_ID_LLM\" })" --network $NETWORK_TYPE)

            if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
                echo "Error calling add_llm_canister for $CANISTER_ID_LLM. Exiting."
                exit 1
            fi
            ((i++)) # next LLM
        done

        echo " "
        echo "Setting NUM_LLMS_ROUND_ROBIN to $NUM_LLMS_ROUND_ROBIN  for $MAINER"
        output=$(dfx canister call $MAINER setRoundRobinLLMs "($NUM_LLMS_ROUND_ROBIN)" --network $NETWORK_TYPE)

        if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
            echo "setRoundRobinLLMs call failed. Exiting."
            exit 1
        fi
    elif [ "$MAINER_CANISTER_TYPE" = "ShareAgent" ]; then
        # ------------
        echo "Registering mainer_service_canister ($CANISTER_ID_MAINER_SERVICE_CANISTER) with $MAINER"
        output=$(dfx canister call $MAINER setShareServiceCanisterId "(\"$CANISTER_ID_MAINER_SERVICE_CANISTER\")" --network $NETWORK_TYPE)

        if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
            echo "Error calling setShareServiceCanisterId for $CANISTER_ID_MAINER_SERVICE_CANISTER. Exiting."
            exit 1
        fi

        # ------------
        echo "Registering $MAINER ($MAINER_CANISTER_ID) with the mainer_service_canister"
        MYPRINCIPAL=$(dfx identity get-principal | tr -d '\n')
        output=$(dfx canister call mainer_service_canister addMainerShareAgentCanisterAdmin "(record { address = \"$MAINER_CANISTER_ID\"; canisterType = variant {MainerAgent}; ownedBy = principal \"$MYPRINCIPAL\" })" --network $NETWORK_TYPE)
        
        if [[ "$output" != *"Ok = record"* ]]; then
            if [[ "$output" != "(variant { Err = variant { Other = \"Canister entry already exists\" } })" ]]; then
                echo "Error calling addMainerShareAgentCanisterAdmin for mAIner $MAINER_CANISTER_ID."
                echo $output
            else
                echo "$MAINER ($MAINER_CANISTER_ID) is already registered with the game_state_canister."
            fi
        fi 
    fi
done