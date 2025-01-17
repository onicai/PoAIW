#!/bin/sh

#######################################################################
# run from parent folder as:
# scripts/balance.sh --network [local|ic]
#######################################################################

# Default network type is local
NETWORK_TYPE="local"
NUM_LLMS_DEPLOYED=2
# local...
CTRLB_PRINCIPAL="bw4dl-smaaa-aaaaa-qaacq-cai"

# Parse command line arguments for network type
while [ $# -gt 0 ]; do
    case "$1" in
        --network)
            shift
            if [ "$1" = "local" ] || [ "$1" = "ic" ]; then
                NETWORK_TYPE=$1
                CTRLB_PRINCIPAL="---TODO"
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
llm_id_start=0
llm_id_end=$((NUM_LLMS_DEPLOYED - 1))

echo "- dfx identity             : "; dfx identity whoami; echo " "
echo "- Wallet balance           : "; dfx wallet --network $NETWORK_TYPE balance; echo " "

for i in $(seq $llm_id_start $llm_id_end)
do
	echo "- llm_$i "; dfx canister status llm_$i --network $NETWORK_TYPE 2>&1 | grep "Balance:"; echo " "
done

echo "- $CTRLB_PRINCIPAL "; dfx canister status $CTRLB_PRINCIPAL --network $NETWORK_TYPE 2>&1 | grep "Balance:"; echo " "