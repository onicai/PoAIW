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

# Deploy ALL canisters:

```bash
# from folder: PoAIW
scripts/build_llama_cpp_canister.sh  # Note: Optional - works on Mac only

# All at once:
# (-) --mode install is slow, because the LLM models are uploaded.
# (-) --mode upgrade is fast, because the LLM models are NOT uploaded.
#       The canisters are re-build and re-deployed, but the LLM models are still in the canister's stable memory.
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

# Test mAIner:
```bash
# from folder: PoAIW/src/mAIner
# start the timer that generates challenge responses recurringly
dfx canister call mainer_ctrlb_canister startTimerExecutionAdmin


# TODO - remove once Create Mainer is functional
# from folder: PoAIW/src/GameState
# register the mAIner agent with the Game State canister for testing as an admin
# NOTE: this is already done by register-all.sh
# dfx canister call game_state_canister addMainerAgentCanisterAdmin "(record { address = \"ahw5u-keaaa-aaaaa-qaaha-cai\"; canisterType = variant {MainerAgent}; ownedBy = principal\"$(dfx identity get-principal)\" })"
# you can also trigger a single challenge response generation manually
dfx canister call mainer_ctrlb_canister triggerChallengeResponseAdmin
```

The challenge response generation takes a moment:
(1) The mAIner uses an LLM to generate a response and submits it to the GameState
(2) The GameState is not storing anything yet. It just forwards the submission to a Judge for scoring
(3) The Judge uses an LLM to score the response and submits the scored submission to the GameState
(4) The GameState now stores the scored submission

To ensure it worked, call
```bash
# from folder: PoAIW/src/mAIner
dfx canister call mainer_ctrlb_canister getSubmittedResponsesAdmin  # TODO

# from folder: PoAIW/src/GameState
dfx canister call game_state_canister get...Admin  # TODO ?
```

# Test Judge
To manually add a Submission to Judge, call
```bash
# from folder: PoAIW/src/Judge
dfx canister call judge_ctrlb_canister addSubmissionToJudge \
  '(record { 
      challengeId = "c-01"; 
      submittedBy = principal "aaaaa-aa"; 
      challengeQuestion = "What is a blockchain?"; 
      challengeAnswer = "A distributed ledger"; 
      submissionId = "s-01"; 
      submittedTimestamp = 1707072000000000000 : nat64; 
      status = variant { Received }
  })'
```

Check the logs, and you will see that the challenge is correctly scored,
and after scoring, send to the GameState for storing.

Because this is a fake challenge, the GameState canister will reject storing
it with a #InvalidId error.