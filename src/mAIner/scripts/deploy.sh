#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/deploy.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
DEPLOY_MODE="install"

NUM_MAINERS_DEPLOYED=3

# When deploying to IC, we deploy to a specific subnet
# none will not use subnet parameter in deploy to ic
# SUBNET="none"
SUBNET="qdvhd-os4o2-zzrdw-xrcv4-gljou-eztdp-bj326-e6jgr-tkhuc-ql6v2-yqe"

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
echo "==================================================="
echo "Deploying $NUM_MAINERS_DEPLOYED mainers"
mainer_id_start=0
mainer_id_end=$((NUM_MAINERS_DEPLOYED - 1))

for m in $(seq $mainer_id_start $mainer_id_end)
do
    
    MAINER="mainer_ctrlb_canister_$m"

    echo " "
    echo "--------------------------------------------------"
    echo "Deploying $MAINER"

    if [ "$NETWORK_TYPE" = "ic" ]; then
        if [ "$SUBNET" = "none" ]; then
            dfx deploy $MAINER --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE
        else
            dfx deploy $MAINER --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE --subnet $SUBNET
        fi
    else
        dfx deploy $MAINER --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE
    fi

    echo " "
    echo "--------------------------------------------------"
    echo "Checking health endpoint"
    output=$(dfx canister call $MAINER health --network $NETWORK_TYPE)

    if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
        echo "$MAINER is not healthy. Exiting."
        exit 1
    else
        echo "$MAINER is healthy."
    fi
done

echo " "
echo "--------------------------------------------------"
echo "Generating bindings for a frontend"
dfx generate