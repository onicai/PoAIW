#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/1-build.sh
#######################################################################

LLAMA_CPP_CANISTER_PATH="../../llama_cpp_canister"
cd $LLAMA_CPP_CANISTER_PATH

echo " "
echo "--------------------------------------------------"
echo "Building the wasm for llama_cpp_canister"
make build-info-cpp-wasm
icpp build-wasm
# icpp build-wasm --to-compile mine-no-lib