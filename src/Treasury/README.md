# Treasury Canister

# Setup

## Motoko

Install mops (https://mops.one/docs/install)
Install motoko dependencies:

```bash
mops install
```

# Deploy

```bash
# Generate the bindings for the upload scripts and the frontend
dfx generate funnai_treasury_canister

# local
dfx deploy funnai_treasury_canister

# IC mainnet (caution!)
## development
dfx deploy --network development funnai_treasury_canister

## production
dfx deploy --network prd funnai_treasury_canister

# Set Game State as master canister (you have to deploy that canister first and then return with its id)
# local
dfx canister call funnai_treasury_canister setMasterCanisterId '("c5kvi-uuaaa-aaaaa-qaaia-cai")'

# IC mainnet (caution!)
## development
dfx canister call --network development funnai_treasury_canister setMasterCanisterId '("")'

## production
dfx canister call --network prd funnai_treasury_canister setMasterCanisterId '("")'

```

```bash
dfx canister call funnai_treasury_canister health
dfx canister call funnai_treasury_canister whoami
dfx canister call funnai_treasury_canister amiController

## Might come in handy during local testing
dfx ledger fabricate-cycles --canister funnai_treasury_canister
```