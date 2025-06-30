dfx deploy archive_challenges_canister --network $NETWORK

e.g. demo:
dfx canister call archive_challenges_canister setMasterCanisterId '("4tr6r-mqaaa-aaaae-qfcta-cai")' --network $NETWORK

Set archive canister in Game State (funnAI folder), e.g. demo:
dfx canister call game_state_canister setArchiveCanisterId '("ga256-riaaa-aaaap-qp4fa-cai")' --network $NETWORK

Get archived challenges:
dfx canister call archive_challenges_canister getChallenges --network $NETWORK
dfx canister call archive_challenges_canister getNumChallenges --network $NETWORK

Get backed up mAIners:
dfx canister call archive_challenges_canister getMainersAdmin --network $NETWORK
dfx canister call archive_challenges_canister getNumMainersAdmin --network $NETWORK

prd:
dfx deploy archive_challenges_canister --network prd --with-cycles 1000000000000 --subnet csyj4-zmann-ys6ge-3kzi6-onexi-obayx-2fvak-zersm-euci4-6pslt-lae

dfx canister call archive_challenges_canister setMasterCanisterId '("r5m5y-diaaa-aaaaa-qanaa-cai")' --network prd

dfx canister call archive_challenges_canister getMasterCanisterId --network prd

Set archive canister in Game State (funnAI folder):
dfx canister call game_state_canister setArchiveCanisterId '("474n2-qiaaa-aaaaf-qasoq-cai")' --network prd
