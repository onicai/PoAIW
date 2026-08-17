# mAIner Creator Canister

# Build, Deploy and Verify

```bash
# Build wasm with Docker (reproducible build)
# The base image is shared across all canisters. Once built, it can be reused.
make docker-build-base
make docker-build-wasm

# Deploy the pre-built wasm
# Note: Post-SNS, this step is replaced with SNS governed deployment.
icp canister stop mainer_creator_canister -e $NETWORK
icp canister snapshot create mainer_creator_canister -e $NETWORK
icp canister install mainer_creator_canister --wasm out/mainer_creator_canister.wasm \
    -e $NETWORK --mode upgrade --wasm-memory-persistence keep -y
icp canister start mainer_creator_canister -e $NETWORK

# Verify the deployed wasm matches the Docker build
make docker-verify-wasm VERIFY_NETWORK=$NETWORK
```

# Available Makefile targets

```bash
make help
```

# The files folder

These files are uploaded into mAInerCreator canister. 
Create them as follows.

## llama_cpp_canister wasm & did

Build & copy it over.

```bash
# From folder: llama_cpp_canister
# Checkout commit of LLM code
# -> commit `4334e3383a8434d6db85920f5a7e027f3fcdf119` , commit message `v0.6.0rc2`
#
icpp build-wasm
cp build/llama_cpp.did ../funnAI/PoAIW/src/mAInerCreator/files/
cp build/llama_cpp.wasm ../funnAI/PoAIW/src/mAInerCreator/files/
```

## mAIner ctrlb canister wasm & did 

Do a local deploy and copy it over:

```bash
# Start the local network
rm -rf .icp/cache && icp network start

# From folder: PoAIW/src/mAIner
icp deploy mainer_ctrlb_canister_0
icp canister status mainer_ctrlb_canister_0 # Confirm hash matches target hash
cp out/mainer_ctrlb_canister_0.did ../mAInerCreator/files/mainer_ctrlb_canister.did
cp out/mainer_ctrlb_canister_0.wasm ../mAInerCreator/files/mainer_ctrlb_canister.wasm
```

## LLM model

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
see "Build, Deploy and Verify" section above.

```bash
scripts/register-game-state.sh [-e prd]
```

### Create a mAIner

```bash
icp canister call mainer_creator_canister health
icp canister call mainer_creator_canister whoami
icp canister call mainer_creator_canister amiController

# ================================================================
# Type: #Own

# Create a mAIner controller canister of type #Own
icp canister call mainer_creator_canister testCreateMainerControllerCanister '(record {mainerAgentCanisterType = variant {Own}, shareServiceCanisterAddress = null})'
NEW_MAINER_OWN_CANISTER="xxxxx-...-cai"   # copy newCanisterId from printout

# Create one or more llm canister for the just created mAIner controller canister of type #Own
icp canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_OWN_CANISTER\")"
icp canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_OWN_CANISTER\")"  # To add another LLM
icp canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_OWN_CANISTER\")"  # Etc..
# -> No need to save the canister id of the LLM, it is all saved internally...

# ================================================================
# Type: #ShareService & #ShareAgent

# Create a mAIner controller canister of type #ShareService
icp canister call mainer_creator_canister testCreateMainerControllerCanister '(record {mainerAgentCanisterType = variant {ShareService}, shareServiceCanisterAddress = null})'
NEW_MAINER_SHARE_SERVICE_CANISTER="yyyyy-...-cai"   # copy newCanisterId from printout

# Create one or more llm canisters for use by the just created mAIner ShareService canister
icp canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_SHARE_SERVICE_CANISTER\")"
icp canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_SHARE_SERVICE_CANISTER\")" # To add another LLM
icp canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_SHARE_SERVICE_CANISTER\")" # Etc.

# Create mAIner controller canisters of type #ShareAgent
# -> A ShareAgent canister uses the ShareService and not its own LLMs,
#    so pass the ShareService canister id
        mainerAgentCanisterType : MainerAgentCanisterType;
icp canister call mainer_creator_canister testCreateMainerControllerCanister "(record { mainerAgentCanisterType = variant {ShareAgent}, shareServiceCanisterAddress = opt \"$NEW_MAINER_SHARE_SERVICE_CANISTER\"})"
NEW_MAINER_SHARE_AGENT_CANISTER="zzzzz-...-cai"   # copy newCanisterId from printout

# You can create more ShareAgent canisters that use the same ShareService
icp canister call mainer_creator_canister testCreateMainerControllerCanister "(record {mainerAgentCanisterType = variant {ShareAgent}, shareServiceCanisterAddress = opt \"$NEW_MAINER_SHARE_SERVICE_CANISTER\"})" 
ANOTHER_MAINER_SHARE_AGENT_CANISTER="zzzzz-...-cai"   # copy newCanisterId from printout
# etc.

# You can verify that a ShareAgent is not allowed to have it's own LLMs
# This will give an error
icp canister call mainer_creator_canister testCreateMainerLlmCanister "(\"$NEW_MAINER_SHARE_AGENT_CANISTER\")"

###################################################

## Might come in handy during local testing
icp cycles transfer 20t mainer_creator_canister -e local
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
icp canister call $MAINER amiController [--ic]
icp canister call $MAINER health [--ic]
icp canister call $MAINER ready [--ic]
icp canister call $MAINER checkAccessToLLMs [--ic]
icp canister call $MAINER getMainerCanisterType [--ic]

# Follow instructions of PoAIW README to generate challenges.
# Then, once they're available in the Game State, call this endpoint.
# (-) A #Own mAIner will pull a challenge, create a response & submit it
# (-) A #ShareAgent mAIner will pull a challenge and send the Challenge to the #ShareService.
#     In the #ShareService canister, it will now sit in the queue
icp canister call $MAINER triggerChallengeResponseAdmin [--ic]

# For a #ShareAgent mAIner, you must now also trigger the #ShareService canister
# to process an item in the queue to generate a response, and send it to the ShareAgent
# who submits it with the GameState
icp canister call $NEW_MAINER_SHARE_SERVICE_CANISTER triggerChallengeResponseAdmin [--ic]

# To ensure it all worked, call
icp canister call $MAINER getSubmittedResponsesAdmin --output json [--ic]
icp canister call $MAINER getChallengeQueueAdmin --output json [--ic]
icp canister call $NEW_MAINER_SHARE_SERVICE_CANISTER getChallengeQueueAdmin --output json [--ic]

# or from folder: funnAI
icp canister call game_state_canister getSubmissionsAdmin --output json [--ic]
icp canister call game_state_canister getNumSubmissionsAdmin --output json [--ic]
```

