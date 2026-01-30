# Treasury Canister

# Build, Deploy and Verify

```bash
# Build wasm with Docker (reproducible build)
# The base image is shared across all canisters. Once built, it can be reused.
make docker-build-base
make docker-build-wasm

# Deploy the pre-built wasm
# Note: Post-SNS, this step is replaced with SNS governed deployment.
dfx canister --network $NETWORK stop funnai_treasury_canister
dfx canister --network $NETWORK snapshot create funnai_treasury_canister
dfx canister install --wasm out/funnai_treasury_canister.wasm \
    --network $NETWORK --mode upgrade --wasm-memory-persistence keep \
    funnai_treasury_canister
dfx canister --network $NETWORK start funnai_treasury_canister

# Verify the deployed wasm matches the Docker build
make docker-verify-wasm VERIFY_NETWORK=$NETWORK
```

# Available Makefile targets

```bash
make help
```

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

# IC mainnet (caution! there is only 1 treasury canister for the stages)
## development: do not call this anymore after treasury is in production (there is only 1 treasury, or create another treasury for this stage)
dfx canister call --network development funnai_treasury_canister setMasterCanisterId '("ciqqv-4iaaa-aaaag-auara-cai")'

## demo: do not call this anymore after treasury is in production (there is only 1 treasury, or create another treasury for this stage)
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
dfx canister call funnai_treasury_canister toggleBurnIncomingFunnaiFlagAdmin --network $NETWORK
dfx canister call funnai_treasury_canister toggleLiquidityAdditionIncomingFunnaiFlagAdmin --network $NETWORK
dfx canister call funnai_treasury_canister toggleMatchLiquidityAdditionIcpFlagAdmin --network $NETWORK
dfx canister call funnai_treasury_canister setLiquidityShareFunnai '100' --network $NETWORK

# Send rewards for LP farm/staking pool on ICPSwap
dfx canister call funnai_treasury_canister getAmountFunnaiToSend --network $NETWORK
dfx canister call funnai_treasury_canister setAmountFunnaiToSend '1' --network $NETWORK
dfx canister call funnai_treasury_canister getSendOutFunnaiFlag --network $NETWORK
dfx canister call funnai_treasury_canister toggleSendOutFunnaiFlagAdmin --network $NETWORK
## careful, this will actually send the FUNNAI tokens to ICPSwap
dfx canister call funnai_treasury_canister sendFunnaiForPoolSetupAdmin --network $NETWORK

## Might come in handy during local testing
dfx ledger fabricate-cycles --canister funnai_treasury_canister
```

# Account
dfx ledger account-id --of-principal qbhxa-ziaaa-aaaaa-qbqza-cai
84f6f707fbc9a70ed8b38ac0765fa715066d81da5097964363bad96240f247bf

e.g. check here: https://dashboard.internetcomputer.org/account/84f6f707fbc9a70ed8b38ac0765fa715066d81da5097964363bad96240f247bf

### FUNNAI balance:
https://637g5-siaaa-aaaaj-aasja-cai.raw.ic0.app/address/vpyot-zqaaa-aaaaa-qavaq-cai/qbhxa-ziaaa-aaaaa-qbqza-cai

or icrc1_balance_of for qbhxa-ziaaa-aaaaa-qbqza-cai on https://dashboard.internetcomputer.org/canister/vpyot-zqaaa-aaaaa-qavaq-cai

### Prd Game State
https://dashboard.internetcomputer.org/account/300d6f0058417bb5131c7313a3fe7f7b90510ca2f413ab863d39b1e35eceebad?s=100

# Test
## Demo
- Upgrade demo Game State
- Set treasury on Game State
```bash
dfx canister call game_state_canister setTreasuryCanisterId '"pm62h-jyaaa-aaaag-aughq-cai"' --network demo
dfx canister call game_state_canister getTreasuryCanisterId --network demo
```

- Toggle disburse flag on Game State
```bash
dfx canister call game_state_canister toggleDisburseFundsToTreasuryFlagAdmin --network demo
dfx canister call game_state_canister getDisburseFundsToTreasuryFlag --network demo
```

- Set Game State as master on Treasury
- Check low balance threshold for Treasury (commands above)
- Check flags for Treasury (commands above)
- Track account balances (ICP)
  - Demo Game State: https://dashboard.internetcomputer.org/account/7d2ab30a87147cd1e34141ae5a311ff808b33471a689d3d2953d386a73494b3b

  - Treasury: https://dashboard.internetcomputer.org/account/84f6f707fbc9a70ed8b38ac0765fa715066d81da5097964363bad96240f247bf

- Run test commands
```bash
dfx canister call game_state_canister testDisbursementToTreasuryAdmin --network demo
dfx canister logs game_state_canister --network demo
dfx canister logs funnai_treasury_canister --network demo
```

- Test normal topup flow (on demo app)
- Test disburseIcpToTreasuryAdmin on Game State
- Test random extra ICP (kicks in once balance on Treasury is big enough)
- Test many concurrent requests (e.g. trigger as admin, and from app)

