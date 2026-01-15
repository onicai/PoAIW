During upgrade on Jan 14, 2026 the archive_challenges_canister could no longer be upgraded
due to the list data being to large for serialization.

We decided to deploy a new canister using the enhanced orthogonal persistence (EOP), and 
keep the old one running as is.

- archive_challenges_canister = new canister
- archive_challenges_canister_orig = the orginal canister that can not be upgraded anymore

The protocol was configured to archive to the new canister.
We hope to be able to extract the data from the original archive canister in the future.

```bash
dfx deploy archive_challenges_canister --network $NETWORK

### e.g. demo:
dfx canister call archive_challenges_canister setMasterCanisterId '("4tr6r-mqaaa-aaaae-qfcta-cai")' --network $NETWORK

### Set archive canister in Game State (funnAI folder), e.g. demo:
dfx canister call game_state_canister setArchiveCanisterId '("ga256-riaaa-aaaap-qp4fa-cai")' --network $NETWORK

### Get archived challenges:
dfx canister call archive_challenges_canister getChallenges --network $NETWORK
dfx canister call archive_challenges_canister getNumChallenges --network $NETWORK

### Get backed up mAIners:
dfx canister call archive_challenges_canister getMainersAdmin --network $NETWORK
dfx canister call archive_challenges_canister getNumMainersAdmin --network $NETWORK

### Get archived submissions:
dfx canister call archive_challenges_canister getNumSubmissionsAdmin --network $NETWORK
dfx canister call archive_challenges_canister getSubmissionsAdmin --network $NETWORK

### Get archived winner declarations:
dfx canister call archive_challenges_canister getWinnerDeclarationsAdmin --network $NETWORK
dfx canister call archive_challenges_canister getNumWinnerDeclarationsAdmin --network $NETWORK

### Get archived scored responses:
dfx canister call archive_challenges_canister getScoredResponsesAdmin --network $NETWORK
dfx canister call archive_challenges_canister getNumScoredResponsesAdmin --network $NETWORK

### prd:
dfx deploy archive_challenges_canister --network prd --with-cycles 5000000000000 --subnet csyj4-zmann-ys6ge-3kzi6-onexi-obayx-2fvak-zersm-euci4-6pslt-lae

dfx canister call archive_challenges_canister setMasterCanisterId '("r5m5y-diaaa-aaaaa-qanaa-cai")' --network prd

dfx canister call archive_challenges_canister getMasterCanisterId --network prd

### Set archive canister in Game State (funnAI folder):
dfx canister call game_state_canister setArchiveCanisterId '("yiobo-hyaaa-aaaaf-qdjnq-cai")' --network prd
```
