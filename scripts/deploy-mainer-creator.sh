#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/deploy-mainer-creator.sh
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
                echo "Invalid network type: $1. Use 'local' or 'ic' or 'testing."
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
            echo "Usage: $0 --network [local|ic|testing]"
            exit 1
            ;;
    esac
done

echo "Using network type: $NETWORK_TYPE"

#######################################################################
echo " "
echo "******************"
echo "* deploy: mAInerCreator *"
echo "*****************"

cd src/mAInerCreator
echo "-src/mAInerCreator: deploy.sh"
scripts/deploy.sh --network $NETWORK_TYPE --mode $DEPLOY_MODE

echo "-src/mAInerCreator: register-game-state.sh"
scripts/register-game-state.sh --network $NETWORK_TYPE
#######################################################################