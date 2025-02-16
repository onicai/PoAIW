# mAIner Creator Canister

### Setup

Install mops (https://mops.one/docs/install)
Install motoko dependencies:

```bash
mops install
```

### Deploy

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

### Upload files

Setup python environment:

```
pip install -r requirements.txt
```

#### mAIner Controller Canister

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

#### mAIner LLM Canister
Run upload script - local:

```bash
# Upload the mainer LLM canister wasm
python -m scripts.upload_mainer_llm_canister_wasm --network local --canister mainer_creator_canister --wasm files/llama_cpp.wasm --candid src/declarations/mainer_creator_canister/mainer_creator_canister.did

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

### Test canister creation

```bash
dfx canister call mainer_creator_canister whoami
dfx canister call mainer_creator_canister amiController

# To test mainer controller canister creation
dfx canister call mainer_creator_canister testCreateMainerControllerCanister

## Call endpoints on created canister
## Note: use newCanisterId printed by testCreateMainerCanister
dfx canister call cgpjn-omaaa-aaaaa-qaakq-cai amiController
dfx canister call cgpjn-omaaa-aaaaa-qaakq-cai health
dfx canister call cgpjn-omaaa-aaaaa-qaakq-cai ready
dfx canister call cgpjn-omaaa-aaaaa-qaakq-cai checkAccessToLLMs

# use canister address of created mainer controller canister, e.g. cgpjn-omaaa-aaaaa-qaakq-cai
dfx canister call mainer_creator_canister testCreateMainerLlmCanister "cgpjn-omaaa-aaaaa-qaakq-cai"

# ----be carefull with these START ---
## In case the canister wasm has to be reset (use with caution):
dfx canister call mainer_creator_canister reset_mainer_controller_canister_wasm

## Might come in handy during local testing
dfx ledger fabricate-cycles --canister mainer_creator_canister
# ----be carefull with these END ---
```
