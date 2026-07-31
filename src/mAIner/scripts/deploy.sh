#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/deploy.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
DEPLOY_MODE="install"

NUM_MAINERS_DEPLOYED=3
MAINER_CANISTER_TYPES=("ShareAgent" "ShareAgent" "Own" )

# When deploying to IC, we deploy to a specific subnet
# none will not use subnet parameter in deploy to ic
# SUBNET="none"
SUBNET="qdvhd-os4o2-zzrdw-xrcv4-gljou-eztdp-bj326-e6jgr-tkhuc-ql6v2-yqe"

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ] || [ "$1" = "demo" ] || [ "$1" = "prd" ]; then
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
            echo "Usage: $0 --network [local|ic|testing|development|demo|prd]"
            exit 1
            ;;
    esac
done

echo "Using network type: $NETWORK_TYPE"

#######################################################################
echo " "
echo "==================================================="
MAINER="mainer_service_canister"
echo "Deploying the protocol's $MAINER"
if [ "$NETWORK_TYPE" = "ic" ] || [ "$NETWORK_TYPE" = "testing" ] || [ "$NETWORK_TYPE" = "development" ] || [ "$NETWORK_TYPE" = "demo" ] || [ "$NETWORK_TYPE" = "prd" ]; then
    if [ "$SUBNET" = "none" ]; then
        icp deploy $MAINER -m $DEPLOY_MODE -e $NETWORK_TYPE -y
    else
        icp deploy $MAINER -m $DEPLOY_MODE --subnet $SUBNET -e $NETWORK_TYPE -y
    fi
else
    icp deploy $MAINER -m $DEPLOY_MODE -e $NETWORK_TYPE -y
fi

echo " "
echo "--------------------------------------------------"
icp canister call $MAINER setMainerCanisterType '(variant {ShareService} )' -e $NETWORK_TYPE
echo "verify getMainerCanisterType: "
icp canister call $MAINER getMainerCanisterType '()' -e $NETWORK_TYPE

echo " "
echo "--------------------------------------------------"
echo "Checking health endpoint"
output=$(icp canister call $MAINER health '()' -e $NETWORK_TYPE --query)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "$MAINER is not healthy. Exiting."
    exit 1
else
    echo "$MAINER is healthy."
fi

#######################################################################
echo " "
echo "==================================================="
echo "Deploying $NUM_MAINERS_DEPLOYED mainer Agents"
mainer_id_start=0
mainer_id_end=$((NUM_MAINERS_DEPLOYED - 1))

for m in $(seq $mainer_id_start $mainer_id_end)
do
    
    MAINER="mainer_ctrlb_canister_$m"

    echo " "
    echo "--------------------------------------------------"
    echo "Deploying $MAINER"

    if [ "$NETWORK_TYPE" = "ic" ] || [ "$NETWORK_TYPE" = "testing" ] || [ "$NETWORK_TYPE" = "development" ] || [ "$NETWORK_TYPE" = "demo" ] || [ "$NETWORK_TYPE" = "prd" ]; then
        if [ "$SUBNET" = "none" ]; then
            icp deploy $MAINER -m $DEPLOY_MODE -e $NETWORK_TYPE -y
        else
            icp deploy $MAINER -m $DEPLOY_MODE --subnet $SUBNET -e $NETWORK_TYPE -y
        fi
    else
        icp deploy $MAINER -m $DEPLOY_MODE -e $NETWORK_TYPE -y
    fi

    echo " "
    echo "--------------------------------------------------"
    echo "setMainerCanisterType to ${MAINER_CANISTER_TYPES[$m]}"
    icp canister call $MAINER setMainerCanisterType "(variant {${MAINER_CANISTER_TYPES[$m]}} )" -e $NETWORK_TYPE
    echo "verify getMainerCanisterType: "
    icp canister call $MAINER getMainerCanisterType '()' -e $NETWORK_TYPE

    echo " "
    echo "--------------------------------------------------"
    echo "Checking health endpoint"
    output=$(icp canister call $MAINER health '()' -e $NETWORK_TYPE --query)

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
# (dfx generate dropped: icp-cli has no equivalent and src/declarations/ is committed)
