#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/register-game-state.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ]; then
                NETWORK_TYPE=$1
            else
                echo "Invalid network type: $1. Use 'local', 'development' or 'ic' or 'testing."
                exit 1
            fi
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 --network [local|ic|testing]"
            exit 1
            ;;
    esac
done

echo "Using network type: $NETWORK_TYPE"

# go to the funnAI folder
cd ../../../
CANISTER_ID_GAME_STATE_CANISTER=$(dfx canister --network $NETWORK_TYPE id game_state_canister)
# go back to the current folder
cd PoAIW/src/mAInerCreator/

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

echo " "
echo "--------------------------------------------------"
echo "Make GameState $CANISTER_ID_GAME_STATE_CANISTER a controller of the mainer_creator_canister"
dfx canister update-settings mainer_creator_canister --add-controller $CANISTER_ID_GAME_STATE_CANISTER --network $NETWORK_TYPE