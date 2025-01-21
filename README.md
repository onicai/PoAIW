# PoAIW

Clone this repo into DecentralizedAIonIC

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

# Deploy Challenger canisters (ctrlb + LLMs):

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

## Deploy Challenger LLMs

```bash
# from folder `DecentralizedAIonIC/PoAIW/llms/Challenger`:

# This will:
# (-) build the llama_cpp_canister wasm, using icpp-pro
# (-) re-deploy the wasm to all the llm canisters, with loss of all existing data!
# (-) upload the model (gguf) selected inside the script
scripts/deploy.sh --network [local/ic]
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
scripts/register-ctrlb-canister.sh --network [local/ic]
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
...

## Manage deployed canisters

```bash
# from folder `DecentralizedAIonIC/PoAIW/llms/Challenger`:
scripts/balance.sh --network [local/ic]
scripts/memory.sh --network [local/ic]
scripts/status.sh --network [local/ic]

scripts/top-off.sh --network [local/ic]
```
