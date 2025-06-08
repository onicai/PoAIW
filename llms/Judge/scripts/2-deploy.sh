#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/2-deploy-reinstall.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_LLMS_DEPLOYED=1
DEPLOY_MODE="install"

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ] || [ "$1" = "demo" ]; then
                NETWORK_TYPE=$1
            else
                echo "Invalid network type: $1. Use 'local', 'development' or 'ic' or 'testing' or 'demo'."
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
if [ "$NETWORK_TYPE" = "development" ] || [ "$NETWORK_TYPE" = "demo" ]; then
    NUM_LLMS_DEPLOYED=2
    SUBNET_LLM_0="none"
    SUBNET_LLM_1="none"
elif [ "$NETWORK_TYPE" = "ic" ] || [ "$NETWORK_TYPE" = "testing" ]; then
    NUM_LLMS_DEPLOYED=3
    # Deploy 3 LLMs per subnet
    # https://docs.google.com/spreadsheets/d/1KeyylEYVs3cQvYXOc9RS0q5eWd_vWIW1UVycfDEIkBk/edit?gid=0#gid=0
    # SUBNET-1-1
    SUBNET_LLM_0="pae4o-o6dxf-xki7q-ezclx-znyd6-fnk6w-vkv5z-5lfwh-xym2i-otrrw-fqe"
    SUBNET_LLM_1="pae4o-o6dxf-xki7q-ezclx-znyd6-fnk6w-vkv5z-5lfwh-xym2i-otrrw-fqe"
    SUBNET_LLM_2="pae4o-o6dxf-xki7q-ezclx-znyd6-fnk6w-vkv5z-5lfwh-xym2i-otrrw-fqe"
fi

# go to the funnAI folder
cd ../../../
CANISTER_ID_GAME_STATE_CANISTER=$(dfx canister --network $NETWORK_TYPE id game_state_canister)
# go back to the current folder
cd PoAIW/llms/Judge/

echo " "
echo "--------------------------------------------------"
echo "Calling Game State ($CANISTER_ID_GAME_STATE_CANISTER) setCyclesFlowAdmin to set numJudgeLlms to $NUM_LLMS_DEPLOYED & re-calculate the CyclesFlow variables"
dfx canister call $CANISTER_ID_GAME_STATE_CANISTER setCyclesFlowAdmin "(record {numJudgeLlms = opt ($NUM_LLMS_DEPLOYED : nat);})" --network $NETWORK_TYPE

#######################################################################
echo " "
echo "==================================================="
echo "Deploying $NUM_LLMS_DEPLOYED llms"
llm_id_start=0
llm_id_end=$((NUM_LLMS_DEPLOYED - 1))

for i in $(seq $llm_id_start $llm_id_end)
do
    subnet_var="SUBNET_LLM_$i"
    echo "--------------------------------------------------"
    echo "Deploying llm_$i to subnet ${!subnet_var}"
    if [ "$NETWORK_TYPE" = "ic" ] || [ "$NETWORK_TYPE" = "testing" ] || [ "$NETWORK_TYPE" = "development" ]; then
        if [ "${!subnet_var}" = "none" ]; then
            yes | dfx deploy llm_$i --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE
        else
            yes | dfx deploy llm_$i --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE --subnet ${!subnet_var}
        fi
        if [ "$DEPLOY_MODE" = "install" ]; then
            echo "Initial install to main-net: Waiting for 30 seconds before checking health endpoint for llm_$i"
            sleep 30
        fi
    else
        yes | dfx deploy llm_$i --mode $DEPLOY_MODE --yes --network $NETWORK_TYPE
    fi 
    
    echo " "
    echo "--------------------------------------------------"
    echo "Checking health endpoint for llm_$i"
    output=$(dfx canister call llm_$i health --network $NETWORK_TYPE )

    if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
        echo "llm_$i health check failed."
        echo $output        
        exit 1
    else
        echo "llm_$i health check succeeded."
        echo 🎉
    fi

done