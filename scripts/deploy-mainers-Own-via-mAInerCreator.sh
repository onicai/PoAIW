#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/deploy-mainers-Own-via-mAInerCreator.sh
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
DEPLOY_MODE="install"

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ]; then
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
cd src/mAInerCreator


if [ "$NETWORK_TYPE" = "local" ]; then
    echo " "
    echo "--------------------------------------------------"
    echo "Adding 20 TCycles to the mAInerCreator canister"
    dfx ledger fabricate-cycles --all --t 20
fi

# ================================================================
# Type: #Own

echo " "
echo "--------------------------------------------------"
echo "Deploying a mAInerController canister of type #Own"
output=$(dfx canister call mainer_creator_canister testCreateMainerControllerCanister '(variant {Own}, null)' --network $NETWORK_TYPE)
echo $output
if [[ "$output" != *"Ok = record"* ]]; then
    echo "Failed to create mAIner controller canister of type #Own. Exiting."    
    exit 1
else
    NEW_MAINER_OWN_CANISTER=$(echo "$output" | sed -n 's/.*newCanisterId = "\([^"]*\)".*/\1/p')
fi

echo " "
echo "Deploy LLM for the mAInerController $NEW_MAINER_OWN_CANISTER of type #Own"
dfx canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_OWN_CANISTER\")"  --network $NETWORK_TYPE
# dfx canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_OWN_CANISTER\")"   --network $NETWORK_TYPE
# dfx canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_OWN_CANISTER\")"  --network $NETWORK_TYPE
# -> No need to save the canister id of the LLM, it is all saved internally...

echo " "
echo "Starting timers for the mAInerController $NEW_MAINER_OWN_CANISTER of type #Own"
dfx canister call $NEW_MAINER_OWN_CANISTER startTimerExecutionAdmin --network $NETWORK_TYPE