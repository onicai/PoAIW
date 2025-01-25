#!/bin/bash

#######################################################################
# For Linux & Mac
#######################################################################
LLAMA_CPP_CANISTER_PATH="../../../../llama_cpp_canister"

#######################################################################
echo " "
echo "--------------------------------------------------"
echo "Building the wasm for llama_cpp_canister"
pwd
cd $LLAMA_CPP_CANISTER_PATH
make build-info-cpp-wasm
icpp build-wasm
cd ../DecentralizedAIonIC/PoAIW/llms/Challenger