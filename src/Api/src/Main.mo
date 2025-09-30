import Principal "mo:base/Principal";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Float "mo:base/Float";
import Iter "mo:base/Iter";
import Option "mo:base/Option";

import Types "../../common/Types";

persistent actor class ApiCanister() = this {

    stable var MASTER_CANISTER_ID : Text = "r5m5y-diaaa-aaaaa-qanaa-cai"; // Corresponds to prd Game State canister

    public shared (msg) func setMasterCanisterId(newMasterCanisterId : Text) : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        MASTER_CANISTER_ID := newMasterCanisterId;
        let authRecord = { auth = "You set the master canister for this canister." };
        return #Ok(authRecord);
    };

    public query (msg) func getMasterCanisterId() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = { auth = "Master canister id for this canister: " # MASTER_CANISTER_ID };
        return #Ok(authRecord);
    };

    // -------------------------------------------------------------------------------
    // Canister Endpoints

    public shared query (msg) func whoami() : async Principal {
        return msg.caller;
    };

    // Function to verify that canister is up & running
    public shared query func health() : async Types.StatusCodeRecordResult {
        return #Ok({ status_code = 200 });
    };

    public shared query (msg) func amiController() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = { auth = "You are a controller of this canister." };
        return #Ok(authRecord);
    };

    // -------------------------------------------------------------------------------
    // Daily Metrics Storage

    // Using HashMap for O(1) lookups by date
    stable var dailyMetricsEntries : [(Text, Types.DailyMetric)] = [];
    transient var dailyMetrics = HashMap.HashMap<Text, Types.DailyMetric>(10, Text.equal, Text.hash);

    // -------------------------------------------------------------------------------
    // Token Rewards Data (Static)

    private func getTokenRewardsDataInternal() : Types.TokenRewardsData {
        {
        metadata = {
            dataset = "FUNNAI Token Minting Data";
            description = "Quarterly minting data showing total supply and rewards per challenge";
            version = "1.0";
            last_updated = "2025-09-25";
            units = {
                total_minted = "FUNNAI tokens";
                rewards_per_challenge = "FUNNAI tokens";
            };
        };
        data = [
            {
                date = "2025-06-29";
                quarter = "Q2 2025";
                total_minted = 0.0;
                rewards_per_challenge = 181.9032733;
                rewards_per_quarter = 2390209.011;
                notes = "";
            },
            {
                date = "2025-09-29";
                quarter = "Q3 2025";
                total_minted = 2390209.011;
                rewards_per_challenge = 139.9194939;
                rewards_per_quarter = 1838542.15;
                notes = "";
            },
            {
                date = "2025-12-29";
                quarter = "Q4 2025";
                total_minted = 4228751.161;
                rewards_per_challenge = 109.9310802;
                rewards_per_quarter = 1444494.393;
                notes = "";
            },
            {
                date = "2026-03-29";
                quarter = "Q1 2026";
                total_minted = 5673245.554;
                rewards_per_challenge = 88.51078458;
                rewards_per_quarter = 1163031.71;
                notes = "";
            },
            {
                date = "2026-06-29";
                quarter = "Q2 2026";
                total_minted = 6836277.264;
                rewards_per_challenge = 73.21057346;
                rewards_per_quarter = 961986.935;
                notes = "";
            },
            {
                date = "2026-09-29";
                quarter = "Q3 2026";
                total_minted = 7798264.199;
                rewards_per_challenge = 62.28185123;
                rewards_per_quarter = 818383.525;
                notes = "";
            },
            {
                date = "2026-12-29";
                quarter = "Q4 2026";
                total_minted = 8616647.724;
                rewards_per_challenge = 54.47562107;
                rewards_per_quarter = 715809.661;
                notes = "";
            },
            {
                date = "2027-03-29";
                quarter = "Q1 2027";
                total_minted = 9332457.385;
                rewards_per_challenge = 48.89974238;
                rewards_per_quarter = 642542.615;
                notes = "";
            },
            {
                date = "2027-06-29";
                quarter = "Q2 2027";
                total_minted = 9975000.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "Rewards per challenge stabilized at 34.96004566 from this date onward until max supply is reached";
            },
            {
                date = "2027-09-29";
                quarter = "Q3 2027";
                total_minted = 10434375.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2027-12-29";
                quarter = "Q4 2027";
                total_minted = 10893750.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2028-03-29";
                quarter = "Q1 2028";
                total_minted = 11353125.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2028-06-29";
                quarter = "Q2 2028";
                total_minted = 11812500.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2028-09-29";
                quarter = "Q3 2028";
                total_minted = 12271875.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2028-12-29";
                quarter = "Q4 2028";
                total_minted = 12731250.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2029-03-29";
                quarter = "Q1 2029";
                total_minted = 13190625.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2029-06-29";
                quarter = "Q2 2029";
                total_minted = 13650000.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2029-09-29";
                quarter = "Q3 2029";
                total_minted = 14109375.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2029-12-29";
                quarter = "Q4 2029";
                total_minted = 14568750.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2030-03-29";
                quarter = "Q1 2030";
                total_minted = 15028125.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2030-06-29";
                quarter = "Q2 2030";
                total_minted = 15487500.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2030-09-29";
                quarter = "Q3 2030";
                total_minted = 15946875.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2030-12-29";
                quarter = "Q4 2030";
                total_minted = 16406250.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2031-03-29";
                quarter = "Q1 2031";
                total_minted = 16865625.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2031-06-29";
                quarter = "Q2 2031";
                total_minted = 17325000.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2031-09-29";
                quarter = "Q3 2031";
                total_minted = 17784375.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2031-12-29";
                quarter = "Q4 2031";
                total_minted = 18243750.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2032-03-29";
                quarter = "Q1 2032";
                total_minted = 18703125.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2032-06-29";
                quarter = "Q2 2032";
                total_minted = 19162500.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2032-09-29";
                quarter = "Q3 2032";
                total_minted = 19621875.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2032-12-29";
                quarter = "Q4 2032";
                total_minted = 20081250.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2033-03-29";
                quarter = "Q1 2033";
                total_minted = 20540625.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2033-06-29";
                quarter = "Q2 2033";
                total_minted = 21000000.0;
                rewards_per_challenge = 0.0;
                rewards_per_quarter = 0.0;
                notes = "Maximum supply reached.";
            }
        ];
        }
    };

    // -------------------------------------------------------------------------------
    // Helper Functions

    // Validate date format (YYYY-MM-DD)
    private func isValidDateFormat(date: Text) : Bool {
        if (date.size() != 10) { return false; };
        let chars = date.chars();
        var i = 0;
        for (c in chars) {
            if (i == 4 or i == 7) {
                if (c != '-') { return false; };
            } else {
                if (c < '0' or c > '9') { return false; };
            };
            i += 1;
        };
        return true;
    };

    // Compare dates (returns -1 if date1 < date2, 0 if equal, 1 if date1 > date2)
    private func compareDates(date1: Text, date2: Text) : Int {
        if (date1 < date2) { return -1; };
        if (date1 > date2) { return 1; };
        return 0;
    };

    // Get current timestamp in ISO 8601 format
    private func getCurrentTimestamp() : Text {
        let now = Time.now();
        // Simple timestamp format (this is a simplified version)
        // In production, you might want a more sophisticated ISO 8601 formatter
        Int.toText(now)
    };

    // Calculate derived metrics from input data
    private func calculateDerivedMetrics(input: Types.DailyMetricInput) : Types.DerivedMetrics {
        let total = Float.fromInt(input.total_mainers_created);
        let active = Float.fromInt(input.total_active_mainers);
        let paused = Float.fromInt(input.total_paused_mainers);
        
        let activePercentage = if (total > 0) { (active / total) * 100 } else { 0.0 };
        let pausedPercentage = if (total > 0) { (paused / total) * 100 } else { 0.0 };
        let avgCyclesPerMainer = if (total > 0) { Float.fromInt(input.total_cycles_all_mainers) / total } else { 0.0 };
        let burnRatePerActiveMainer = if (active > 0) { Float.fromInt(input.daily_burn_rate_cycles) / active } else { 0.0 };
        
        let totalActiveTiers = Float.fromInt(
            input.active_low_burn_rate_mainers +
            input.active_medium_burn_rate_mainers +
            input.active_high_burn_rate_mainers +
            input.active_very_high_burn_rate_mainers +
            input.active_custom_burn_rate_mainers
        );
        
        {
            active_percentage = activePercentage;
            paused_percentage = pausedPercentage;
            avg_cycles_per_mainer = avgCyclesPerMainer;
            burn_rate_per_active_mainer = burnRatePerActiveMainer;
            tier_distribution = {
                low = if (totalActiveTiers > 0) { (Float.fromInt(input.active_low_burn_rate_mainers) / totalActiveTiers) * 100 } else { 0.0 };
                medium = if (totalActiveTiers > 0) { (Float.fromInt(input.active_medium_burn_rate_mainers) / totalActiveTiers) * 100 } else { 0.0 };
                high = if (totalActiveTiers > 0) { (Float.fromInt(input.active_high_burn_rate_mainers) / totalActiveTiers) * 100 } else { 0.0 };
                very_high = if (totalActiveTiers > 0) { (Float.fromInt(input.active_very_high_burn_rate_mainers) / totalActiveTiers) * 100 } else { 0.0 };
                custom = if (totalActiveTiers > 0) { (Float.fromInt(input.active_custom_burn_rate_mainers) / totalActiveTiers) * 100 } else { 0.0 };
            };
        }
    };

    // Convert input to DailyMetric
    private func inputToDailyMetric(input: Types.DailyMetricInput, _isUpdate: Bool) : Types.DailyMetric {
        let timestamp = getCurrentTimestamp();
        let existing = dailyMetrics.get(input.date);
        
        let createdAt = switch (existing) {
            case (?metric) { metric.metadata.created_at };
            case null { timestamp };
        };
        
        {
            metadata = {
                date = input.date;
                created_at = createdAt;
                updated_at = timestamp;
            };
            system_metrics = {
                funnai_index = input.funnai_index;
                daily_burn_rate = {
                    cycles = input.daily_burn_rate_cycles;
                    usd = input.daily_burn_rate_usd;
                };
            };
            mainers = {
                totals = {
                    created = input.total_mainers_created;
                    active = input.total_active_mainers;
                    paused = input.total_paused_mainers;
                    total_cycles = input.total_cycles_all_mainers;
                };
                breakdown_by_tier = {
                    active = {
                        low = input.active_low_burn_rate_mainers;
                        medium = input.active_medium_burn_rate_mainers;
                        high = input.active_high_burn_rate_mainers;
                        very_high = input.active_very_high_burn_rate_mainers;
                        custom = input.active_custom_burn_rate_mainers;
                    };
                    paused = {
                        low = input.paused_low_burn_rate_mainers;
                        medium = input.paused_medium_burn_rate_mainers;
                        high = input.paused_high_burn_rate_mainers;
                        very_high = input.paused_very_high_burn_rate_mainers;
                        custom = input.paused_custom_burn_rate_mainers;
                    };
                };
            };
            derived_metrics = calculateDerivedMetrics(input);
        }
    };

    // -------------------------------------------------------------------------------
    // Admin CRUD Endpoints

    public shared (msg) func createDailyMetricAdmin(input: Types.DailyMetricInput) : async Types.DailyMetricResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not (Principal.isController(msg.caller) or Principal.equal(msg.caller, Principal.fromText(MASTER_CANISTER_ID)))) {
            return #Err(#Unauthorized);
        };
        
        // Validate date format
        if (not isValidDateFormat(input.date)) {
            return #Err(#Other("Invalid date format. Use YYYY-MM-DD"));
        };
        
        // Check if metric already exists
        switch (dailyMetrics.get(input.date)) {
            case (?_existing) {
                return #Err(#Other("Metric for date " # input.date # " already exists"));
            };
            case null {
                let metric = inputToDailyMetric(input, false);
                dailyMetrics.put(input.date, metric);
                return #Ok(metric);
            };
        };
    };

    public shared (msg) func updateDailyMetricAdmin(params: Types.UpdateDailyMetricAdminInput) : async Types.DailyMetricResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not (Principal.isController(msg.caller) or Principal.equal(msg.caller, Principal.fromText(MASTER_CANISTER_ID)))) {
            return #Err(#Unauthorized);
        };
        
        // Validate date format
        if (not isValidDateFormat(params.date)) {
            return #Err(#Other("Invalid date format. Use YYYY-MM-DD"));
        };

        // Get existing metric
        switch (dailyMetrics.get(params.date)) {
            case null {
                return #Err(#Other("Metric for date " # params.date # " not found"));
            };
            case (?existing) {
                // Create full input from partial update
                let fullInput : Types.DailyMetricInput = {
                    date = params.date;
                    funnai_index = Option.get(params.input.funnai_index, existing.system_metrics.funnai_index);
                    daily_burn_rate_cycles = Option.get(params.input.daily_burn_rate_cycles, existing.system_metrics.daily_burn_rate.cycles);
                    daily_burn_rate_usd = Option.get(params.input.daily_burn_rate_usd, existing.system_metrics.daily_burn_rate.usd);
                    total_mainers_created = Option.get(params.input.total_mainers_created, existing.mainers.totals.created);
                    total_active_mainers = Option.get(params.input.total_active_mainers, existing.mainers.totals.active);
                    total_paused_mainers = Option.get(params.input.total_paused_mainers, existing.mainers.totals.paused);
                    total_cycles_all_mainers = Option.get(params.input.total_cycles_all_mainers, existing.mainers.totals.total_cycles);
                    active_low_burn_rate_mainers = Option.get(params.input.active_low_burn_rate_mainers, existing.mainers.breakdown_by_tier.active.low);
                    active_medium_burn_rate_mainers = Option.get(params.input.active_medium_burn_rate_mainers, existing.mainers.breakdown_by_tier.active.medium);
                    active_high_burn_rate_mainers = Option.get(params.input.active_high_burn_rate_mainers, existing.mainers.breakdown_by_tier.active.high);
                    active_very_high_burn_rate_mainers = Option.get(params.input.active_very_high_burn_rate_mainers, existing.mainers.breakdown_by_tier.active.very_high);
                    active_custom_burn_rate_mainers = Option.get(params.input.active_custom_burn_rate_mainers, existing.mainers.breakdown_by_tier.active.custom);
                    paused_low_burn_rate_mainers = Option.get(params.input.paused_low_burn_rate_mainers, existing.mainers.breakdown_by_tier.paused.low);
                    paused_medium_burn_rate_mainers = Option.get(params.input.paused_medium_burn_rate_mainers, existing.mainers.breakdown_by_tier.paused.medium);
                    paused_high_burn_rate_mainers = Option.get(params.input.paused_high_burn_rate_mainers, existing.mainers.breakdown_by_tier.paused.high);
                    paused_very_high_burn_rate_mainers = Option.get(params.input.paused_very_high_burn_rate_mainers, existing.mainers.breakdown_by_tier.paused.very_high);
                    paused_custom_burn_rate_mainers = Option.get(params.input.paused_custom_burn_rate_mainers, existing.mainers.breakdown_by_tier.paused.custom);
                };
                
                let updatedMetric = inputToDailyMetric(fullInput, true);
                dailyMetrics.put(params.date, updatedMetric);
                return #Ok(updatedMetric);
            };
        };
    };

    public shared (msg) func deleteDailyMetricAdmin(date: Text) : async Types.NatResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not (Principal.isController(msg.caller) or Principal.equal(msg.caller, Principal.fromText(MASTER_CANISTER_ID)))) {
            return #Err(#Unauthorized);
        };
        
        // Validate date format
        if (not isValidDateFormat(date)) {
            return #Err(#Other("Invalid date format. Use YYYY-MM-DD"));
        };
        
        switch (dailyMetrics.remove(date)) {
            case null {
                return #Err(#Other("Metric for date " # date # " not found"));
            };
            case (?_) {
                return #Ok(1);  // Return 1 to indicate successful deletion
            };
        };
    };

    public query (msg) func getDailyMetricsAdmin() : async Types.DailyMetricsResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        
        let allMetrics = Iter.toArray(dailyMetrics.vals());
        
        // Sort by date (most recent first)
        let sortedMetrics = Array.sort<Types.DailyMetric>(allMetrics, func(a, b) {
            switch (compareDates(b.metadata.date, a.metadata.date)) {
                case (-1) { #less };
                case (0) { #equal };
                case (1) { #greater };
                case (_) { #equal };
            }
        });
        
        if (sortedMetrics.size() == 0) {
            return #Ok({
                period = {
                    start_date = "";
                    end_date = "";
                    total_days = 0;
                };
                daily_metrics = [];
            });
        };
        
        let response : Types.DailyMetricsResponse = {
            period = {
                start_date = sortedMetrics[sortedMetrics.size() - 1].metadata.date;
                end_date = sortedMetrics[0].metadata.date;
                total_days = sortedMetrics.size();
            };
            daily_metrics = sortedMetrics;
        };
        
        return #Ok(response);
    };

    public shared (msg) func bulkCreateDailyMetricsAdmin(inputs: [Types.DailyMetricInput]) : async Types.NatResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not (Principal.isController(msg.caller) or Principal.equal(msg.caller, Principal.fromText(MASTER_CANISTER_ID)))) {
            return #Err(#Unauthorized);
        };

        var created = 0;

        for (input in inputs.vals()) {
            // Validate date format
            if (isValidDateFormat(input.date)) {
                // Only create if doesn't exist
                switch (dailyMetrics.get(input.date)) {
                    case null {
                        let metric = inputToDailyMetric(input, false);
                        dailyMetrics.put(input.date, metric);
                        created += 1;
                    };
                    case (?_) {
                        // Skip existing dates
                    };
                };
            };
        };

        return #Ok(created);
    };

    public shared (msg) func resetDailyMetricsAdmin() : async Types.NatResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let count = dailyMetrics.size();

        // Clear all metrics from the HashMap
        for (key in dailyMetrics.keys()) {
            dailyMetrics.delete(key);
        };

        return #Ok(count);  // Return the number of metrics that were deleted
    };

    // -------------------------------------------------------------------------------
    // Public Query Endpoints

    public shared query func getDailyMetrics(dailyMetricsQuery: ?Types.DailyMetricsQuery) : async Types.DailyMetricsResult {
        let allMetrics = Iter.toArray(dailyMetrics.vals());
        
        if (allMetrics.size() == 0) {
            return #Ok({
                period = {
                    start_date = "";
                    end_date = "";
                    total_days = 0;
                };
                daily_metrics = [];
            });
        };
        
        // Sort by date (most recent first)
        var sortedMetrics = Array.sort<Types.DailyMetric>(allMetrics, func(a, b) {
            switch (compareDates(b.metadata.date, a.metadata.date)) {
                case (-1) { #less };
                case (0) { #equal };
                case (1) { #greater };
                case (_) { #equal };
            }
        });
        
        // Apply filters based on query parameters
        switch (dailyMetricsQuery) {
            case null {
                // No query params - return latest metric only
                if (sortedMetrics.size() > 0) {
                    sortedMetrics := [sortedMetrics[0]];
                };
            };
            case (?q) {
                // Filter by date range if specified
                sortedMetrics := Array.filter<Types.DailyMetric>(sortedMetrics, func(metric) {
                    var include = true;
                    
                    switch (q.start_date) {
                        case (?startDate) {
                            if (isValidDateFormat(startDate) and compareDates(metric.metadata.date, startDate) < 0) {
                                include := false;
                            };
                        };
                        case null {};
                    };
                    
                    switch (q.end_date) {
                        case (?endDate) {
                            if (isValidDateFormat(endDate) and compareDates(metric.metadata.date, endDate) > 0) {
                                include := false;
                            };
                        };
                        case null {};
                    };
                    
                    include
                });
                
                // Apply limit if specified
                switch (q.limit) {
                    case (?limit) {
                        if (limit < sortedMetrics.size()) {
                            sortedMetrics := Array.subArray<Types.DailyMetric>(sortedMetrics, 0, limit);
                        };
                    };
                    case null {};
                };
            };
        };
        
        if (sortedMetrics.size() == 0) {
            return #Ok({
                period = {
                    start_date = "";
                    end_date = "";
                    total_days = 0;
                };
                daily_metrics = [];
            });
        };
        
        let response : Types.DailyMetricsResponse = {
            period = {
                start_date = sortedMetrics[sortedMetrics.size() - 1].metadata.date;
                end_date = sortedMetrics[0].metadata.date;
                total_days = sortedMetrics.size();
            };
            daily_metrics = sortedMetrics;
        };
        
        return #Ok(response);
    };

    public shared query func getLatestDailyMetric() : async Types.DailyMetricResult {
        let allMetrics = Iter.toArray(dailyMetrics.vals());
        
        if (allMetrics.size() == 0) {
            return #Err(#Other("No metrics available"));
        };
        
        // Sort by date (most recent first)
        let sortedMetrics = Array.sort<Types.DailyMetric>(allMetrics, func(a, b) {
            switch (compareDates(b.metadata.date, a.metadata.date)) {
                case (-1) { #less };
                case (0) { #equal };
                case (1) { #greater };
                case (_) { #equal };
            }
        });
        
        return #Ok(sortedMetrics[0]);
    };

    public shared query func getDailyMetricByDate(date: Text) : async Types.DailyMetricResult {
        // Validate date format
        if (not isValidDateFormat(date)) {
            return #Err(#Other("Invalid date format. Use YYYY-MM-DD"));
        };
        
        switch (dailyMetrics.get(date)) {
            case null {
                return #Err(#Other("Metric for date " # date # " not found"));
            };
            case (?metric) {
                return #Ok(metric);
            };
        };
    };

    public shared query func getNumDailyMetrics() : async Types.NatResult {
        return #Ok(dailyMetrics.size());
    };

    // -------------------------------------------------------------------------------
    // Token Rewards Public Query Endpoints

    public shared query func getTokenRewardsData() : async Types.TokenRewardsDataResult {
        return #Ok(getTokenRewardsDataInternal());
    };


    // System upgrade hooks
    system func preupgrade() {
        dailyMetricsEntries := Iter.toArray(dailyMetrics.entries());
    };

    system func postupgrade() {
        dailyMetrics := HashMap.fromIter<Text, Types.DailyMetric>(dailyMetricsEntries.vals(), dailyMetricsEntries.size(), Text.equal, Text.hash);
        dailyMetricsEntries := [];
    };
};