# Challenger Canister

# Build, Deploy and Verify

```bash
# Build wasm with Docker (reproducible build)
# The base image is shared across all canisters. Once built, it can be reused.
make docker-build-base
make docker-build-wasm

# Deploy the pre-built wasm
# Note: Post-SNS, this step is replaced with SNS governed deployment.
dfx canister --network $NETWORK stop challenger_ctrlb_canister
dfx canister --network $NETWORK snapshot create challenger_ctrlb_canister
dfx canister install --wasm out/challenger_ctrlb_canister.wasm \
    --network $NETWORK --mode upgrade --wasm-memory-persistence keep \
    challenger_ctrlb_canister
dfx canister --network $NETWORK start challenger_ctrlb_canister

# Verify the deployed wasm matches the Docker build
make docker-verify-wasm VERIFY_NETWORK=$NETWORK
```

# Available Makefile targets

```bash
make help
```

See also instructions in `PoAIW/README.md`
