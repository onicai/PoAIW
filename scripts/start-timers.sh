#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/start-timers.sh --network [local/ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_MAINERS_DEPLOYED=3

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
echo "Starting timer for Challenger:"
dfx canister call challenger_ctrlb_canister startTimerExecutionAdmin --network $NETWORK_TYPE

# the timers for the mAIners are already running as part of the deploy process
# echo "==========================================="
# cd ../mAIner

# MAINER="mainer_service_canister"
# echo "Starting timer for $MAINER:"
# dfx canister call $MAINER startTimerExecutionAdmin --network $NETWORK_TYPE


# mainer_id_start=0
# mainer_id_end=$((NUM_MAINERS_DEPLOYED - 1))

# for m in $(seq $mainer_id_start $mainer_id_end)
# do
#     MAINER="mainer_ctrlb_canister_$m"
#     echo "Starting timer for $MAINER:"
#     dfx canister call $MAINER startTimerExecutionAdmin --network $NETWORK_TYPE
# done

echo "==========================================="
cd ../Judge
echo "Starting timer for Judge:"
dfx canister call judge_ctrlb_canister startTimerExecutionAdmin --network $NETWORK_TYPE

