See instructions in `PoAIW/README.md`

# Investigate mAIner issues
```bash
dfx canister status ywrcf-liaaa-aaaaa-qbcfq-cai --network ic
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic health
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic amiController
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic ready
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic getMainerCanisterType
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic canAgentSettingsBeUpdated
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic checkAccessToLLMs
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic getChallengeQueueAdmin
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic getGameStateCanisterId
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic getIssueFlagsAdmin
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic getLLMCanisterIds
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic getMainerStatisticsAdmin
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic getRecentSubmittedResponsesAdmin
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic getShareServiceCanisterId
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic getTimerActionRegularityInSecondsAdmin
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic timeToNextAgentSettingsUpdate
```

## Reset a mAIner
```bash
# Get the correct mAIner canister id, by running from funnAI folder:
scripts/get_mainers.sh --network prd --user $PRINCIPAL_ID

# Verify that the canister id is in the canister_ids.json in this folder.
# If it is not, do not edit it yourself, but run from funnAI folder:
scripts/get_mainers.sh --network prd

# Then, upgrade the mAIner from this folder (mAIner):
# Get the mainer_ctrlb_canister_## from the canister_ids.json and run:
dfx deploy mainer_ctrlb_canister_## --network prd --mode upgrade
dfx canister call mainer_ctrlb_canister_## --network prd startTimerExecutionAdmin
```