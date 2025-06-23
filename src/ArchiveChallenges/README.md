dfx deploy archive_challenges_canister --network $NETWORK

e.g. demo:
dfx canister call archive_challenges_canister setMasterCanisterId '("4tr6r-mqaaa-aaaae-qfcta-cai")' --network $NETWORK

Set archive canister in Game State (funnAI folder), e.g. demo:
dfx canister call game_state_canister setArchiveCanisterId '("ga256-riaaa-aaaap-qp4fa-cai")' --network $NETWORK

Get archived challenges:
dfx canister call archive_challenges_canister getChallenges --network $NETWORK