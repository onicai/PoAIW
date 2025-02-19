# PoAIW

Clone this repo into funnAI

# Setup

## Clone

Clone the following repos to your local disk using this folder structure:

```
|-funnAI       (https://github.com/onicai/funnAI)
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
# Do this in all these folders:
# - from folder: `PoAIW/src/Challenger`
# - from folder: `PoAIW/src/Judge`
# - from folder: `PoAIW/src/mAIner`
mops install
```

## Install dfx

```bash
sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)"
```

# Download the LLMs from HuggingFace

The scripts expect the *.gguf files to be in the correct location:

```bash
# See: llms/mAIner/scripts/3-upload-model.sh
#      These paths are relative to the llama_cpp_canister root folder
MODELS=(
    "models/tensorblock/SmolLM2-135M-Instruct-GGUF/SmolLM2-135M-Instruct-Q8_0.gguf"
    "models/Qwen/Qwen2.5-0.5B-Instruct-GGUF/qwen2.5-0.5b-instruct-q8_0.gguf"
)

# Download 
# (1) SmolLM2-135M-Instruct-Q8_0.gguf from https://huggingface.co/tensorblock/SmolLM2-135M-Instruct-GGUF
# (2) qwen2.5-0.5b-instruct-q8_0.gguf from https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF

# Verify they're in correct location
# From folder: PoAIW
ls ../../llama_cpp_canister/models/tensorblock/SmolLM2-135M-Instruct-GGUF/SmolLM2-135M-Instruct-Q8_0.gguf
ls ../../llama_cpp_canister/models/Qwen/Qwen2.5-0.5B-Instruct-GGUF/qwen2.5-0.5b-instruct-q8_0.gguf
```

# Deploy ALL canisters:

```bash
# from folder: PoAIW
scripts/build_llama_cpp_canister.sh  # Note: Optional - works on Mac only

# All at once:
# (-) --mode install is slow, because the LLM models are uploaded.
# (-) --mode upgrade is fast, because the LLM models are NOT uploaded.
#       The canisters are re-build and re-deployed, but the LLM models are still in the canister's stable memory.
# (-) When we deployed to ic, the initial installation of each component was done manually
#     to ensure the LLMs ended up on the correct subnet
scripts/deploy-all.sh --mode [install/reinstall/upgrade] --network [local/ic]

# Step-by-step:
scripts/deploy-challenger.sh --mode [install/reinstall/upgrade] --network [local/ic]
scripts/deploy-judge.sh      --mode [install/reinstall/upgrade] --network [local/ic]
scripts/deploy-mainer.sh     --mode [install/reinstall/upgrade] --network [local/ic]
scripts/deploy-gamestate.sh  --mode [install/reinstall/upgrade] --network [local/ic]
```

Note: on WSL, you might first have to run 
```bash
sudo sysctl -w vm.max_map_count=2097152
```
to successfully load the models in the LLM canisters.

# Full system test with timers

```bash
# from folder: PoAIW
scripts/start-timers.sh --network [local/ic]

# from folder: PoAIW/src/GameState

# Verify Challenger challenge generations
dfx canister call game_state_canister getCurrentChallengesAdmin --output json [--ic]

# Verify mAIner response generations
# Note: status changes from #Submitted > #Judging > #Judged
dfx canister call game_state_canister getSubmissionsAdmin --output json [--ic]

# Verify Judge score generations
dfx canister call game_state_canister getScoredChallengesAdmin --output json [--ic]

# from folder: PoAIW
scripts/stop-timers.sh --network [local/ic]
```

NOTE: when working locally, you easily add cycles to the canisters with:
```bash
# From the canister folders: to add 2 trillion cycles
dfx ledger fabricate-cycles --all --t 2
```

# Test components individually

## Test Challenger:
```bash
# from folder: PoAIW/src/Challenger
# start the timer that generates challenges recurringly
dfx canister call challenger_ctrlb_canister startTimerExecutionAdmin [--ic]
# stop the timer that generates challenges recurringly
dfx canister call challenger_ctrlb_canister stopTimerExecutionAdmin [--ic]
# you can also trigger a single challenge generation manually
dfx canister call challenger_ctrlb_canister generateNewChallenge [--ic]
```

The challenge generation takes a moment. To ensure it worked, call
```bash
# from folder: PoAIW/src/Challenger
dfx canister call challenger_ctrlb_canister getChallengesAdmin --output json [--ic]

# from folder: PoAIW/src/GameState
dfx canister call game_state_canister getCurrentChallengesAdmin --output json [--ic]
```

## Test mAIners:

```bash
# from folder: PoAIW/src/mAIner
# start the timer that generates challenge responses recurringly
dfx canister call mainer_ctrlb_canister_0 startTimerExecutionAdmin [--ic]
dfx canister call mainer_ctrlb_canister_1 startTimerExecutionAdmin [--ic]
# stop the timer that generates challenge responses recurringly
dfx canister call mainer_ctrlb_canister_0 stopTimerExecutionAdmin [--ic]
dfx canister call mainer_ctrlb_canister_1 stopTimerExecutionAdmin [--ic]

# you can also trigger a single challenge response generation manually
dfx canister call mainer_ctrlb_canister_0 triggerChallengeResponseAdmin [--ic]
dfx canister call mainer_ctrlb_canister_1 triggerChallengeResponseAdmin [--ic]
```

The response generation takes a moment. To ensure it worked, call
```bash
# from folder: PoAIW/src/mAIner
dfx canister call mainer_ctrlb_canister getSubmittedResponsesAdmin --output json [--ic]

# from folder: PoAIW/src/GameState
dfx canister call game_state_canister getSubmissionsAdmin --output json [--ic]
```

## Test Judge
```bash
# from folder: PoAIW/src/Judge
# start the timer that generates scores recurringly
dfx canister call judge_ctrlb_canister startTimerExecutionAdmin [--ic]
# stop the timer that generates scores recurringly
dfx canister call judge_ctrlb_canister stopTimerExecutionAdmin [--ic]

# you can also trigger a single score generation manually
dfx canister call judge_ctrlb_canister triggerScoreSubmissionAdmin [--ic]
```

To ensure it worked, call
```bash
# from folder: PoAIW/src/GameState
dfx canister call game_state_canister getScoredChallengesAdmin --output json [--ic]
```

## Top off the LLMs

This script will top-off all LLMs to 20 trillion cycles if their balance is below 18 trillion cycles.

It will use cycles from the wallet: 

```bash
# from folder: PoAIW
scripts/top-off-llms.sh --network [local/ic]
```