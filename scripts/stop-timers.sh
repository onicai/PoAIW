#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/start-all-timers.sh --network [local/ic]
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
cd src/Challenger
echo "Stopping timer for Challenger:"
dfx canister call challenger_ctrlb_canister stopTimerExecutionAdmin --network $NETWORK_TYPE

echo "==========================================="
cd ../mAIner
echo "Stopping timer for mAIner:"
dfx canister call mainer_ctrlb_canister stopTimerExecutionAdmin --network $NETWORK_TYPE

echo "==========================================="
cd ../Judge
echo "Stopping timer for Judge:"
dfx canister call judge_ctrlb_canister stopTimerExecutionAdmin --network $NETWORK_TYPE

