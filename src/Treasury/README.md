# Treasury Canister

# Build, Deploy and Verify

```bash
# Build wasm with Docker (reproducible build)
# The base image is shared across all canisters. Once built, it can be reused.
make docker-build-base
make docker-build-wasm

# Deploy the pre-built wasm
# Note: Post-SNS, this step is replaced with SNS governed deployment.
icp canister stop funnai_treasury_canister -e $NETWORK
icp canister snapshot create funnai_treasury_canister -e $NETWORK
icp canister install funnai_treasury_canister --wasm out/funnai_treasury_canister.wasm \
    -e $NETWORK --mode upgrade --wasm-memory-persistence keep -y
icp canister start funnai_treasury_canister -e $NETWORK

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
# (no `icp` equivalent to `dfx generate` -- src/declarations/ is committed)

# local
icp deploy funnai_treasury_canister

# IC mainnet (caution!)
## development
icp deploy -e development funnai_treasury_canister

## production
icp deploy -e prd funnai_treasury_canister

# Set Game State as master canister (you have to deploy that canister first and then return with its id)
# local
icp canister call funnai_treasury_canister setMasterCanisterId '("c5kvi-uuaaa-aaaaa-qaaia-cai")'

# IC mainnet (caution! there is only 1 treasury canister for the stages)
## development: do not call this anymore after treasury is in production (there is only 1 treasury, or create another treasury for this stage)
icp canister call -e development funnai_treasury_canister setMasterCanisterId '("ciqqv-4iaaa-aaaag-auara-cai")'

## demo: do not call this anymore after treasury is in production (there is only 1 treasury, or create another treasury for this stage)
icp canister call -e demo funnai_treasury_canister setMasterCanisterId '("4tr6r-mqaaa-aaaae-qfcta-cai")'

## production
icp canister call -e prd funnai_treasury_canister setMasterCanisterId '("r5m5y-diaaa-aaaaa-qanaa-cai")'

```

```bash
icp canister call funnai_treasury_canister health -e $NETWORK
icp canister call funnai_treasury_canister whoami -e $NETWORK
icp canister call funnai_treasury_canister amiController -e $NETWORK
icp canister call funnai_treasury_canister getMasterCanisterId -e $NETWORK
icp canister call funnai_treasury_canister getConvertIcpToFunnaiFlag -e $NETWORK
icp canister call funnai_treasury_canister getBurnIncomingFunnaiFlag -e $NETWORK
icp canister call funnai_treasury_canister getBurnShareFunnai -e $NETWORK
icp canister call funnai_treasury_canister getDeveloperShareIcp -e $NETWORK
icp canister call funnai_treasury_canister getDisburseCyclesToDevelopersFlag -e $NETWORK
icp canister call funnai_treasury_canister getDisburseFundsToDevelopersFlag -e $NETWORK
icp canister call funnai_treasury_canister getIcpBaseAmount -e $NETWORK
icp canister call funnai_treasury_canister getLiquidityAdditionIncomingFunnaiFlag -e $NETWORK
icp canister call funnai_treasury_canister getLiquidityShareFunnai -e $NETWORK
icp canister call funnai_treasury_canister getMatchLiquidityAdditionIcpFlag -e $NETWORK
icp canister call funnai_treasury_canister getMinimumIcpBalance -e $NETWORK

# Update values
icp canister call funnai_treasury_canister setMinimumIcpBalance '0' -e $NETWORK
icp canister call funnai_treasury_canister toggleConvertIcpToFunnaiFlagAdmin -e $NETWORK
icp canister call funnai_treasury_canister toggleBurnIncomingFunnaiFlagAdmin -e $NETWORK
icp canister call funnai_treasury_canister toggleLiquidityAdditionIncomingFunnaiFlagAdmin -e $NETWORK
icp canister call funnai_treasury_canister toggleMatchLiquidityAdditionIcpFlagAdmin -e $NETWORK
icp canister call funnai_treasury_canister setLiquidityShareFunnai '100' -e $NETWORK

# Send rewards for LP farm/staking pool on ICPSwap
icp canister call funnai_treasury_canister getAmountFunnaiToSend -e $NETWORK
icp canister call funnai_treasury_canister setAmountFunnaiToSend '1' -e $NETWORK
icp canister call funnai_treasury_canister getSendOutFunnaiFlag -e $NETWORK
icp canister call funnai_treasury_canister toggleSendOutFunnaiFlagAdmin -e $NETWORK
## careful, this will actually send the FUNNAI tokens to ICPSwap
icp canister call funnai_treasury_canister sendFunnaiForPoolSetupAdmin -e $NETWORK

## Might come in handy during local testing
icp cycles transfer 20t funnai_treasury_canister -e local
```

# Account
icp identity account-id --of-principal qbhxa-ziaaa-aaaaa-qbqza-cai
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
icp canister call game_state_canister setTreasuryCanisterId '"pm62h-jyaaa-aaaag-aughq-cai"' -e demo
icp canister call game_state_canister getTreasuryCanisterId -e demo
```

- Toggle disburse flag on Game State
```bash
icp canister call game_state_canister toggleDisburseFundsToTreasuryFlagAdmin -e demo
icp canister call game_state_canister getDisburseFundsToTreasuryFlag -e demo
```

- Set Game State as master on Treasury
- Check low balance threshold for Treasury (commands above)
- Check flags for Treasury (commands above)
- Track account balances (ICP)
  - Demo Game State: https://dashboard.internetcomputer.org/account/7d2ab30a87147cd1e34141ae5a311ff808b33471a689d3d2953d386a73494b3b

  - Treasury: https://dashboard.internetcomputer.org/account/84f6f707fbc9a70ed8b38ac0765fa715066d81da5097964363bad96240f247bf

- Run test commands
```bash
icp canister call game_state_canister testDisbursementToTreasuryAdmin -e demo
icp canister logs game_state_canister -e demo
icp canister logs funnai_treasury_canister -e demo
```

- Test normal topup flow (on demo app)
- Test disburseIcpToTreasuryAdmin on Game State
- Test random extra ICP (kicks in once balance on Treasury is big enough)
- Test many concurrent requests (e.g. trigger as admin, and from app)

