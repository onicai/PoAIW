#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/deploy.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
DEPLOY_MODE="install"

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ] || [ "$1" = "demo" ] || [ "$1" = "prd" ]; then
                NETWORK_TYPE=$1
            else
                echo "Invalid network type: $1. Use 'local', 'development' or 'ic' or 'testing' or 'demo' or 'prd'."
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

if [ "$NETWORK_TYPE" = "ic" ]; then
    SUBNET="csyj4-zmann-ys6ge-3kzi6-onexi-obayx-2fvak-zersm-euci4-6pslt-lae"
elif [ "$NETWORK_TYPE" = "testing" ]; then
    SUBNET="csyj4-zmann-ys6ge-3kzi6-onexi-obayx-2fvak-zersm-euci4-6pslt-lae"
elif [ "$NETWORK_TYPE" = "prd" ]; then
    SUBNET="snjp4-xlbw4-mnbog-ddwy6-6ckfd-2w5a2-eipqo-7l436-pxqkh-l6fuv-vae"
elif [ "$NETWORK_TYPE" = "development" ]; then
    SUBNET="none"  # TODO
else
    SUBNET="none"  # No specific subnet for local
fi

echo "Using network type : $NETWORK_TYPE"
echo "Deploying to subnet: $SUBNET"

#######################################################################

echo " "
echo "--------------------------------------------------"
echo "Deploying the challenger_ctrlb_canister"

if [ "$NETWORK_TYPE" = "ic" ] || [ "$NETWORK_TYPE" = "testing" ] || [ "$NETWORK_TYPE" = "development" ] || [ "$NETWORK_TYPE" = "demo" ] || [ "$NETWORK_TYPE" = "prd" ]; then
    if [ "$SUBNET" = "none" ]; then
        dfx deploy challenger_ctrlb_canister --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE
    else
        dfx deploy challenger_ctrlb_canister --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE --subnet $SUBNET
    fi
else
    dfx deploy challenger_ctrlb_canister --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE
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