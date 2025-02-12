#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/top-off-all.sh --network [local/ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"

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
echo "==========================================="
cd llms/Challenger
echo "Balance of llms/Challenger:"
scripts/balance.sh --network $NETWORK_TYPE

echo "==========================================="
cd ../Judge
echo "Balance of llms/Judge:"
scripts/balance.sh --network $NETWORK_TYPE

echo "==========================================="
cd ../mAIner
echo "Balance of llms/mAIner:"
scripts/balance.sh --network $NETWORK_TYPE