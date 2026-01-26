import Array "mo:base/Array";
import Types "../../common/Types";

module {
    // =========================================================================
    // Old Types (before total_cycles was added)
    // =========================================================================

    // Old SystemMetrics without total_cycles field
    type OldSystemMetrics = {
        funnai_index: Float;
        daily_burn_rate: Types.DailyBurnRate;
        // NOTE: total_cycles field did not exist in old version
    };

    // Old DailyMetric using OldSystemMetrics
    type OldDailyMetric = {
        metadata: Types.DailyMetricMetadata;
        system_metrics: OldSystemMetrics;
        mainers: Types.MainersMetrics;
        derived_metrics: Types.DerivedMetrics;
    };

    // =========================================================================
    // Old Stable State Structure
    // =========================================================================

    type OldState = {
        var dailyMetricsEntries : [(Text, OldDailyMetric)];
        var adminRoleAssignmentsStable : [(Text, Types.AdminRoleAssignment)];
    };

    // =========================================================================
    // New Stable State Structure
    // =========================================================================

    type NewState = {
        var dailyMetricsEntries : [(Text, Types.DailyMetric)];
        var adminRoleAssignmentsStable : [(Text, Types.AdminRoleAssignment)];
    };

    // =========================================================================
    // Migration Function
    // =========================================================================

    public func migration(old : OldState) : NewState {
        // Migrate dailyMetricsEntries: add total_cycles = null to each record
        let migratedEntries = Array.map<(Text, OldDailyMetric), (Text, Types.DailyMetric)>(
            old.dailyMetricsEntries,
            func((date, oldMetric) : (Text, OldDailyMetric)) : (Text, Types.DailyMetric) {
                (
                    date,
                    {
                        metadata = oldMetric.metadata;
                        system_metrics = {
                            funnai_index = oldMetric.system_metrics.funnai_index;
                            daily_burn_rate = oldMetric.system_metrics.daily_burn_rate;
                            total_cycles = null;  // New field, initialize to null
                        };
                        mainers = oldMetric.mainers;
                        derived_metrics = oldMetric.derived_metrics;
                    }
                )
            }
        );

        {
            var dailyMetricsEntries = migratedEntries;
            var adminRoleAssignmentsStable = old.adminRoleAssignmentsStable;
        }
    };
}
