# Archive Challenges Canister

# Build, Deploy and Verify

```bash
# Build wasm with Docker (reproducible build)
# The base image is shared across all canisters. Once built, it can be reused.
make docker-build-base
make docker-build-wasm

# Deploy the pre-built wasm
# Note: Post-SNS, this step is replaced with SNS governed deployment.
icp canister stop archive_challenges_canister -e $NETWORK
icp canister snapshot create archive_challenges_canister -e $NETWORK
icp canister install archive_challenges_canister --wasm out/archive_challenges_canister.wasm \
    -e $NETWORK --mode upgrade --wasm-memory-persistence keep -y
icp canister start archive_challenges_canister -e $NETWORK

# Verify the deployed wasm matches the Docker build
make docker-verify-wasm VERIFY_NETWORK=$NETWORK
```

# Available Makefile targets

```bash
make help
```

# Background

During upgrade on Jan 14, 2026 the archive_challenges_canister could no longer be upgraded
due to the list data being to large for serialization.

We decided to deploy a new canister using the enhanced orthogonal persistence (EOP), and
keep the old one running as is.

- archive_challenges_canister = new canister
- archive_challenges_canister_orig = the orginal canister that can not be upgraded anymore

The protocol was configured to archive to the new canister.
We hope to be able to extract the data from the original archive canister in the future.

# Useful commands

```bash

### e.g. demo:
icp canister call archive_challenges_canister setMasterCanisterId '("4tr6r-mqaaa-aaaae-qfcta-cai")' -e $NETWORK

### Set archive canister in Game State (funnAI folder), e.g. demo:
icp canister call game_state_canister setArchiveCanisterId '("ga256-riaaa-aaaap-qp4fa-cai")' -e $NETWORK

### Get archived challenges:
icp canister call archive_challenges_canister getChallenges -e $NETWORK
icp canister call archive_challenges_canister getNumChallenges -e $NETWORK

### Get backed up mAIners:
icp canister call archive_challenges_canister getMainersAdmin -e $NETWORK
icp canister call archive_challenges_canister getNumMainersAdmin -e $NETWORK

### Get archived submissions:
icp canister call archive_challenges_canister getNumSubmissionsAdmin -e $NETWORK
icp canister call archive_challenges_canister getSubmissionsAdmin -e $NETWORK

### Get archived winner declarations:
icp canister call archive_challenges_canister getWinnerDeclarationsAdmin -e $NETWORK
icp canister call archive_challenges_canister getNumWinnerDeclarationsAdmin -e $NETWORK

### Get archived scored responses:
icp canister call archive_challenges_canister getScoredResponsesAdmin -e $NETWORK
icp canister call archive_challenges_canister getNumScoredResponsesAdmin -e $NETWORK

### prd:
icp deploy archive_challenges_canister -e prd --cycles 5000000000000 --subnet csyj4-zmann-ys6ge-3kzi6-onexi-obayx-2fvak-zersm-euci4-6pslt-lae

icp canister call archive_challenges_canister setMasterCanisterId '("r5m5y-diaaa-aaaaa-qanaa-cai")' -e prd

icp canister call archive_challenges_canister getMasterCanisterId -e prd

### Set archive canister in Game State (funnAI folder):
icp canister call game_state_canister setArchiveCanisterId '("yiobo-hyaaa-aaaaf-qdjnq-cai")' -e prd
```
