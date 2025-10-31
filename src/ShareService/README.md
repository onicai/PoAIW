# ShareService
This canister serves as a Generative AI service to mAIners and thus has multiple LLM canisters attached. 

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