---

# Appendix A: Manual deploy steps

```bash
# Set a network
NETWORK=prd
NETWORK=testing
NETWORK=demo
NETWORK=develop
NETWORK=local

# set the gamestate id
# easiest is to go to the funnAI folder to set it, and then come back
cd ../../../
CANISTER_ID_GAME_STATE_CANISTER=$(icp canister status game_state_canister) -e $NETWORK --id-only
cd PoAIW/src/mAInerCreator/
echo "CANISTER_ID_GAME_STATE_CANISTER = $CANISTER_ID_GAME_STATE_CANISTER"

# Generate the bindings for the upload scripts and the frontend
# (no `icp` equivalent to `dfx generate` -- src/declarations/ is committed)

# Deploy & configure
icp deploy   -e $NETWORK mainer_creator_canister --mode [install/reinstall/upgrade]
icp canister call mainer_creator_canister setMasterCanisterId '("'$CANISTER_ID_GAME_STATE_CANISTER'")'
icp canister call mainer_creator_canister getMasterCanisterIdAdmin

# Upload wasm & llm model files
#
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

# Upload the mainer controller canister wasm
python -m scripts.upload_mainer_controller_canister -e $NETWORK --canister mainer_creator_canister --wasm files/mainer_ctrlb_canister.wasm --candid src/declarations/mainer_creator_canister/mainer_creator_canister.did

# Upload the mainer LLM canister wasm
python -m scripts.upload_mainer_llm_canister_wasm -e local --canister mainer_creator_canister --wasm files/llama_cpp.wasm --candid src/declarations/mainer_creator_canister/mainer_creator_canister.did

# Upload the mainer LLM model file (gguf)
python -m scripts.upload_mainer_llm_canister_modelfile -e local --canister mainer_creator_canister --chunksize 2000000 --wasm files/qwen2.5-0.5b-instruct-q8_0.gguf --hf-sha256 "ca59ca7f13d0e15a8cfa77bd17e65d24f6844b554a7b6c12e07a5f89ff76844e" --candid src/declarations/mainer_creator_canister/mainer_creator_canister.did

# Verify the sha256 hashes of all uploaded files
# Warning: do not run this while upload is in process. Wait till it is fully completed.
#          It uses a lazy evaluation logic.
icp canister call mainer_creator_canister getSha256HashesAdmin
```