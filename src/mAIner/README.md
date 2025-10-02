# Deploy a new mAIner

New mAIners are deployed via the front-end, but for testing it can be done as follows:

```bash
# Make sure the mAInerCreator has the correct wasm you want to deploy.
# -> See README in the mAInerCreator folder.

# Then instruct the GameState canister to create a new mAIner.
# from folder: funnAI
# Verify that 'subnetShareAgentCtrl' is set correctly in GameState
dfx canister --network $NETWORK call game_state_canister getSubnetsAdmin

# If subnets are wrong, fix it, with:
# Set environment variables for the subnets.
# Option 1: source the file for the environment & verify things are set
source scripts/canister_ids-$NETWORK.env
SUBNETSACTRL=$SUBNET_0_1
SUBNETSSCTRL=$SUBNET_0_1
SUBNETSSLLM=$SUBNET_2_1
# Option 2: set them manually
SUBNETSACTRL=...
SUBNETSSCTRL=...
SUBNETSSLLM=...
# Set the SubnetIds in the GameState canister
dfx canister --network $NETWORK call game_state_canister setSubnetsAdmin "(record {subnetShareAgentCtrl = \"$SUBNETSACTRL\"; subnetShareServiceCtrl = \"$SUBNETSSCTRL\"; subnetShareServiceLlm = \"$SUBNETSSLLM\" })"

# Deploy a new ShareAgent via Admin command
scripts/scripts-gamestate/deploy-mainers-ShareAgent-via-gamestate.sh --mode install --network $NETWORK

# Update gamestate to the latest wasmhash. <canisterId> is the address of one of the upgraded ShareAgent canisters
dfx canister call game_state_canister deriveNewMainerAgentCanisterWasmHashAdmin '(record {address="<canisterId>"; textNote="New wasm deployed"})' --network $NETWORK
```

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
NETWORK=prd
USER_ID=...
# Get the correct mAIner canister id, by running from funnAI folder:
scripts/get_mainers.sh --network $NETWORK --user $USER_ID

# Verify that the canister id is in the canister_ids.json in this folder.
# If it is not, do not edit it yourself, but run from funnAI folder:
scripts/get_mainers.sh --network $NETWORK

# Then, upgrade the mAIner from this folder (mAIner):
# Get the mainer_ctrlb_canister_## from the canister_ids.json and run:
MAINER=mainer_ctrlb_canister_##

# verify logs and make sure it is Ok to upgrade (nothing in the queue)
dfx canister --network $NETWORK logs $MAINER --follow
dfx canister --network $NETWORK call $MAINER getChallengeQueueAdmin --output json

# stop & snapshot & start
dfx canister --network $NETWORK stop $MAINER
dfx canister --network $NETWORK snapshot create $MAINER
dfx canister --network $NETWORK start $MAINER

# Upgrade & start Timer
# IMPORTANT: make sure the correct branch is checked out !!!!!!!!!!!!!!
dfx deploy   --network $NETWORK $MAINER --mode upgrade
dfx canister --network $NETWORK call $MAINER startTimerExecutionAdmin

# verify everything looks good (timer should have been restarted)
dfx canister --network $NETWORK logs $MAINER

# if it does not look good, restore the snapshot
dfx canister --network $NETWORK snapshot list $MAINER
dfx canister --network $NETWORK snapshot load $MAINER <snapshot-id>
```