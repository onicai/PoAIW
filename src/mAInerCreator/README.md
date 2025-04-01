# mAIner Creator Canister

# The files folder

It contains checked in files, created with:

- Files from https://github.com/onicai/llama_cpp_canister/releases/tag/v0.0.1
- did & wasm of the mAIner ctrlb canister

You must manually download:

- [qwen2.5-0.5b-instruct-q8_0.gguf](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF)

# Setup

## Motoko

Install mops (https://mops.one/docs/install)
Install motoko dependencies:

```bash
mops install
```

## Python

Setup python environment:

```bash
conda create --name mainercreator python=3.11
conda activate mainercreator

pip install -r requirements.txt
```

# Deploy

## Using scripts

Run the scripts from funnAI --> See the README in that folder

Note: See Appendix A below for manual deploy steps.

After that initial deployment, to update the code for the mAIner Creator canister:
```bash
scripts/deploy.sh --mode upgrade [--network ic]
scripts/register-game-state.sh [--network ic]
```

### Create a mAIner

```bash
dfx canister call mainer_creator_canister health
dfx canister call mainer_creator_canister whoami
dfx canister call mainer_creator_canister amiController

# ================================================================
# Type: #Own

# Create a mAIner controller canister of type #Own
dfx canister call mainer_creator_canister testCreateMainerControllerCanister '(variant {Own}, null)'
NEW_MAINER_OWN_CANISTER="xxxxx-...-cai"   # copy newCanisterId from printout

# Create one or more llm canister for the just created mAIner controller canister of type #Own
dfx canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_OWN_CANISTER\")"
dfx canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_OWN_CANISTER\")"  # To add another LLM
dfx canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_OWN_CANISTER\")"  # Etc..
# -> No need to save the canister id of the LLM, it is all saved internally...

# ================================================================
# Type: #ShareService & #ShareAgent

# Create a mAIner controller canister of type #ShareService
dfx canister call mainer_creator_canister testCreateMainerControllerCanister '(variant {ShareService}, null)'
NEW_MAINER_SHARE_SERVICE_CANISTER="yyyyy-...-cai"   # copy newCanisterId from printout

# Create one or more llm canisters for use by the just created mAIner ShareService canister
dfx canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_SHARE_SERVICE_CANISTER\")"
dfx canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_SHARE_SERVICE_CANISTER\")" # To add another LLM
dfx canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_SHARE_SERVICE_CANISTER\")" # Etc.

# Create mAIner controller canisters of type #ShareAgent
# -> A ShareAgent canister uses the ShareService and not its own LLMs,
#    so pass the ShareService canister id
dfx canister call mainer_creator_canister testCreateMainerControllerCanister "(variant {ShareAgent}, opt \"$NEW_MAINER_SHARE_SERVICE_CANISTER\")"
NEW_MAINER_SHARE_AGENT_CANISTER="zzzzz-...-cai"   # copy newCanisterId from printout

# You can create more ShareAgent canisters that use the same ShareService
dfx canister call mainer_creator_canister testCreateMainerControllerCanister "(variant {ShareAgent}, opt \"$NEW_MAINER_SHARE_SERVICE_CANISTER\")" 
ANOTHER_MAINER_SHARE_AGENT_CANISTER="zzzzz-...-cai"   # copy newCanisterId from printout
# etc.

# You can verify that a ShareAgent is not allowed to have it's own LLMs
# This will give an error
dfx canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_SHARE_AGENT_CANISTER\")"

###################################################
# TODO:
# We need a mechanism to remove LLM canisters
# We need a mechanism to upgrade the source code of all the canisters, without reinstalling the LLM models
###################################################

## Might come in handy during local testing
dfx ledger fabricate-cycles --canister mainer_creator_canister
```

### Test newly created mAIners

```bash
# Use one of these statements:
# -> To test the mAIner of type #Own
MAINER=$NEW_MAINER_OWN_CANISTER
# -> To test the mAIner of type #ShareAgent, pick one of these
MAINER=$NEW_MAINER_SHARE_AGENT_CANISTER
MAINER=$ANOTHER_MAINER_SHARE_AGENT_CANISTER

# Then run the tests:
# NOTE that these are the manual tests.
# In production, timers will be running, and things will happen automatic.

# Test some helper endpoints
dfx canister call $MAINER amiController [--ic]
dfx canister call $MAINER health [--ic]
dfx canister call $MAINER ready [--ic]
dfx canister call $MAINER checkAccessToLLMs [--ic]
dfx canister call $MAINER getMainerCanisterType [--ic]

# Follow instructions of PoAIW README to generate challenges.
# Then, once they're available in the Game State, call this endpoint.
# (-) A #Own mAIner will pull a challenge, create a response & submit it
# (-) A #ShareAgent mAIner will pull a challenge and send the Challenge to the #ShareService.
#     In the #ShareService canister, it will now sit in the queue
dfx canister call $MAINER triggerChallengeResponseAdmin [--ic]

# For a #ShareAgent mAIner, you must now also trigger the #ShareService canister
# to process an item in the queue to generate a response, and send it to the ShareAgent
# who submits it with the GameState
dfx canister call $NEW_MAINER_SHARE_SERVICE_CANISTER triggerChallengeResponseAdmin [--ic]

# To ensure it all worked, call
dfx canister call $MAINER getSubmittedResponsesAdmin --output json [--ic]
dfx canister call $MAINER getChallengeQueueAdmin --output json [--ic]
dfx canister call $NEW_MAINER_SHARE_SERVICE_CANISTER getChallengeQueueAdmin --output json [--ic]

# or from folder: funnAI
dfx canister call game_state_canister getSubmissionsAdmin --output json [--ic]
dfx canister call game_state_canister getNumSubmissionsAdmin --output json [--ic]
```

---

# Appendix A: Manual deploy steps

The deploy scripts for mAIner Creator automate the following steps:

## Manual Deploy
```bash
# Generate the bindings for the upload scripts and the frontend
dfx generate mainer_creator_canister

# local
dfx deploy mainer_creator_canister

# IC mainnet (caution!)
## development
dfx deploy --network development mainer_creator_canister

## production
dfx deploy --ic mainer_creator_canister

# Set Game State as master canister (you have to deploy that canister first and then return with its id)
# local
dfx canister call mainer_creator_canister setMasterCanisterId '("c5kvi-uuaaa-aaaaa-qaaia-cai")'

# IC mainnet (caution!)
## development
dfx canister call --network development mainer_creator_canister setMasterCanisterId '("")'

## production
dfx canister call --ic mainer_creator_canister setMasterCanisterId '("")'

```

## Manual files upload for mAIner Controller Canister

Run upload script - local:

```bash
# --------------------------------------------------------------------------
# IMPORTANT: ic-py might throw a timeout => patch it here:
# Ubuntu:
# /home/arjaan/miniconda3/envs/<your-env>/lib/python3.10/site-packages/httpx/_config.py
# Mac:
# /Users/arjaan/miniconda3/envs/<your-env>/lib/python3.10/site-packages/httpx/_config.py
# DEFAULT_TIMEOUT_CONFIG = Timeout(timeout=5.0)
DEFAULT_TIMEOUT_CONFIG = Timeout(timeout=99999999.0)
# And perhaps here:
# Ubuntu:
# /home/arjaan/miniconda3/envs/<your-env>/lib/python3.10/site-packages/httpcore/_backends/sync.py #L28-L29
# Mac:
# /Users/arjaan/miniconda3/envs/<your-env>/lib/python3.10/site-packages/httpcore/_backends/sync.py #L28-L29
#
class SyncStream(NetworkStream):
    def __init__(self, sock: socket.socket) -> None:
        self._sock = sock

    def read(self, max_bytes: int, timeout: typing.Optional[float] = None) -> bytes:
        exc_map: ExceptionMapping = {socket.timeout: ReadTimeout, OSError: ReadError}
        with map_exceptions(exc_map):
            # PATCH AB
            timeout = 999999999
            # ENDPATCH
            self._sock.settimeout(timeout)
            return self._sock.recv(max_bytes)
# ------------------------------------------------------------------------

# ========================================================================
# Upload the mainer controller canister wasm
python -m scripts.upload_mainer_controller_canister --network local --canister mainer_creator_canister --wasm files/mainer_ctrlb_canister.wasm --candid src/declarations/mainer_creator_canister/mainer_creator_canister.did
```

Run upload script - IC:

```bash
# To IC
## development
### TODO: Upload the mainer controller canister wasm
python -m scripts.upload_mainer_controller_canister --network development --canister mainer_creator_canister --wasm files/mainer_ctrlb_canister.wasm --candid src/declarations/mainer_creator_canister/mainer_creator_canister.did

## production
### TODO: Upload the mainer controller canister wasm
python -m scripts.upload_mainer_controller_canister --network ic --canister mainer_creator_canister --wasm files/mainer_ctrlb_canister.wasm --candid src/declarations/mainer_creator_canister/mainer_creator_canister.did
```

### Manual files upload for mAIner LLM Canister

Run upload script - local:

```bash
# Upload the mainer LLM canister wasm
python -m scripts.upload_mainer_llm_canister_wasm --network local --canister mainer_creator_canister --wasm files/llama_cpp.wasm --candid src/declarations/mainer_creator_canister/mainer_creator_canister.did

# Upload the mainer LLM model file (gguf)
python -m scripts.upload_mainer_llm_canister_modelfile --network local --canister mainer_creator_canister --wasm files/qwen2.5-0.5b-instruct-q8_0.gguf --candid src/declarations/mainer_creator_canister/mainer_creator_canister.did
```

Run upload script - IC:

```bash
# To IC
## development
### Upload the mainer LLM canister wasm
python -m scripts.upload_mainer_llm_canister_wasm --network development --canister mainer_creator_canister --wasm files/llama_cpp.wasm --candid src/declarations/mainer_creator_canister/mainer_creator_canister.did

## production
### Upload the mainer LLM canister wasm
python -m scripts.upload_mainer_llm_canister_wasm --network ic --canister mainer_creator_canister --wasm files/llama_cpp.wasm --candid src/declarations/mainer_creator_canister/mainer_creator_canister.did
```
