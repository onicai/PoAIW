#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/deploy-mainers-Share.sh
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
DEPLOY_MODE="install"

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ]; then
                NETWORK_TYPE=$1
            else
                echo "Invalid network type: $1. Use 'local' or 'ic'."
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
# Type: #ShareService

echo " "
echo "--------------------------------------------------"
echo "Deploying a mAInerController canister of type #ShareService"

# Create a mAIner controller canister of type #ShareService
output=$(dfx canister call mainer_creator_canister testCreateMainerControllerCanister '(variant {ShareService}, null)' --network $NETWORK_TYPE)
echo $output
if [[ "$output" != *"Ok = record"* ]]; then
    echo "Failed to create mAIner controller canister of type #Own. Exiting."    
    exit 1
else
    NEW_MAINER_SHARE_SERVICE_CANISTER=$(echo "$output" | sed -n 's/.*newCanisterId = "\([^"]*\)".*/\1/p')
fi

echo " "
echo "Deploy LLM for the mAInerController $NEW_MAINER_SHARE_SERVICE_CANISTER of type #ShareService"
dfx canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_SHARE_SERVICE_CANISTER\")" --network $NETWORK_TYPE
# dfx canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_SHARE_SERVICE_CANISTER\")" --network $NETWORK_TYPE
# dfx canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_SHARE_SERVICE_CANISTER\")" --network $NETWORK_TYPE
# -> No need to save the canister id of the LLM, it is all saved internally...

echo " "
echo "Starting timers for the mAInerController $NEW_MAINER_SHARE_SERVICE_CANISTER of type #ShareService"
dfx canister call $NEW_MAINER_SHARE_SERVICE_CANISTER startTimerExecutionAdmin --network $NETWORK_TYPE

echo " "
echo "--------------------------------------------------"
echo "Deploying a mAInerController canister of type #ShareAgent"

# -> A ShareAgent canister uses the ShareService and not its own LLMs,
#    so pass the ShareService canister id
output=$(dfx canister call mainer_creator_canister testCreateMainerControllerCanister "(variant {ShareAgent}, opt \"$NEW_MAINER_SHARE_SERVICE_CANISTER\")" --network $NETWORK_TYPE)
echo $output
if [[ "$output" != *"Ok = record"* ]]; then
    echo "Failed to create mAIner controller canister of type #ShareAgent. Exiting."    
    exit 1
else
    NEW_MAINER_SHARE_AGENT_CANISTER=$(echo "$output" | sed -n 's/.*newCanisterId = "\([^"]*\)".*/\1/p')
fi

echo " "
echo "Starting timers for the mAInerController $NEW_MAINER_SHARE_AGENT_CANISTER of type #ShareAgent"
dfx canister call $NEW_MAINER_SHARE_AGENT_CANISTER startTimerExecutionAdmin --network $NETWORK_TYPE


echo " "
echo "--------------------------------------------------"
echo "Deploying another mAInerController canister of type #ShareAgent"

output=$(dfx canister call mainer_creator_canister testCreateMainerControllerCanister "(variant {ShareAgent}, opt \"$NEW_MAINER_SHARE_SERVICE_CANISTER\")" --network $NETWORK_TYPE)
echo $output
if [[ "$output" != *"Ok = record"* ]]; then
    echo "Failed to create mAIner controller canister of type #ShareAgent. Exiting."    
    exit 1
else
    ANOTHER_MAINER_SHARE_AGENT_CANISTER=$(echo "$output" | sed -n 's/.*newCanisterId = "\([^"]*\)".*/\1/p')
fi

echo " "
echo "Starting timers for the mAInerController $ANOTHER_MAINER_SHARE_AGENT_CANISTER of type #ShareAgent"
dfx canister call $ANOTHER_MAINER_SHARE_AGENT_CANISTER startTimerExecutionAdmin --network $NETWORK_TYPE 

#######################################################################