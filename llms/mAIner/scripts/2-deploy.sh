#!/bin/bash

# Default network type is local
NETWORK_TYPE="local"
NUM_LLMS_DEPLOYED=2
DEPLOY_MODE="install"

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
if [ "$NETWORK_TYPE" = "development" ] || [ "$NETWORK_TYPE" = "demo" ]; then
    NUM_LLMS_DEPLOYED=2
    SUBNET_LLM_0="none"
    SUBNET_LLM_1="none"
elif [ "$NETWORK_TYPE" = "ic" ] || [ "$NETWORK_TYPE" = "testing" ]; then
    NUM_LLMS_DEPLOYED=3
    # Deploy 3 LLMs per subnet
    # https://docs.google.com/spreadsheets/d/1KeyylEYVs3cQvYXOc9RS0q5eWd_vWIW1UVycfDEIkBk/edit?gid=0#gid=0
    # SUBNET-1-1
    SUBNET_LLM_0="qxesv-zoxpm-vc64m-zxguk-5sj74-35vrb-tbgwg-pcird-5gr26-62oxl-cae"
    SUBNET_LLM_1="qxesv-zoxpm-vc64m-zxguk-5sj74-35vrb-tbgwg-pcird-5gr26-62oxl-cae"
    SUBNET_LLM_2="qxesv-zoxpm-vc64m-zxguk-5sj74-35vrb-tbgwg-pcird-5gr26-62oxl-cae"
elif [ "$NETWORK_TYPE" = "prd" ]; then
    NUM_LLMS_DEPLOYED=13
    # Deploy 3 ShareService LLMs per subnet
    # https://docs.google.com/spreadsheets/d/1KeyylEYVs3cQvYXOc9RS0q5eWd_vWIW1UVycfDEIkBk/edit?gid=0#gid=0
    # SUBNET_2_1
    SUBNET_LLM_0="lspz2-jx4pu-k3e7p-znm7j-q4yum-ork6e-6w4q6-pijwq-znehu-4jabe-kqe"
    SUBNET_LLM_1="lspz2-jx4pu-k3e7p-znm7j-q4yum-ork6e-6w4q6-pijwq-znehu-4jabe-kqe"
    SUBNET_LLM_2="lspz2-jx4pu-k3e7p-znm7j-q4yum-ork6e-6w4q6-pijwq-znehu-4jabe-kqe"
    # by accident we deployed a 4th LLM to this subnet, we will leave it in
    SUBNET_LLM_12="lspz2-jx4pu-k3e7p-znm7j-q4yum-ork6e-6w4q6-pijwq-znehu-4jabe-kqe"
    # SUBNET_2_2
    SUBNET_LLM_3="mpubz-g52jc-grhjo-5oze5-qcj74-sex34-omprz-ivnsm-qvvhr-rfzpv-vae"
    SUBNET_LLM_4="mpubz-g52jc-grhjo-5oze5-qcj74-sex34-omprz-ivnsm-qvvhr-rfzpv-vae"
    SUBNET_LLM_5="mpubz-g52jc-grhjo-5oze5-qcj74-sex34-omprz-ivnsm-qvvhr-rfzpv-vae"
    # SUBNET_2_3
    SUBNET_LLM_6="4zbus-z2bmt-ilreg-xakz4-6tyre-hsqj4-slb4g-zjwqo-snjcc-iqphi-3qe"
    SUBNET_LLM_7="4zbus-z2bmt-ilreg-xakz4-6tyre-hsqj4-slb4g-zjwqo-snjcc-iqphi-3qe"
    SUBNET_LLM_8="4zbus-z2bmt-ilreg-xakz4-6tyre-hsqj4-slb4g-zjwqo-snjcc-iqphi-3qe"
    # SUBNET_2_4
    SUBNET_LLM_9="cv73p-6v7zi-u67oy-7jc3h-qspsz-g5lrj-4fn7k-xrax3-thek2-sl46v-jae"
    SUBNET_LLM_10="cv73p-6v7zi-u67oy-7jc3h-qspsz-g5lrj-4fn7k-xrax3-thek2-sl46v-jae"
    SUBNET_LLM_11="cv73p-6v7zi-u67oy-7jc3h-qspsz-g5lrj-4fn7k-xrax3-thek2-sl46v-jae"
fi

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
    if [ "$NETWORK_TYPE" = "ic" ] || [ "$NETWORK_TYPE" = "testing" ] || [ "$NETWORK_TYPE" = "development" ] || [ "$NETWORK_TYPE" = "demo" ] || [ "$NETWORK_TYPE" = "prd" ]; then
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