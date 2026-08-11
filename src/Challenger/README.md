# Challenger Canister

# Build, Deploy and Verify

```bash
# Build wasm with Docker (reproducible build)
# The base image is shared across all canisters. Once built, it can be reused.
make docker-build-base
make docker-build-wasm

# Deploy the pre-built wasm
# Note: Post-SNS, this step is replaced with SNS governed deployment.
icp canister stop challenger_ctrlb_canister -e $NETWORK
icp canister snapshot create challenger_ctrlb_canister -e $NETWORK
icp canister install challenger_ctrlb_canister --wasm out/challenger_ctrlb_canister.wasm \
    -e $NETWORK --mode upgrade --wasm-memory-persistence keep -y
icp canister start challenger_ctrlb_canister -e $NETWORK

# Verify the deployed wasm matches the Docker build
make docker-verify-wasm VERIFY_NETWORK=$NETWORK
```

# Available Makefile targets

```bash
make help
```

See also instructions in `PoAIW/README.md`
