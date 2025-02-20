# PoAIW - deploy Challenger

This README details the steps for a manual deploy of the Challenger & its LLMs

# Setup

## Clone

Clone the following repos to your local disk using this folder structure:

```
|-DecentralizedAIonIC       (https://github.com/patnorris/DecentralizedAIonIC)
  |-PoAIW                   (https://github.com/onicai/PoAIW)

|-llama_cpp_canister        (https://github.com/onicai/llama_cpp_canister)
  |-src
    |-llama_cpp_onicai_fork (https://github.com/onicai/llama_cpp_onicai_fork)
```

Note: The folder structure is important, because the scripts use relative paths.

## Miniconda

Create a conda environment with python dependencies of `llama_cpp_canister` repo

```bash
# install Miniconda on your system

# create a conda environment
conda create --name llama_cpp_canister python=3.11
conda activate llama_cpp_canister

# from llama_cpp_canister root folder
pip install -r requirements.txt
```

## mops

Install mops (https://mops.one/docs/install), and then:

```bash
# from folder: `PoAIW/src/Challenger`
mops install
```

## Install dfx

```bash
sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)"
```

# Manually deploying Challenger

When deploying locally do it in exactly this order, because dfx updates the `.env` files with the canister ids, and the scripts depend on it.

## Activate conda environment

```bash
conda activate llama_cpp_canister
```

## start dfx

```bash
# when running local, start dfx (if not yet done)
dfx start --clean

```
## Build or Download wasm for llama_cpp_canister

### For mac

```bash
# from folder `DecentralizedAIonIC/PoAIW/llms/Challenger`:

scripts/1-build.sh
```

### For Linux or WSL Ubuntu

The build command only works on Mac.

If you use Linux or WSL Ubuntu, do the following.

Manually download the .did & .wasm files from:
https://drive.google.com/drive/folders/1HAjHWSgANf8XDR6AzurZ-8JPpHDcLXae?usp=sharing

And store them in this location:

```bash
|-llama_cpp_canister   (Note: sibling of DecentralizedAIonIC)
  |-src
    |-llama_cpp.did
  |-build
    |-llama_cpp.wasm
```

To verify the files are in correct relative location:

```bash
# from folder `DecentralizedAIonIC/PoAIW/llms/Challenger`:

ls ../../../../llama_cpp_canister/build/llama_cpp.did
ls ../../../../llama_cpp_canister/build/llama_cpp.wasm
```

## Download LLM model (gguf)

Download the model `qwen2.5-0.5b-instruct-q8_0.gguf` from huggingface: https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF

Store it in the llama_cpp_canister repository at: 

`llama_cpp_canister/models/Qwen/Qwen2.5-0.5B-Instruct-GGUF/qwen2.5-0.5b-instruct-q8_0.gguf`

To verify the file is in the correct relative location:

```bash
# from folder `DecentralizedAIonIC/PoAIW/llms/Challenger`:

ls ../../../../llama_cpp_canister/models/Qwen/Qwen2.5-0.5B-Instruct-GGUF/qwen2.5-0.5b-instruct-q8_0.gguf
```

## Deploy Challenger LLMs

```bash
# from folder `DecentralizedAIonIC/PoAIW/llms/Challenger`:

scripts/2-deploy.sh --mode [install/reinstall/upgrade] --network [local/ic] 

# After an install or reinstall only: upload the model
scripts/3-upload-model.sh --network [local/ic]

# Load the model into OP memory
scripts/4-load-model.sh --network [local/ic]

# Set max tokens  (Update MAX_TOKENS in the script!)
scripts/5-set-max-tokens.sh --network [local/ic]
```

## Deploy Challenger ctrlb canister

```bash
# from folder: `PoAIW/src/Challenger`
scripts/deploy.sh --network [local/ic]
scripts/register-llms.sh  --network [local/ic]
```

## Register Challenger ctrlb canister as controller of LLMs

```bash
# from folder `DecentralizedAIonIC/PoAIW/llms/Challenger`:
scripts/6-register-ctrlb-canister.sh --network [local/ic]
```

## Verify LLMs

```bash
# from folder `DecentralizedAIonIC/PoAIW/llms/Challenger`:
scripts/ready-check.sh --network [local/ic]
```

## Verify Challenger ctrlb canister

```bash
# from folder: `PoAIW/src/Challenger`
scripts/ready-check.sh --network [local/ic]
scripts/register-check.sh --network [local/ic]
```

## Test Challenger with dfx

```bash
# from folder: `PoAIW/src/Challenger`
dfx canister call challenger_ctrlb_canister whoami --ic

# Run with same identity used to deploy (as a controller)
$ dfx canister call challenger_ctrlb_canister amiController --ic
(variant { Ok = record { status_code = 200 : nat16 } })

# This call checks if the challenger_ctrlb_canister is a controller of the LLMs
$ dfx canister call challenger_ctrlb_canister checkAccessToLLMs --ic
(variant { Ok = record { status_code = 200 : nat16 } })

# Generate a new Challenge
$ dfx canister call challenger_ctrlb_canister generateNewChallenge --ic
(
  variant {
    Ok = record {
      generatedByLlmId = "bkyz2-fmaaa-aaaaa-qaaaq-cai";
      generatedChallenge = "What is the process for creating a digital asset that can be stored on a blockchain?";
      generationPrompt = "<|im_start|>user\nAsk a question about crypto, that can be answered with common knowledge. Do NOT give the answer. Start the question with What\n<|im_end|>\n<|im_start|>assistant\n";
      generationId = "746afa0f-7de3-4c5d-92be-b31537a5a365";
      generatedTimestamp = 1_737_487_434_489_711_432 : nat64;
    }
  },
)

## Manage deployed canisters

```bash
# from folder `DecentralizedAIonIC/PoAIW/llms/Challenger`:
scripts/balance.sh --network [local/ic]
scripts/memory.sh --network [local/ic]
scripts/status.sh --network [local/ic]

scripts/top-off.sh --network [local/ic]
```
