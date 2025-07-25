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
dfx canister call --network development funnai_treasury_canister setMasterCanisterId '("ciqqv-4iaaa-aaaag-auara-cai")'

## demo
dfx canister call --network demo funnai_treasury_canister setMasterCanisterId '("4tr6r-mqaaa-aaaae-qfcta-cai")'

## production
dfx canister call --network prd funnai_treasury_canister setMasterCanisterId '("r5m5y-diaaa-aaaaa-qanaa-cai")'

```

```bash
dfx canister call funnai_treasury_canister health --network $NETWORK
dfx canister call funnai_treasury_canister whoami --network $NETWORK
dfx canister call funnai_treasury_canister amiController --network $NETWORK
dfx canister call funnai_treasury_canister getMasterCanisterId --network $NETWORK
dfx canister call funnai_treasury_canister getConvertIcpToFunnaiFlag --network $NETWORK
dfx canister call funnai_treasury_canister getBurnIncomingFunnaiFlag --network $NETWORK
dfx canister call funnai_treasury_canister getBurnShareFunnai --network $NETWORK
dfx canister call funnai_treasury_canister getDeveloperShareIcp --network $NETWORK
dfx canister call funnai_treasury_canister getDisburseCyclesToDevelopersFlag --network $NETWORK
dfx canister call funnai_treasury_canister getDisburseFundsToDevelopersFlag --network $NETWORK
dfx canister call funnai_treasury_canister getIcpBaseAmount --network $NETWORK
dfx canister call funnai_treasury_canister getLiquidityAdditionIncomingFunnaiFlag --network $NETWORK
dfx canister call funnai_treasury_canister getLiquidityShareFunnai --network $NETWORK
dfx canister call funnai_treasury_canister getMatchLiquidityAdditionIcpFlag --network $NETWORK
dfx canister call funnai_treasury_canister getMinimumIcpBalance --network $NETWORK

# Update values
dfx canister call funnai_treasury_canister setMinimumIcpBalance '0' --network $NETWORK
dfx canister call funnai_treasury_canister toggleConvertIcpToFunnaiFlagAdmin --network $NETWORK

## Might come in handy during local testing
dfx ledger fabricate-cycles --canister funnai_treasury_canister
```

# Account
dfx ledger account-id --of-principal qbhxa-ziaaa-aaaaa-qbqza-cai
84f6f707fbc9a70ed8b38ac0765fa715066d81da5097964363bad96240f247bf