import Types "../../common/Types";

module {
    // =========================================================================
    // Identity Migration (no schema changes)
    // =========================================================================

    type State = {
        var dailyMetricsEntries : [(Text, Types.DailyMetric)];
        var adminRoleAssignmentsStable : [(Text, Types.AdminRoleAssignment)];
    };

    public func migration(state : State) : State {
        state
    };
}
