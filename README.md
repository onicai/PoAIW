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

Note: on WSL, you might first have to run 
```bash
sudo sysctl -w vm.max_map_count=2097152
```
to successfully load the models in the LLM canisters.

Once completed, challenger_ctrlb_canister should have the canister id br5f7-7uaaa-aaaaa-qaaca-cai

# Deploy Game State canister:
```bash
# from folder: PoAIW/src/GameState
dfx deploy game_state_canister
```
game_state_canister should now have the canister id b77ix-eeaaa-aaaaa-qaada-cai

Once deployed, connect the Game State and Challenger canisters:
```bash
# from folder: PoAIW/src/GameState
dfx canister call game_state_canister addOfficialCanister '(record { address = "br5f7-7uaaa-aaaaa-qaaca-cai"; canisterType = variant {Challenger} })'
# verify with
dfx canister call game_state_canister getOfficialChallengerCanisters
```
```bash
# from folder: PoAIW/src/Challenger
dfx canister call challenger_ctrlb_canister setGameStateCanisterId "b77ix-eeaaa-aaaaa-qaada-cai"
```

# Deploy Judge canister:
```bash
# from folder: PoAIW/src/Judge
dfx deploy judge_ctrlb_canister
```
judge_ctrlb_canister should now have the canister id avqkn-guaaa-aaaaa-qaaea-cai

Once deployed, connect the Game State and Judge canisters:
```bash
# from folder: PoAIW/src/GameState
dfx canister call game_state_canister addOfficialCanister '(record { address = "avqkn-guaaa-aaaaa-qaaea-cai"; canisterType = variant {Judge} })'
```
```bash
# from folder: PoAIW/src/Jugde
dfx canister call judge_ctrlb_canister setGameStateCanisterId "b77ix-eeaaa-aaaaa-qaada-cai"
```

# Create challenges:
```bash
# from folder: PoAIW/src/Challenger
# start the timer that generates challenges recurringly
dfx canister call challenger_ctrlb_canister startTimerExecutionAdmin
# you can also trigger a single challenge generation manually
dfx canister call challenger_ctrlb_canister generateNewChallenge
```

The challenge generation takes a moment. To ensure it worked, call
```bash
# from folder: PoAIW/src/Challenger
dfx canister call challenger_ctrlb_canister getChallengesAdmin

# from folder: PoAIW/src/GameState
dfx canister call game_state_canister getCurrentChallengesAdmin
```