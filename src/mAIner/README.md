# Build, Deploy and Verify

```bash
# Build wasm with Docker (reproducible build)
# The base image is shared across all canisters. Once built, it can be reused.
make docker-build-base
make docker-build-wasm

# Deploy the pre-built wasm for ShareService
# See also `smoketest` target in Makefile
# Note: Post-SNS, this step is replaced with SNS governed deployment.
icp canister stop mainer_service_canister -e $NETWORK
icp canister snapshot create mainer_service_canister -e $NETWORK
icp canister install mainer_service_canister --wasm out/mainer_service_canister.wasm \
    -e $NETWORK --mode upgrade --wasm-memory-persistence keep -y
icp canister start mainer_service_canister -e $NETWORK

# Verify the deployed wasm matches the Docker build
make docker-verify-wasm VERIFY_NETWORK=$NETWORK
```

# Deploy the pre-built wasm for mainer_ctrlb_canister_0, for testing
# See also `smoketest` target in Makefile
icp canister stop mainer_ctrlb_canister_0 -e $NETWORK
icp canister snapshot create mainer_ctrlb_canister_0 -e $NETWORK
icp canister install mainer_ctrlb_canister_0 --wasm out/mainer_service_canister.wasm \
    -e $NETWORK --mode upgrade --wasm-memory-persistence keep -y
icp canister start mainer_ctrlb_canister_0 -e $NETWORK
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
icp canister call game_state_canister getSubnetsAdmin

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
icp canister call game_state_canister setSubnetsAdmin "(record {subnetShareAgentCtrl = \"$SUBNETSACTRL\"; subnetShareServiceCtrl = \"$SUBNETSSCTRL\"; subnetShareServiceLlm = \"$SUBNETSSLLM\" })"

# Deploy a new ShareAgent via Admin command
scripts/scripts-gamestate/deploy-mainers-ShareAgent-via-gamestate.sh --mode install -e $NETWORK

# Update gamestate to the latest wasmhash. <canisterId> is the address of one of the upgraded ShareAgent canisters
icp canister call game_state_canister deriveNewMainerAgentCanisterWasmHashAdmin '(record {address="<canisterId>"; textNote="New wasm deployed"})' -e $NETWORK
```

# Investigate mAIner issues
```bash
icp canister status ywrcf-liaaa-aaaaa-qbcfq-cai -e ic
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic health
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic amiController
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic ready
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic getMainerCanisterType
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic getCurrentAgentTimersAdmin
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic getAgentTimersAdmin
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic getCurrentAgentSettingsAdmin
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic getAgentSettingsAdmin
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic canAgentSettingsBeUpdated
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic checkAccessToLLMs
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic getChallengeQueueAdmin
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic getGameStateCanisterId
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic getIssueFlagsAdmin
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic getLLMCanisterIds
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic getMainerStatisticsAdmin
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic getRecentSubmittedResponsesAdmin
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic getShareServiceCanisterId
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic getTimerActionRegularityInSecondsAdmin
icp canister call ywrcf-liaaa-aaaaa-qbcfq-cai -e ic timeToNextAgentSettingsUpdate
```

## Reset a mAIner
```bash
NETWORK=prd
USER_ID=...
# Get the correct mAIner canister id, by running from funnAI folder:
scripts/get_mainers.sh -e $NETWORK --user $USER_ID

# Verify that the canister id is in the canister_ids.json in this folder.
# If it is not, do not edit it yourself, but run from funnAI folder:
scripts/get_mainers.sh -e $NETWORK

# Then, upgrade the mAIner from this folder (mAIner):
# Get the mainer_ctrlb_canister_## from the canister_ids.json and run:
MAINER=mainer_ctrlb_canister_##

# verify logs and make sure it is Ok to upgrade (nothing in the queue)
icp canister logs $MAINER -e $NETWORK --follow
icp canister call $MAINER getChallengeQueueAdmin --output json

# toggle maintenance flag
icp canister call $MAINER getMaintenanceFlag
icp canister call $MAINER toggleMaintenanceFlagAdmin # if needed

# stop & snapshot & start
icp canister stop $MAINER -e $NETWORK
icp canister snapshot create $MAINER -e $NETWORK
icp canister start $MAINER -e $NETWORK

# Upgrade & start Timer & toggle maintenance flag
# IMPORTANT: make sure the correct branch is checked out !!!!!!!!!!!!!!
icp deploy   -e $NETWORK $MAINER --mode upgrade
icp canister call $MAINER startTimerExecutionAdmin
icp canister call $MAINER getMaintenanceFlag
icp canister call $MAINER toggleMaintenanceFlagAdmin # if needed

# verify everything looks good (timer should have been restarted)
icp canister logs $MAINER -e $NETWORK

# if it does not look good, restore the snapshot
icp canister snapshot list $MAINER -e $NETWORK
icp canister stop $MAINER -e $NETWORK
icp canister snapshot restore $MAINER -e $NETWORK <snapshot-id>
icp canister start $MAINER -e $NETWORK
icp canister call $MAINER startTimerExecutionAdmin
icp canister call $MAINER getMaintenanceFlag
icp canister call $MAINER toggleMaintenanceFlagAdmin # if needed

# if it looks good, delete the snapshot
icp canister snapshot list $MAINER -e $NETWORK
icp canister snapshot delete $MAINER -e $NETWORK <snapshot-id>
```