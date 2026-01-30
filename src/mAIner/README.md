# Build, Deploy and Verify

```bash
# Build wasm with Docker (reproducible build)
# The base image is shared across all canisters. Once built, it can be reused.
make docker-build-base
make docker-build-wasm

# Deploy the pre-built wasm
# Note: Post-SNS, this step is replaced with SNS governed deployment.
dfx canister --network $NETWORK stop mainer_service_canister
dfx canister --network $NETWORK snapshot create mainer_service_canister
dfx canister install --wasm out/mainer_service_canister.wasm \
    --network $NETWORK --mode upgrade --wasm-memory-persistence keep \
    mainer_service_canister
dfx canister --network $NETWORK start mainer_service_canister

# Verify the deployed wasm matches the Docker build
make docker-verify-wasm VERIFY_NETWORK=$NETWORK
```

# Available Makefile targets

```bash
make help
```

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
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic getCurrentAgentTimersAdmin
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic getAgentTimersAdmin
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic getCurrentAgentSettingsAdmin
dfx canister call ywrcf-liaaa-aaaaa-qbcfq-cai --network ic getAgentSettingsAdmin
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

# toggle maintenance flag
dfx canister --network $NETWORK call $MAINER getMaintenanceFlag
dfx canister --network $NETWORK call $MAINER toggleMaintenanceFlagAdmin # if needed

# stop & snapshot & start
dfx canister --network $NETWORK stop $MAINER
dfx canister --network $NETWORK snapshot create $MAINER
dfx canister --network $NETWORK start $MAINER

# Upgrade & start Timer & toggle maintenance flag
# IMPORTANT: make sure the correct branch is checked out !!!!!!!!!!!!!!
dfx deploy   --network $NETWORK $MAINER --mode upgrade
dfx canister --network $NETWORK call $MAINER startTimerExecutionAdmin
dfx canister --network $NETWORK call $MAINER getMaintenanceFlag
dfx canister --network $NETWORK call $MAINER toggleMaintenanceFlagAdmin # if needed

# verify everything looks good (timer should have been restarted)
dfx canister --network $NETWORK logs $MAINER

# if it does not look good, restore the snapshot
dfx canister --network $NETWORK snapshot list $MAINER
dfx canister --network $NETWORK stop $MAINER
dfx canister --network $NETWORK snapshot load $MAINER <snapshot-id>
dfx canister --network $NETWORK start $MAINER
dfx canister --network $NETWORK call $MAINER startTimerExecutionAdmin
dfx canister --network $NETWORK call $MAINER getMaintenanceFlag
dfx canister --network $NETWORK call $MAINER toggleMaintenanceFlagAdmin # if needed

# if it looks good, delete the snapshot
dfx canister --network $NETWORK snapshot list $MAINER
dfx canister --network $NETWORK snapshot delete $MAINER <snapshot-id>
```