```bash
# When deploying local, no need to append `--network $NETWORK`

dfx deploy api_canister --network $NETWORK

dfx canister call api_canister setMasterCanisterId '("...-cai")' --network $NETWORK

# Set api canister in Game State (funnAI folder):
dfx canister call game_state_canister setApiCanisterId '("...-cai")' --network $NETWORK

# Seed it with data
./seed_data.sh --network $NETWORK

# Get daily metrics with public queries:
dfx canister call api_canister getDailyMetrics 'null' --network $NETWORK  --output json
dfx canister call api_canister getDailyMetrics '(opt record {start_date=opt "2025-09-06"; end_date=opt "2025-09-08"; limit=null})' --network $NETWORK  --output json
dfx canister call api_canister getLatestDailyMetric --network $NETWORK  --output json
dfx canister call api_canister getDailyMetricByDate '("2025-09-08")' --network $NETWORK  --output json
dfx canister call api_canister getNumDailyMetrics --network $NETWORK  --output json

# CRUD daily metrics as Admin:
dfx canister call api_canister createDailyMetricAdmin '(record {date="2025-09-08"; funnai_index=0.32; daily_burn_rate_cycles=1365; daily_burn_rate_usd=1871.83; total_mainers_created=701; total_active_mainers=474; total_paused_mainers=227; total_cycles_all_mainers=8276; active_low_burn_rate_mainers=121; active_medium_burn_rate_mainers=84; active_high_burn_rate_mainers=269; active_very_high_burn_rate_mainers=0; paused_low_burn_rate_mainers=56; paused_medium_burn_rate_mainers=36; paused_high_burn_rate_mainers=135; paused_very_high_burn_rate_mainers=0})' --network $NETWORK

dfx canister call api_canister updateDailyMetricAdmin '(record {date="2025-09-08"; input=record {funnai_index=opt 0.35; daily_burn_rate_cycles=null; daily_burn_rate_usd=null; total_mainers_created=null; total_active_mainers=null; total_paused_mainers=null; total_cycles_all_mainers=null; active_low_burn_rate_mainers=null; active_medium_burn_rate_mainers=null; active_high_burn_rate_mainers=null; active_very_high_burn_rate_mainers=null; paused_low_burn_rate_mainers=null; paused_medium_burn_rate_mainers=null; paused_high_burn_rate_mainers=null; paused_very_high_burn_rate_mainers=null}})' --network $NETWORK

dfx canister call api_canister deleteDailyMetricAdmin '("2025-09-08")' --network $NETWORK

dfx canister call api_canister getDailyMetricsAdmin --network $NETWORK

dfx canister call api_canister bulkCreateDailyMetricsAdmin '(vec {record {date="2025-09-06"; funnai_index=0.25; daily_burn_rate_cycles=1204; daily_burn_rate_usd=1651.28; total_mainers_created=689; total_active_mainers=442; total_paused_mainers=247; total_cycles_all_mainers=7923; active_low_burn_rate_mainers=115; active_medium_burn_rate_mainers=79; active_high_burn_rate_mainers=248; active_very_high_burn_rate_mainers=0; paused_low_burn_rate_mainers=61; paused_medium_burn_rate_mainers=42; paused_high_burn_rate_mainers=144; paused_very_high_burn_rate_mainers=0}})' --network $NETWORK

# Test script:
test_local.sh


# prd:
mops install
dfx deploy api_canister --network prd --with-cycles 1000000000000 --subnet csyj4-zmann-ys6ge-3kzi6-onexi-obayx-2fvak-zersm-euci4-6pslt-lae
dfx canister --network prd update-settings bgm6p-5aaaa-aaaaf-qbzda-cai --add-controller ....
# -> Add canister id to CycleOps
# -> Add canister id to funnAI/scripts/canister_ids-prd.env
dfx canister call api_canister setMasterCanisterId '("r5m5y-diaaa-aaaaa-qanaa-cai")' --network prd
dfx canister call api_canister getMasterCanisterId --network prd
# Set api canister in Game State (funnAI folder):
dfx canister call game_state_canister setApiCanisterId '("bgm6p-5aaaa-aaaaf-qbzda-cai")' --network prd


# demo:
dfx deploy api_canister --network demo --with-cycles 1000000000000 --subnet nl6hn-ja4yw-wvmpy-3z2jx-ymc34-pisx3-3cp5z-3oj4a-qzzny-jbsv3-4qe
dfx canister --network prd update-settings p6pu7-5aaaa-aaaap-qqdfa-cai --add-controller ....
# -> Add canister id to funnAI/scripts/canister_ids-demo.env
dfx canister call api_canister setMasterCanisterId '("4tr6r-mqaaa-aaaae-qfcta-cai")' --network demo
dfx canister call api_canister getMasterCanisterId --network demo
# Set api canister in Game State (funnAI folder):
dfx canister call game_state_canister setApiCanisterId '("bgm6p-5aaaa-aaaaf-qbzda-cai")' --network demo
# Seed it with dummy data (optional)
./seed_data.sh --network demo

# testing:
dfx deploy api_canister --network testing --with-cycles 1000000000000 --subnet nl6hn-ja4yw-wvmpy-3z2jx-ymc34-pisx3-3cp5z-3oj4a-qzzny-jbsv3-4qe
dfx canister --network prd update-settings nyxgs-uqaaa-aaaap-qqdia-cai --add-controller ....
# -> Add canister id to funnAI/scripts/canister_ids-testing.env
dfx canister call api_canister setMasterCanisterId '("vpa37-giaaa-aaaam-qdxeq-cai")' --network testing
dfx canister call api_canister getMasterCanisterId --network testing
# Set api canister in Game State (funnAI folder):
dfx canister call game_state_canister setApiCanisterId '("nyxgs-uqaaa-aaaap-qqdia-cai")' --network testing
# Seed it with dummy data (optional)
./seed_data.sh --network testing
```