#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/register-game-state.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"

NUM_MAINERS_DEPLOYED=3

# When deploying local, use canister IDs from .env
# Use this when deploying from funnAI
source ../../../.env
# Use this when deploying from PoAIW
# source ../GameState/.env

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
                    CANISTER_ID_GAME_STATE_CANISTER='xzpy6-hiaaa-aaaaj-az4pq-cai' 
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
echo "==================================================="
echo "We have $NUM_MAINERS_DEPLOYED mainers"
mainer_id_start=0
mainer_id_end=$((NUM_MAINERS_DEPLOYED - 1))

for m in $(seq $mainer_id_start $mainer_id_end)
do
    MAINER="mainer_ctrlb_canister_$m"

    echo " "
    echo "--------------------------------------------------"
    echo "Checking health endpoint for $MAINER"
    output=$(dfx canister call $MAINER health --network $NETWORK_TYPE)

    if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
        echo "$MAINER is not healthy. Exiting."
        exit 1
    else
        echo "$MAINER is healthy."
    fi

    echo " "
    echo "--------------------------------------------------"
    echo "Registering GameState with the $MAINER"
    output=$(dfx canister call $MAINER setGameStateCanisterId "(\"$CANISTER_ID_GAME_STATE_CANISTER\")" --network $NETWORK_TYPE)

    if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
        echo "Error calling setGameStateCanisterId for GameState $CANISTER_ID_GAME_STATE_CANISTER."
        exit 1
    else
        echo "Successfully called setGameStateCanisterId for GameState $CANISTER_ID_GAME_STATE_CANISTER."
    fi
done