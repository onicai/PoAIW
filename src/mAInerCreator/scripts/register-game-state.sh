#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/register-game-state.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"

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
echo "--------------------------------------------------"
echo "Checking health endpoint"
output=$(dfx canister call mainer_creator_canister health --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "mainer_creator_canister is not healthy. Exiting."
    exit 1
else
    echo "mainer_creator_canister is healthy."
fi

echo " "
echo "--------------------------------------------------"
echo "Registering GameState $CANISTER_ID_GAME_STATE_CANISTER with the mainer_creator_canister"
dfx canister call mainer_creator_canister setMasterCanisterId "(\"$CANISTER_ID_GAME_STATE_CANISTER\")" --network $NETWORK_TYPE