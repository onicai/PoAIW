#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/deploy.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
DEPLOY_MODE="install"

# When deploying to IC, we deploy to a specific subnet
# none will not use subnet parameter in deploy to ic
# SUBNET="none"
SUBNET="qdvhd-os4o2-zzrdw-xrcv4-gljou-eztdp-bj326-e6jgr-tkhuc-ql6v2-yqe"

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ]; then
                NETWORK_TYPE=$1
            else
                echo "Invalid network type: $1. Use 'local' or 'ic' or 'testing'."
                exit 1
            fi
            shift
            ;;
        --mode)
            shift
            if [ "$1" = "install" ] || [ "$1" = "reinstall" ] || [ "$1" = "upgrade" ]; then
                DEPLOY_MODE=$1
            else
                echo "Invalid mode: $1. Use 'install', 'reinstall' or 'upgrade'."
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
echo "Deploying the game_state_canister"

if [ "$NETWORK_TYPE" = "ic" ] || [ "$NETWORK_TYPE" = "testing" ] || [ "$NETWORK_TYPE" = "development" ]; then
    if [ "$SUBNET" = "none" ]; then
        dfx deploy game_state_canister --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE
    else
        dfx deploy game_state_canister --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE --subnet $SUBNET
    fi
else
    dfx deploy game_state_canister --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE
fi

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
echo "Calling setCyclesFlowAdmin to calculate the CyclesFlow variables"
dfx canister call game_state_canister setCyclesFlowAdmin '(record {})' --network $NETWORK_TYPE

echo " "
echo "Calling setCyclesFlowAdmin to get the CyclesFlow variables"
dfx canister call game_state_canister getCyclesFlowAdmin --network $NETWORK_TYPE

if [ "$DEPLOY_MODE" != "upgrade" ]; then
    echo " "
    echo "--------------------------------------------------"
    echo "Setting initial challenge topics"
    output=$(dfx canister call game_state_canister setInitialChallengeTopics --network $NETWORK_TYPE)

    if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
        echo "setInitialChallengeTopics failed. Exiting."
        exit 1
    else
        echo "setInitialChallengeTopics successfull."
    fi
fi

echo " "
echo "--------------------------------------------------"
echo "Generating bindings for a frontend"
dfx generate