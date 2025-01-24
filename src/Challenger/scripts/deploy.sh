#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/deploy.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"

# When deploying to IC, we deploy to a specific subnet
# none will not use subnet parameter in deploy to ic
SUBNET="none"
# SUBNET="qdvhd-os4o2-zzrdw-xrcv4-gljou-eztdp-bj326-e6jgr-tkhuc-ql6v2-yqe"

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
echo "--------------------------------------------------"
echo "Deploying the challenger_ctrlb_canister"

if [ "$NETWORK_TYPE" = "ic" ]; then
    if [ "$SUBNET" = "none" ]; then
        dfx deploy challenger_ctrlb_canister -m reinstall --yes --network $NETWORK_TYPE
    else
        dfx deploy challenger_ctrlb_canister -m reinstall --yes --network $NETWORK_TYPE --subnet $SUBNET
    fi
else
    dfx deploy challenger_ctrlb_canister -m reinstall --yes --network $NETWORK_TYPE
fi

echo " "
echo "--------------------------------------------------"
echo "Checking health endpoint"
output=$(dfx canister call challenger_ctrlb_canister health --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "challenger_ctrlb_canister is not healthy. Exiting."
    exit 1
else
    echo "challenger_ctrlb_canister is healthy."
fi

echo " "
echo "--------------------------------------------------"
echo "Generating bindings for a frontend"
dfx generate