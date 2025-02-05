#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/register-all.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"

# When deploying local, use canister IDs from .env
source ../Challenger/.env
source ../Judge/.env

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
                    CANISTER_ID_CHALLENGER_CTRLB_CANISTER='--todo--'
                    CANISTER_ID_JUDGE_CTRLB_CANISTER='--todo--'  
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