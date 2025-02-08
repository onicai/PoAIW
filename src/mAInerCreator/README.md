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
dfx generate

# local
dfx deploy mainer_creator_canister

# IC mainnet (caution!)
## development
dfx deploy --network development mainer_creator_canister

## production
dfx deploy --ic mainer_creator_canister

# Set Game State as master canister (you have to deploy that canister first and then return with its id)
# local
dfx canister call mainer_creator_canister setMasterCanisterId '("be2us-64aaa-aaaaa-qaabq-cai")'

# IC mainnet (caution!)
## development
dfx canister call --network development mainer_creator_canister setMasterCanisterId '("sbflw-gyaaa-aaaal-qcbeq-cai")'

## production
dfx canister call --ic mainer_creator_canister setMasterCanisterId '("xzpew-mqaaa-aaaai-acqza-cai")'

```

### Upload files

Setup python environment:

```
pip install -r requirements.txt
```

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
# TODO: Upload the mainer canister wasm
python3 -m scripts.upload_backend_canister --network local --canister mainer_creator_canister --wasm files/DeVinci_backend.wasm --candid src/declarations/mainer_creator_canister/mainer_creator_canister.did
```

Run upload script - IC:

```bash
# To IC
## development
### TODO: Upload the mainer canister wasm
python3 -m scripts.upload_backend_canister --network development --canister mainer_creator_canister --wasm files/DeVinci_backend.wasm --candid src/declarations/mainer_creator_canister/mainer_creator_canister.did

## production
### TODO: Upload the mainer canister wasm
python3 -m scripts.upload_backend_canister --network ic --canister mainer_creator_canister --wasm files/DeVinci_backend.wasm --candid src/declarations/mainer_creator_canister/mainer_creator_canister.did
```

### Test canister creation

```bash
dfx canister call mainer_creator_canister whoami
dfx canister call mainer_creator_canister amiController

# To test mainer canister creation
dfx canister call mainer_creator_canister testCreateMainerCanister

## Call endpoints on created canister
## Note: use newCanisterId printed by testCreateMainerCanister
# TODO
dfx canister call b77ix-eeaaa-aaaaa-qaada-cai size
dfx canister call b77ix-eeaaa-aaaaa-qaada-cai check_cycles_and_topup

# ----be carefull with these START ---
## In case the canister wasm has to be reset (use with caution):
dfx canister call mainer_creator_canister reset_mainer_canister_wasm

## Might come in handy during local testing
dfx ledger fabricate-cycles --canister mainer_creator_canister
# ----be carefull with these END ---
```
