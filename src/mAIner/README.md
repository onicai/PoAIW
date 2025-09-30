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
# in this folder (mAIner), make sure you got the correct mAIner code
# temporarily add mAIner's id to canister_ids.json, e.g. "mainer_ctrlb_canister_2": {     "ic": "ywrcf-liaaa-aaaaa-qbcfq-cai"  },
dfx deploy mainer_ctrlb_canister_2 --network ic --mode upgrade
dfx canister call mainer_ctrlb_canister_2 --network ic startTimerExecutionAdmin
```