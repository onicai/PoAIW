#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/deploy-judge.sh
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
DEPLOY_MODE="install"

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
echo "******************"
echo "* deploy: Judge *"
echo "*****************"

cd llms/Judge
echo "-llms/Judge: 2-deploy.sh:"
scripts/2-deploy.sh --network $NETWORK_TYPE --mode $DEPLOY_MODE
if [ "$DEPLOY_MODE" != "upgrade" ]; then
    echo "-llms/Judge: 3-upload-model.sh"
    scripts/3-upload-model.sh --network $NETWORK_TYPE
fi
echo "-llms/Judge: 4-load-model.sh"
scripts/4-load-model.sh --network $NETWORK_TYPE
echo "-llms/Judge: 5-set-max-tokens.sh"
scripts/5-set-max-tokens.sh --network $NETWORK_TYPE

cd ../../src/Judge
echo "-src/Judge: deploy.sh"
scripts/deploy.sh --network $NETWORK_TYPE --mode $DEPLOY_MODE
echo "-src/Judge: register-llms.sh"
scripts/register-llms.sh --network $NETWORK_TYPE
echo "-src/Judge: register-game-state.sh"
scripts/register-game-state.sh --network $NETWORK_TYPE

cd ../../llms/Judge
echo "-llms/Judge: 6-register-ctrlb-canister.sh"
scripts/6-register-ctrlb-canister.sh --network $NETWORK_TYPE

echo "-llms/Judge: 7-log-pause.sh"
scripts/7-log-pause.sh --network $NETWORK_TYPE

#######################################################################