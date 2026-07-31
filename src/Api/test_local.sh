#!/bin/bash

# Local testing script for API canister

echo "============================================"
echo "API Canister Local Testing Script"
echo "============================================"

# Deploy the canister
echo ""
echo "1. Deploying API canister..."
icp deploy api_canister -e local -y

# Get the canister ID
CANISTER_ID=$(icp canister status api_canister -e local --id-only)
echo "Canister deployed with ID: $CANISTER_ID"

# Test health endpoint
echo ""
echo "2. Testing health endpoint..."
icp canister call api_canister health '()' -e local

# Test whoami endpoint
echo ""
echo "3. Testing whoami endpoint..."
icp canister call api_canister whoami '()' -e local

# Test controller check
echo ""
echo "4. Testing controller check..."
icp canister call api_canister amiController '()' -e local

# Get initial metrics count
echo ""
echo "5. Getting initial metrics count..."
icp canister call api_canister getNumDailyMetrics '()' -e local

# Create a test daily metric
echo ""
echo "6. Creating test daily metric for 2025-09-08..."
icp canister call api_canister createDailyMetricAdmin '(record {
    date = "2025-09-08";
    funnai_index = 0.32;
    daily_burn_rate_cycles = 1365;
    daily_burn_rate_usd = 1871.83;
    total_mainers_created = 701;
    total_active_mainers = 474;
    total_paused_mainers = 227;
    total_cycles_all_mainers = 8276;
    active_low_burn_rate_mainers = 121;
    active_medium_burn_rate_mainers = 84;
    active_high_burn_rate_mainers = 269;
    active_very_high_burn_rate_mainers = 0;
    active_custom_burn_rate_mainers = 0;
    paused_low_burn_rate_mainers = 56;
    paused_medium_burn_rate_mainers = 36;
    paused_high_burn_rate_mainers = 135;
    paused_very_high_burn_rate_mainers = 0;
    paused_custom_burn_rate_mainers = 0;
})' -e local

# Create another test metric
echo ""
echo "7. Creating test daily metric for 2025-09-07..."
icp canister call api_canister createDailyMetricAdmin '(record {
    date = "2025-09-07";
    funnai_index = 0.28;
    daily_burn_rate_cycles = 1289;
    daily_burn_rate_usd = 1767.45;
    total_mainers_created = 695;
    total_active_mainers = 458;
    total_paused_mainers = 237;
    total_cycles_all_mainers = 8134;
    active_low_burn_rate_mainers = 118;
    active_medium_burn_rate_mainers = 82;
    active_high_burn_rate_mainers = 258;
    active_very_high_burn_rate_mainers = 0;
    active_custom_burn_rate_mainers = 0;
    paused_low_burn_rate_mainers = 58;
    paused_medium_burn_rate_mainers = 38;
    paused_high_burn_rate_mainers = 141;
    paused_very_high_burn_rate_mainers = 0;
    paused_custom_burn_rate_mainers = 0;
})' -e local

# Get metrics count after creation
echo ""
echo "8. Getting metrics count after creation..."
icp canister call api_canister getNumDailyMetrics '()' -e local

# Get latest metric
echo ""
echo "9. Getting latest daily metric..."
icp canister call api_canister getLatestDailyMetric '()' -e local

# Get specific metric by date
echo ""
echo "10. Getting metric for specific date (2025-09-07)..."
icp canister call api_canister getDailyMetricByDate '("2025-09-07")' -e local

# Get all metrics (public endpoint without params)
echo ""
echo "11. Getting daily metrics (public endpoint - latest only)..."
icp canister call api_canister getDailyMetrics 'null' -e local

# Get metrics with date range
echo ""
echo "12. Getting metrics with date range..."
icp canister call api_canister getDailyMetrics '(opt record {
    start_date = opt "2025-09-07";
    end_date = opt "2025-09-08";
    limit = null;
})' -e local

# Test update functionality
echo ""
echo "13. Updating metric for 2025-09-08..."
icp canister call api_canister updateDailyMetricAdmin '(record {
    date = "2025-09-08";
    input = record {
        funnai_index = opt 0.35;
        daily_burn_rate_cycles = null;
        daily_burn_rate_usd = null;
        total_mainers_created = null;
        total_active_mainers = null;
        total_paused_mainers = null;
        total_cycles_all_mainers = null;
        active_low_burn_rate_mainers = null;
        active_medium_burn_rate_mainers = null;
        active_high_burn_rate_mainers = null;
        active_very_high_burn_rate_mainers = null;
        active_custom_burn_rate_mainers = null;
        paused_low_burn_rate_mainers = null;
        paused_medium_burn_rate_mainers = null;
        paused_high_burn_rate_mainers = null;
        paused_very_high_burn_rate_mainers = null;
        paused_custom_burn_rate_mainers = null;
    }
})' -e local

# Get updated metric
echo ""
echo "14. Getting updated metric..."
icp canister call api_canister getDailyMetricByDate '("2025-09-08")' -e local

# Test bulk create
echo ""
echo "15. Testing bulk create..."
icp canister call api_canister bulkCreateDailyMetricsAdmin '(vec {
    record {
        date = "2025-09-06";
        funnai_index = 0.25;
        daily_burn_rate_cycles = 1204;
        daily_burn_rate_usd = 1651.28;
        total_mainers_created = 689;
        total_active_mainers = 442;
        total_paused_mainers = 247;
        total_cycles_all_mainers = 7923;
        active_low_burn_rate_mainers = 115;
        active_medium_burn_rate_mainers = 79;
        active_high_burn_rate_mainers = 248;
        active_very_high_burn_rate_mainers = 0;
        active_custom_burn_rate_mainers = 0;
        paused_low_burn_rate_mainers = 61;
        paused_medium_burn_rate_mainers = 42;
        paused_high_burn_rate_mainers = 144;
        paused_very_high_burn_rate_mainers = 0;
        paused_custom_burn_rate_mainers = 0;
    };
    record {
        date = "2025-09-05";
        funnai_index = 0.22;
        daily_burn_rate_cycles = 1150;
        daily_burn_rate_usd = 1577.25;
        total_mainers_created = 682;
        total_active_mainers = 435;
        total_paused_mainers = 247;
        total_cycles_all_mainers = 7850;
        active_low_burn_rate_mainers = 112;
        active_medium_burn_rate_mainers = 77;
        active_high_burn_rate_mainers = 246;
        active_very_high_burn_rate_mainers = 0;
        active_custom_burn_rate_mainers = 0;
        paused_low_burn_rate_mainers = 62;
        paused_medium_burn_rate_mainers = 43;
        paused_high_burn_rate_mainers = 142;
        paused_very_high_burn_rate_mainers = 0;
        paused_custom_burn_rate_mainers = 0;
    };
})' -e local

# Get all metrics (admin endpoint)
echo ""
echo "16. Getting all metrics (admin endpoint)..."
icp canister call api_canister getDailyMetricsAdmin '()' -e local

# Get final count
echo ""
echo "17. Getting final metrics count..."
icp canister call api_canister getNumDailyMetrics '()' -e local

# Test delete functionality
echo ""
echo "18. Deleting metric for 2025-09-05..."
icp canister call api_canister deleteDailyMetricAdmin '("2025-09-05")' -e local

# Verify deletion
echo ""
echo "19. Verifying deletion - getting count..."
icp canister call api_canister getNumDailyMetrics '()' -e local

echo ""
echo "============================================"
echo "Testing complete!"
echo "============================================"