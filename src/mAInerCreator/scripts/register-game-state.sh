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
CANISTER_ID_GAME_STATE_CANISTER=$(icp canister status game_state_canister -e $NETWORK_TYPE --id-only)
# go back to the current folder
cd PoAIW/src/mAInerCreator/

#######################################################################
echo " "
echo "--------------------------------------------------"
echo "Checking health endpoint"
output=$(icp canister call mainer_creator_canister health '()' -e $NETWORK_TYPE --query)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "mainer_creator_canister is not healthy. Exiting."
    exit 1
else
    echo "mainer_creator_canister is healthy."
fi

echo " "
echo "--------------------------------------------------"
echo "Registering GameState $CANISTER_ID_GAME_STATE_CANISTER with the mainer_creator_canister"
icp canister call mainer_creator_canister setMasterCanisterId "(\"$CANISTER_ID_GAME_STATE_CANISTER\")" -e $NETWORK_TYPE

echo " "
echo "--------------------------------------------------"
echo "Make GameState $CANISTER_ID_GAME_STATE_CANISTER a controller of the mainer_creator_canister"
icp canister settings update mainer_creator_canister --add-controller $CANISTER_ID_GAME_STATE_CANISTER -e $NETWORK_TYPE