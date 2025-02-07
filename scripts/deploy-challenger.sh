#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/deploy-challenger.sh
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
echo " "
echo "**************************"
echo "* deploy: Challenger *"
echo "**************************"

cd llms/Challenger
echo "-llms/Challenger: 2-deploy.sh:"
scripts/2-deploy.sh --network $NETWORK_TYPE --mode $DEPLOY_MODE
if [ "$DEPLOY_MODE" != "upgrade" ]; then
    echo "-llms/Challenger: 3-upload-model.sh"
    scripts/3-upload-model.sh --network $NETWORK_TYPE
fi
echo "-llms/Challenger: 4-load-model.sh"
scripts/4-load-model.sh --network $NETWORK_TYPE
echo "-llms/Challenger: 5-set-max-tokens.sh"
scripts/5-set-max-tokens.sh --network $NETWORK_TYPE

cd ../../src/Challenger
echo "-src/Challenger: deploy.sh"
scripts/deploy.sh --network $NETWORK_TYPE --mode $DEPLOY_MODE
echo "-src/Challenger: register-llms.sh"
scripts/register-llms.sh --network $NETWORK_TYPE

cd ../../llms/Challenger
echo "-llms/Challenger: 6-register-ctrlb-canister.sh"
scripts/6-register-ctrlb-canister.sh --network $NETWORK_TYPE

echo "-llms/Challenger: 7-log-pause.sh"
scripts/7-log-pause.sh --network $NETWORK_TYPE


#######################################################################