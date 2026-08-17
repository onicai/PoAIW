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
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ] || [ "$1" = "demo" ] || [ "$1" = "prd" ]; then
                NETWORK_TYPE=$1
            else
                echo "Invalid network type: $1. Use 'local' or 'ic' or 'testing' or 'development' or 'demo' or 'prd'."
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
echo "==========================================="
echo "icp identity"
icp identity default

echo " "
echo "==========================================="
echo "Wallet canister for this identity:"
echo "jh35u-eqaaa-aaaag-abf3a-cai   # the funnAI cycles wallet (icp-cli has no wallet concept)"

echo " "
echo "==========================================="
echo "Wallet balance before top-off:"
icp canister call jh35u-eqaaa-aaaag-abf3a-cai wallet_balance '()' -e $NETWORK_TYPE --query

echo " "
echo "==========================================="
cd llms/Challenger
echo "Topping off Challenger LLMs:"
scripts/top-off.sh --network $NETWORK_TYPE

echo "==========================================="
cd ../Judge
echo "Topping off Judge LLMs:"
scripts/top-off.sh --network $NETWORK_TYPE

echo "==========================================="
cd ../../src/GameState
echo "Topping off GameState ctrlb:"
scripts/top-off.sh --network $NETWORK_TYPE

echo "==========================================="
cd ../Challenger
echo "Topping off Challenger ctrlb:"
scripts/top-off.sh --network $NETWORK_TYPE

echo "==========================================="
cd ../Judge
echo "Topping off Judge ctrlb:"
scripts/top-off.sh --network $NETWORK_TYPE

echo "==========================================="
cd ../mAInerCreator
echo "Topping off mAInerCreator ctrlb:"
scripts/top-off.sh --network $NETWORK_TYPE

echo "==========================================="
echo " "
echo "Wallet balance after top-off:"
icp canister call jh35u-eqaaa-aaaag-abf3a-cai wallet_balance '()' -e $NETWORK_TYPE --query