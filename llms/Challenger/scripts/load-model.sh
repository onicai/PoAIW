#!/bin/bash

#######################################################################
# For Linux & Mac
#######################################################################
LLAMA_CPP_CANISTER_PATH="../../../../llama_cpp_canister"
export PYTHONPATH="${PYTHONPATH}:$(realpath $LLAMA_CPP_CANISTER_PATH)"

#######################################################################
# run from parent folder as:
# scripts/load-model.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_LLMS_DEPLOYED=2

# The model to deploy (Relative to llama_cpp_canister folder)
MODEL="models/Qwen/Qwen2.5-0.5B-Instruct-GGUF/qwen2.5-0.5b-instruct-q8_0.gguf"
MAX_TOKENS=10

# Smaller test models, with same prompt template as Qwen2.5
# https://huggingface.co/tensorblock/SmolLM2-135M-Instruct-GGUF
# MODEL="models/tensorblock/SmolLM2-135M-Instruct-GGUF/SmolLM2-135M-Instruct-Q4_K_M.gguf"
# MAX_TOKENS=50 # To be tested still for SmolLM2 

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
echo "==================================================="
echo "Loading model for $NUM_LLMS_DEPLOYED llms"
llm_id_start=0
llm_id_end=$((NUM_LLMS_DEPLOYED - 1))

for i in $(seq $llm_id_start $llm_id_end)
do
    (  # Start a subshell to optionally run the commands in parallel for each llm
        
        # Temporary file to store info for each LLM
        temp_file=$(mktemp)

        echo " " >> $temp_file
        echo " "
        echo "--------------------------------------------------" >> $temp_file
        echo "--------------------------------------------------"
        echo "Checking health endpoint for llm_$i"
        echo "Checking health endpoint for llm_$i" >> $temp_file
        output=$(dfx canister call llm_$i health --network $NETWORK_TYPE )

        if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
            echo "llm_$i health check failed. Exiting." >> $temp_file
            echo $output >> $temp_file
            echo "****************************************************************"
            echo "llm_$i health check failed. Exiting."
            cat $temp_file
            rm $temp_file
            echo "****************************************************************"
            exit 1
        else
            echo "llm_$i health check succeeded." >> $temp_file
            echo "llm_$i health check succeeded."
        fi

        echo " " >> $temp_file
        echo " "
        echo "--------------------------------------------------" >> $temp_file
        echo "--------------------------------------------------"
        echo "Calling load_model for llm_$i"
        echo "Calling load_model for llm_$i" >> $temp_file
        output=$(dfx canister call llm_$i load_model \
                '(record { args = vec {"--model"; "models/model.gguf";} })' \
                --network "$NETWORK_TYPE")

        if ! echo "$output" | grep -q " Ok "; then
            echo "llm_$i load_model failed. Exiting." >> $temp_file
            echo $output >> $temp_file
            echo "****************************************************************"
            echo "llm_$i load_model failed. Exiting."
            cat $temp_file
            rm $temp_file
            echo "****************************************************************"
            exit 1
        else
            echo "llm_$i load_model succeeded." >> $temp_file
            echo "llm_$i load_model succeeded."
        fi

        echo " " >> $temp_file
        echo " "
        echo "--------------------------------------------------" >> $temp_file
        echo "--------------------------------------------------"
        echo "Setting max tokens to ($MAX_TOKENS) for llm_$i"
        echo "Setting max tokens to ($MAX_TOKENS) for llm_$i" >> $temp_file
        # output=$(dfx canister call llm_$i set_max_tokens \'(record { max_tokens_query = $MAX_TOKENS : nat64\; max_tokens_update = $MAX_TOKENS : nat64 })\' --network $NETWORK_TYPE )
        output=$(dfx canister call llm_$i set_max_tokens \
                '(record { max_tokens_query = '"$MAX_TOKENS"' : nat64; max_tokens_update = '"$MAX_TOKENS"' : nat64 })' \
                --network "$NETWORK_TYPE")


        if [ "$output" != "(variant { Ok = record { status_code = 200 : nat16 } })" ]; then
            echo "llm_$i set_max_tokens failed. Exiting." >> $temp_file
            echo $output >> $temp_file
            echo "****************************************************************"
            echo "llm_$i set_max_tokens failed. Exiting."
            cat $temp_file
            rm $temp_file
            echo "****************************************************************"
            exit 1
        else
            echo "llm_$i set_max_tokens succeeded." >> $temp_file
            echo "llm_$i set_max_tokens succeeded."
        fi

        # All good if we come here
        echo "llm_$i successfully loaded into memory"
        rm $temp_file # Clean up the temporary file

    # ) & # Run the subshell in the background  (parallel processing)
    ) # Run the subshell in the foreground  (sequential processing)
done
wait # Wait for all background processes to finish