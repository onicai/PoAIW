#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/top-off-all.sh --network [local/ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_MAINERS_DEPLOYED=3

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
echo "==========================================="
echo "dfx identity"
dfx identity whoami; echo " "

echo "==========================================="
echo "Wallet balance"
dfx wallet --network $NETWORK_TYPE balance; echo " "

echo "==========================================="
cd src/GameState
echo "Balance of GameState canister:"
dfx canister status game_state_canister --network $NETWORK_TYPE 2>&1 | grep "Balance:"; echo " "

echo "==========================================="
cd ../Challenger
echo "Balance of Challenger canister:"
dfx canister status challenger_ctrlb_canister --network $NETWORK_TYPE 2>&1 | grep "Balance:"; echo " "

echo "==========================================="
cd ../mAIner

MAINER="mainer_service_canister"
echo "Balance of $MAINER:"
dfx canister status $MAINER --network $NETWORK_TYPE 2>&1 | grep "Balance:"; echo " "

mainer_id_start=0
mainer_id_end=$((NUM_MAINERS_DEPLOYED - 1))

for m in $(seq $mainer_id_start $mainer_id_end)
do
    MAINER="mainer_ctrlb_canister_$m"
    echo "Balance of $MAINER:"
    dfx canister status $MAINER --network $NETWORK_TYPE 2>&1 | grep "Balance:"; echo " "
done


echo "==========================================="
cd ../Judge
echo "Balance of Judge canister:"
dfx canister status judge_ctrlb_canister --network $NETWORK_TYPE 2>&1 | grep "Balance:"; echo " "

echo "==========================================="
cd ../../llms/Challenger
echo "Balance of Challenger LLM canisters:"
scripts/balance.sh --network $NETWORK_TYPE

echo "==========================================="
cd ../mAIner
echo "Balance of mAIner LLM canisters:"
scripts/balance.sh --network $NETWORK_TYPE

echo "==========================================="
cd ../Judge
echo "Balance of Judge LLM canisters:"
scripts/balance.sh --network $NETWORK_TYPE