#!/bin/bash

# Seed the API canister with example data for the past 30 days
# Usage: ./seed_data.sh --network [prd|demo|testing|local]

# Parse command line arguments
NETWORK="local"
if [[ "$1" == "--network" ]]; then
    if [[ -n "$2" ]]; then
        NETWORK="$2"
    else
        echo "Error: --network requires a value (prd|demo|testing|local)"
        exit 1
    fi
elif [[ -n "$1" ]]; then
    echo "Usage: ./seed_data.sh --network [prd|demo|testing|local]"
    exit 1
fi

echo "Seeding API canister with 30 days of data on network: $NETWORK"

# Base values for generating realistic data
BASE_FUNNAI_INDEX=0.30
BASE_BURN_RATE_CYCLES=1300
BASE_BURN_RATE_USD=1780.00
BASE_MAINERS=690
BASE_ACTIVE_RATIO=0.66
BASE_CYCLES=8000

# Function to generate data for a specific date
generate_daily_metric() {
    local date=$1
    local day_offset=$2
    
    # Add some variance to make data realistic
    local variance=$(echo "scale=2; $day_offset * 0.01" | bc)
    local daily_variance=$(echo "scale=2; (($day_offset % 7) - 3) * 0.005" | bc)
    
    local funnai_index=$(echo "scale=2; $BASE_FUNNAI_INDEX + $variance + $daily_variance" | bc)
    local burn_cycles=$(echo "$BASE_BURN_RATE_CYCLES + ($day_offset * 5) + (($day_offset % 5) * 10)" | bc | cut -d. -f1)
    local burn_usd=$(echo "scale=2; $BASE_BURN_RATE_USD + ($day_offset * 7.5) + (($day_offset % 5) * 15)" | bc)
    
    local total_mainers=$(echo "$BASE_MAINERS + ($day_offset * 2)" | bc | cut -d. -f1)
    local active_mainers=$(echo "$total_mainers * $BASE_ACTIVE_RATIO / 1" | bc | cut -d. -f1)
    local paused_mainers=$(echo "$total_mainers - $active_mainers" | bc | cut -d. -f1)
    local total_cycles=$(echo "$BASE_CYCLES + ($day_offset * 50)" | bc | cut -d. -f1)
    
    # Distribute mainers across tiers (roughly: low=25%, medium=18%, high=57%, very_high=0%)
    local active_low=$(echo "$active_mainers * 25 / 100" | bc | cut -d. -f1)
    local active_medium=$(echo "$active_mainers * 18 / 100" | bc | cut -d. -f1)
    local active_high=$(echo "$active_mainers - $active_low - $active_medium" | bc | cut -d. -f1)
    local active_very_high=0
    
    local paused_low=$(echo "$paused_mainers * 24 / 100" | bc | cut -d. -f1)
    local paused_medium=$(echo "$paused_mainers * 17 / 100" | bc | cut -d. -f1)
    local paused_high=$(echo "$paused_mainers - $paused_low - $paused_medium" | bc | cut -d. -f1)
    local paused_very_high=0
    
    echo "record {
        date=\"$date\";
        funnai_index=$funnai_index;
        daily_burn_rate_cycles=$burn_cycles;
        daily_burn_rate_usd=$burn_usd;
        total_mainers_created=$total_mainers;
        total_active_mainers=$active_mainers;
        total_paused_mainers=$paused_mainers;
        total_cycles_all_mainers=$total_cycles;
        active_low_burn_rate_mainers=$active_low;
        active_medium_burn_rate_mainers=$active_medium;
        active_high_burn_rate_mainers=$active_high;
        active_very_high_burn_rate_mainers=$active_very_high;
        paused_low_burn_rate_mainers=$paused_low;
        paused_medium_burn_rate_mainers=$paused_medium;
        paused_high_burn_rate_mainers=$paused_high;
        paused_very_high_burn_rate_mainers=$paused_very_high
    }"
}

# Generate dates for the past 30 days
DATES=()
METRICS=()
for i in {29..0}; do
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        DATE=$(date -v-${i}d +%Y-%m-%d)
    else
        # Linux
        DATE=$(date -d "$i days ago" +%Y-%m-%d)
    fi
    DATES+=($DATE)
    METRIC=$(generate_daily_metric $DATE $((30-i)))
    METRICS+=("$METRIC")
done

# Build the vec of records for bulk create
BULK_DATA="vec {"
for i in "${!METRICS[@]}"; do
    BULK_DATA+="${METRICS[$i]}"
    if [ $i -lt $((${#METRICS[@]} - 1)) ]; then
        BULK_DATA+="; "
    fi
done
BULK_DATA+="}"

echo ""
echo "Creating ${#DATES[@]} daily metrics from ${DATES[0]} to ${DATES[$((${#DATES[@]}-1))]}..."
echo ""

# Execute the bulk create command
if [ "$NETWORK" = "local" ]; then
    dfx canister call api_canister bulkCreateDailyMetricsAdmin "($BULK_DATA)" 2>&1 | tee /Users/arjaan/github/repos/funnAI/secret/.current_claude_command.txt
else
    dfx canister call api_canister bulkCreateDailyMetricsAdmin "($BULK_DATA)" --network $NETWORK 2>&1 | tee /Users/arjaan/github/repos/funnAI/secret/.current_claude_command.txt
fi

echo ""
echo "Verifying data was created..."
if [ "$NETWORK" = "local" ]; then
    dfx canister call api_canister getNumDailyMetrics
else
    dfx canister call api_canister getNumDailyMetrics --network $NETWORK
fi

echo ""
echo "Getting latest metric (first 50 lines)..."
if [ "$NETWORK" = "local" ]; then
    dfx canister call api_canister getLatestDailyMetric 2>&1 | head -50 || true
else
    dfx canister call api_canister getLatestDailyMetric --network $NETWORK 2>&1 | head -50 || true
fi

echo ""
echo "Seeding complete!"