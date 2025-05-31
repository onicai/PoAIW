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
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ]; then
                NETWORK_TYPE=$1
            else
                echo "Invalid network type: $1. Use 'local', 'development' or 'ic' or 'testing'."
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

if [ "$NETWORK_TYPE" = "ic" ]; then
    SUBNET="w4asl-4nmyj-qnr7c-6cqq4-tkwmt-o26di-iupkq-vx4kt-asbrx-jzuxh-4ae"
elif [ "$NETWORK_TYPE" = "testing" ]; then
    SUBNET="w4asl-4nmyj-qnr7c-6cqq4-tkwmt-o26di-iupkq-vx4kt-asbrx-jzuxh-4ae"
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
echo "Deploying the mainer_creator_canister"

if [ "$NETWORK_TYPE" = "ic" ] || [ "$NETWORK_TYPE" = "testing" ] || [ "$NETWORK_TYPE" = "development" ]; then
    if [ "$SUBNET" = "none" ]; then
        dfx deploy mainer_creator_canister --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE
    else
        dfx deploy mainer_creator_canister --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE --subnet $SUBNET
    fi
else
    dfx deploy mainer_creator_canister --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE
fi

echo " "
echo "Checking health endpoint"
output=$(dfx canister call mainer_creator_canister health --network $NETWORK_TYPE)

if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
    echo "mainer_creator_canister is not healthy. Exiting."
    exit 1
else
    echo "mainer_creator_canister is healthy."
fi

# echo " "
# echo "Generate the bindings for the upload scripts"
dfx generate
CANDID="src/declarations/mainer_creator_canister/mainer_creator_canister.did"
echo " "
echo "Using the candid file: $CANDID"

echo " "
echo "Upload the mAIner CONTROLLER canister wasm with scripts.upload_mainer_controller_canister"
python -m scripts.upload_mainer_controller_canister --network $NETWORK_TYPE --canister mainer_creator_canister --wasm files/mainer_ctrlb_canister.wasm --candid $CANDID

echo " "
echo "Upload the mAIner LLM canister wasm with scripts.upload_mainer_llm_canister_wasm"
python -m scripts.upload_mainer_llm_canister_wasm --network $NETWORK_TYPE --canister mainer_creator_canister --wasm files/llama_cpp.wasm --candid $CANDID

# Skip this time-consuming step when when upgrading the code
if [ "$DEPLOY_MODE" != "upgrade" ]; then
    # Note:
    # The --hf-sha256 can be found at https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/blob/main/qwen2.5-0.5b-instruct-q8_0.gguf
    echo " "
    echo "Upload the mainer LLM model file (gguf) "
    python -m scripts.upload_mainer_llm_canister_modelfile --network $NETWORK_TYPE \
        --canister mainer_creator_canister \
        --wasm files/qwen2.5-0.5b-instruct-q8_0.gguf  \
        --hf-sha256 "ca59ca7f13d0e15a8cfa77bd17e65d24f6844b554a7b6c12e07a5f89ff76844e" \
        --candid $CANDID
fi