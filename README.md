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

```bash
# from folder: PoAIW
scripts/deploy-challenger.sh --mode [install/reinstall/upgrade] --network [local/ic]
```