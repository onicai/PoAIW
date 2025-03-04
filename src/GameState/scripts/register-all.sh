#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/register-all.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_MAINERS_DEPLOYED=3 # Total number of mainers deployed

# When deploying local, use canister IDs from .env
source ../Challenger/.env
source ../Judge/.env
source ../mAIner/.env

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
                    CANISTER_ID_CHALLENGER_CTRLB_CANISTER='lxb3x-jyaaa-aaaaj-azzta-cai'
                    CANISTER_ID_JUDGE_CTRLB_CANISTER='xxnvw-4yaaa-aaaaj-az4oq-cai' 
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

#######################################################################
echo " "
echo "--------------------------------------------------"
echo "Checking health endpoint"
output=$(dfx canister call game_state_canister health --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "game_state_canister is not healthy. Exiting."
    exit 1
else
    echo "game_state_canister is healthy."
fi

echo " "
echo "--------------------------------------------------"
echo "Registering Challenger with the game_state_canister"
output=$(dfx canister call game_state_canister addOfficialCanister "(record { address = \"$CANISTER_ID_CHALLENGER_CTRLB_CANISTER\"; canisterType = variant {Challenger} })" --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "Error calling addOfficialCanister for Challenger $CANISTER_ID_CHALLENGER_CTRLB_CANISTER."
    exit 1
else
    echo "Successfully called addOfficialCanister for Challenger $CANISTER_ID_CHALLENGER_CTRLB_CANISTER."
fi

echo " "
echo "--------------------------------------------------"
echo "Registering Judge with the game_state_canister"
output=$(dfx canister call game_state_canister addOfficialCanister "(record { address = \"$CANISTER_ID_JUDGE_CTRLB_CANISTER\"; canisterType = variant {Judge} })" --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "Error calling addOfficialCanister for Judge $CANISTER_ID_JUDGE_CTRLB_CANISTER."
    exit 1
else
    echo "Successfully called addOfficialCanister for Judge $CANISTER_ID_JUDGE_CTRLB_CANISTER."
fi 


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

for m in $(seq $mainer_id_start $mainer_id_end)
do
    CANISTER_ID_MAINER_CTRLB_CANISTER=${CANISTER_ID_MAINER_CTRLB_CANISTERS[$m]}

    echo " "
    echo "--------------------------------------------------"
    echo "Registering mainer_ctrlb_canister_$m ($CANISTER_ID_MAINER_CTRLB_CANISTER) with the game_state_canister"
    MYPRINCIPAL=$(dfx identity get-principal | tr -d '\n')
    output=$(dfx canister call game_state_canister addMainerAgentCanisterAdmin "(record { address = \"$CANISTER_ID_MAINER_CTRLB_CANISTER\"; canisterType = variant {MainerAgent}; ownedBy = principal \"$MYPRINCIPAL\" })" --network $NETWORK_TYPE)
    
    if [[ "$output" != *"Ok = record"* ]]; then
        if [[ "$output" != "(variant { Err = variant { Other = \"Canister entry already exists\" } })" ]]; then
            echo "Error calling addMainerAgentCanisterAdmin for mAIner $CANISTER_ID_MAINER_CTRLB_CANISTER."
            echo $output
        else
            echo "mainer_ctrlb_canister_$m ($CANISTER_ID_MAINER_CTRLB_CANISTER) is already registered with the game_state_canister."
        fi
    else
        echo "Successfully called addMainerAgentCanisterAdmin for mAIner $CANISTER_ID_MAINER_CTRLB_CANISTER."
    fi 
done