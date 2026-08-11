# Build, Deploy and Verify

```bash
# Build wasm with Docker (reproducible build)
# The base image is shared across all canisters. Once built, it can be reused.
make docker-build-base
make docker-build-wasm

# Deploy the pre-built wasm
# Note: Post-SNS, this step is replaced with SNS governed deployment.
icp canister stop api_canister -e $NETWORK
icp canister snapshot create api_canister -e $NETWORK
icp canister install api_canister --wasm out/api_canister.wasm \
    -e $NETWORK --mode upgrade --wasm-memory-persistence keep -y
icp canister start api_canister -e $NETWORK

# Verify the deployed wasm matches the Docker build
make docker-verify-wasm VERIFY_NETWORK=$NETWORK
```

# Available Makefile targets

```bash
make help
```

# API Usage

```bash
# When deploying local, no need to append `-e $NETWORK`

icp canister call api_canister setMasterCanisterId '("...-cai")' -e $NETWORK

# Set api canister in Game State (funnAI folder):
icp canister call game_state_canister setApiCanisterId '("...-cai")' -e $NETWORK

# Get token rewards data:
icp canister call api_canister getTokenRewardsData -e $NETWORK  --output json

# Get daily metrics with public queries:
icp canister call api_canister getDailyMetrics 'null' -e $NETWORK  --output json
icp canister call api_canister getDailyMetrics '(opt record {start_date=opt "2025-09-06"; end_date=opt "2025-09-08"; limit=null})' -e $NETWORK  --output json
icp canister call api_canister getLatestDailyMetric -e $NETWORK  --output json
icp canister call api_canister getDailyMetricByDate '("2025-09-08")' -e $NETWORK  --output json
icp canister call api_canister getNumDailyMetrics -e $NETWORK  --output json

# CRUD daily metrics as Admin:

# Create without total_cycles (backward compatible):
icp canister call api_canister createDailyMetricAdmin '(record {date="2025-09-08"; funnai_index=0.32; daily_burn_rate_cycles=1365; daily_burn_rate_usd=1871.83; total_mainers_created=701; total_active_mainers=474; total_paused_mainers=227; total_cycles_all_mainers=8276; active_low_burn_rate_mainers=121; active_medium_burn_rate_mainers=84; active_high_burn_rate_mainers=269; active_very_high_burn_rate_mainers=0; active_custom_burn_rate_mainers=0; paused_low_burn_rate_mainers=56; paused_medium_burn_rate_mainers=36; paused_high_burn_rate_mainers=135; paused_very_high_burn_rate_mainers=0; paused_custom_burn_rate_mainers=0})' -e $NETWORK

# Create with total_cycles (new optional fields):
# - total_cycles_all: Total cycles across all canisters (mainers + protocol)
# - total_cycles_protocol: Cycles from protocol/non-mainer canisters
icp canister call api_canister createDailyMetricAdmin '(record {date="2025-09-08"; funnai_index=0.32; daily_burn_rate_cycles=1365; daily_burn_rate_usd=1871.83; total_mainers_created=701; total_active_mainers=474; total_paused_mainers=227; total_cycles_all_mainers=8276; active_low_burn_rate_mainers=121; active_medium_burn_rate_mainers=84; active_high_burn_rate_mainers=269; active_very_high_burn_rate_mainers=0; active_custom_burn_rate_mainers=0; paused_low_burn_rate_mainers=56; paused_medium_burn_rate_mainers=36; paused_high_burn_rate_mainers=135; paused_very_high_burn_rate_mainers=0; paused_custom_burn_rate_mainers=0; total_cycles_all=opt 18276; total_cycles_protocol=opt 10000})' -e $NETWORK

# Update without total_cycles (backward compatible):
icp canister call api_canister updateDailyMetricAdmin '(record {date="2025-09-08"; input=record {funnai_index=opt 0.35; daily_burn_rate_cycles=null; daily_burn_rate_usd=null; total_mainers_created=null; total_active_mainers=null; total_paused_mainers=null; total_cycles_all_mainers=null; active_low_burn_rate_mainers=null; active_medium_burn_rate_mainers=null; active_high_burn_rate_mainers=null; active_very_high_burn_rate_mainers=null; active_custom_burn_rate_mainers=null; paused_low_burn_rate_mainers=null; paused_medium_burn_rate_mainers=null; paused_high_burn_rate_mainers=null; paused_very_high_burn_rate_mainers=null; paused_custom_burn_rate_mainers=null}})' -e $NETWORK

# Update with total_cycles (add or modify total_cycles):
icp canister call api_canister updateDailyMetricAdmin '(record {date="2025-09-08"; input=record {funnai_index=null; daily_burn_rate_cycles=null; daily_burn_rate_usd=null; total_mainers_created=null; total_active_mainers=null; total_paused_mainers=null; total_cycles_all_mainers=null; active_low_burn_rate_mainers=null; active_medium_burn_rate_mainers=null; active_high_burn_rate_mainers=null; active_very_high_burn_rate_mainers=null; active_custom_burn_rate_mainers=null; paused_low_burn_rate_mainers=null; paused_medium_burn_rate_mainers=null; paused_high_burn_rate_mainers=null; paused_very_high_burn_rate_mainers=null; paused_custom_burn_rate_mainers=null; total_cycles_all=opt 20000; total_cycles_protocol=opt 11724}})' -e $NETWORK

icp canister call api_canister deleteDailyMetricAdmin '("2025-09-08")' -e $NETWORK

icp canister call api_canister getDailyMetricsAdmin -e $NETWORK

# Bulk create without total_cycles (backward compatible):
icp canister call api_canister bulkCreateDailyMetricsAdmin '(vec {record {date="2025-09-06"; funnai_index=0.25; daily_burn_rate_cycles=1204; daily_burn_rate_usd=1651.28; total_mainers_created=689; total_active_mainers=442; total_paused_mainers=247; total_cycles_all_mainers=7923; active_low_burn_rate_mainers=115; active_medium_burn_rate_mainers=79; active_high_burn_rate_mainers=248; active_very_high_burn_rate_mainers=0; active_custom_burn_rate_mainers=0; paused_low_burn_rate_mainers=61; paused_medium_burn_rate_mainers=42; paused_high_burn_rate_mainers=144; paused_very_high_burn_rate_mainers=0; paused_custom_burn_rate_mainers=0}})' -e $NETWORK

# Bulk create with total_cycles:
icp canister call api_canister bulkCreateDailyMetricsAdmin '(vec {record {date="2025-09-06"; funnai_index=0.25; daily_burn_rate_cycles=1204; daily_burn_rate_usd=1651.28; total_mainers_created=689; total_active_mainers=442; total_paused_mainers=247; total_cycles_all_mainers=7923; active_low_burn_rate_mainers=115; active_medium_burn_rate_mainers=79; active_high_burn_rate_mainers=248; active_very_high_burn_rate_mainers=0; active_custom_burn_rate_mainers=0; paused_low_burn_rate_mainers=61; paused_medium_burn_rate_mainers=42; paused_high_burn_rate_mainers=144; paused_very_high_burn_rate_mainers=0; paused_custom_burn_rate_mainers=0; total_cycles_all=opt 17923; total_cycles_protocol=opt 10000}})' -e $NETWORK

# Activity Feed - public queries (cached data from GameState):
icp canister call api_canister getActivityFeed '(record {})' -e $NETWORK --output json
icp canister call api_canister getActivityFeed '(record {winnersLimit=opt 10; winnersOffset=opt 0; challengesLimit=opt 5; challengesOffset=opt 0})' -e $NETWORK --output json
icp canister call api_canister getActivityFeed '(record {sinceTimestamp=opt 1700000000000000000})' -e $NETWORK --output json
icp canister call api_canister getOpenChallengesFromCache -e $NETWORK --output json
icp canister call api_canister getActivityFeedCacheStatus -e $NETWORK --output json

# Activity Feed - Admin endpoints (timer control):
icp canister call api_canister getActivityFeedSyncIntervalAdmin -e $NETWORK
icp canister call api_canister setActivityFeedSyncIntervalAdmin '(600)' -e $NETWORK
icp canister call api_canister startActivityFeedTimerAdmin -e $NETWORK
icp canister call api_canister stopActivityFeedTimerAdmin -e $NETWORK

# To starts fresh:
icp canister call api_canister resetDailyMetricsAdmin -e $NETWORK

# Test script:
test_local.sh


# prd:
# Initial Install
mops install
icp deploy api_canister -e prd --cycles 1000000000000 --subnet csyj4-zmann-ys6ge-3kzi6-onexi-obayx-2fvak-zersm-euci4-6pslt-lae
icp canister settings update bgm6p-5aaaa-aaaaf-qbzda-cai -e prd --add-controller ....
# -> Add canister id to CycleOps
# -> Add canister id to funnAI/scripts/canister_ids-prd.env
icp canister call api_canister setMasterCanisterId '("r5m5y-diaaa-aaaaa-qanaa-cai")' -e prd
icp canister call api_canister getMasterCanisterId -e prd
# Set api canister in Game State (funnAI folder):
icp canister call game_state_canister setApiCanisterId '("bgm6p-5aaaa-aaaaf-qbzda-cai")' -e prd
#
# Upgrade (see "Build, Deploy and Verify" section above)


# demo:
icp deploy api_canister -e demo --cycles 1000000000000 --subnet nl6hn-ja4yw-wvmpy-3z2jx-ymc34-pisx3-3cp5z-3oj4a-qzzny-jbsv3-4qe
icp canister settings update p6pu7-5aaaa-aaaap-qqdfa-cai -e prd --add-controller ....
# -> Add canister id to funnAI/scripts/canister_ids-demo.env
icp canister call api_canister setMasterCanisterId '("4tr6r-mqaaa-aaaae-qfcta-cai")' -e demo
icp canister call api_canister getMasterCanisterId -e demo
# Set api canister in Game State (funnAI folder):
icp canister call game_state_canister setApiCanisterId '("bgm6p-5aaaa-aaaaf-qbzda-cai")' -e demo

# testing:
icp deploy api_canister -e testing --cycles 1000000000000 --subnet nl6hn-ja4yw-wvmpy-3z2jx-ymc34-pisx3-3cp5z-3oj4a-qzzny-jbsv3-4qe
icp canister settings update nyxgs-uqaaa-aaaap-qqdia-cai -e prd --add-controller ....
# -> Add canister id to funnAI/scripts/canister_ids-testing.env
icp canister call api_canister setMasterCanisterId '("vpa37-giaaa-aaaam-qdxeq-cai")' -e testing
icp canister call api_canister getMasterCanisterId -e testing
# Set api canister in Game State (funnAI folder):
icp canister call game_state_canister setApiCanisterId '("nyxgs-uqaaa-aaaap-qqdia-cai")' -e testing
```