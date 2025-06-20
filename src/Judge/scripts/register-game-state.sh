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
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ] || [ "$1" = "demo" ] || [ "$1" = "prd" ]; then
                NETWORK_TYPE=$1
            else
                echo "Invalid network type: $1. Use 'local', 'development' or 'ic' or 'testing' or 'demo' or 'prd'."
                exit 1
            fi
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 --network [local|ic|testing|development|demo|prd]"
            exit 1
            ;;
    esac
done

echo "Using network type: $NETWORK_TYPE"

# go to the funnAI folder
cd ../../../
CANISTER_ID_GAME_STATE_CANISTER=$(dfx canister --network $NETWORK_TYPE id game_state_canister)
# go back to the current folder
cd PoAIW/src/Judge/

#######################################################################
echo " "
echo "--------------------------------------------------"
echo "Checking health endpoint"
output=$(dfx canister call judge_ctrlb_canister health --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "judge_ctrlb_canister is not healthy. Exiting."
    exit 1
else
    echo "judge_ctrlb_canister is healthy."
fi

echo " "
echo "--------------------------------------------------"
echo "Registering GameState with the judge_ctrlb_canister"
output=$(dfx canister call judge_ctrlb_canister setGameStateCanisterId "(\"$CANISTER_ID_GAME_STATE_CANISTER\")" --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "Error calling setGameStateCanisterId for GameState $CANISTER_ID_GAME_STATE_CANISTER."
    exit 1
else
    echo "Successfully called setGameStateCanisterId for GameState $CANISTER_ID_GAME_STATE_CANISTER."
fi

echo " "
echo "--------------------------------------------------"
echo "Make GameState $CANISTER_ID_GAME_STATE_CANISTER a controller of the judge_ctrlb_canister"
dfx canister update-settings judge_ctrlb_canister --add-controller $CANISTER_ID_GAME_STATE_CANISTER --network $NETWORK_TYPE