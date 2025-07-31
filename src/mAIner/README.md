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