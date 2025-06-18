
import Principal "mo:base/Principal";
import D "mo:base/Debug";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Types "Types";
import Nat "mo:base/Nat";
import Error "mo:base/Error";
import Array "mo:base/Array";
import Constants "Constants";

module InstallCanisterCode {

    public func getTimerRegularityForCyclesBurnRate(cyclesBurnRate : Types.CyclesBurnRate, cyclesUsedPerResponse : Nat) : Nat {
        D.print("getTimerRegularityForCyclesBurnRate cyclesBurnRate " # debug_show(cyclesBurnRate));
        D.print("getTimerRegularityForCyclesBurnRate cyclesUsedPerResponse " # debug_show(cyclesUsedPerResponse));
        var timeIntervalDuration = Constants.SECONDS_IN_MINUTE * Constants.MINUTES_IN_HOUR * Constants.HOURS_IN_DAY; // Daily as default, i.e. this gives the seconds per day
        D.print("getTimerRegularityForCyclesBurnRate timeIntervalDuration " # debug_show(timeIntervalDuration));
        switch (cyclesBurnRate.timeInterval) {
            case (#Daily) {
                // use default
            };
        };
        // Calculate how many responses can be generated with the cycles budget based on response costs (generation plus submission)
        let submissionsInTimeInterval = cyclesBurnRate.cycles / cyclesUsedPerResponse;
        D.print("getTimerRegularityForCyclesBurnRate submissionsInTimeInterval " # debug_show(submissionsInTimeInterval));
        // Calculate how often to respond (in seconds)
        let timerRegularity = timeIntervalDuration / submissionsInTimeInterval;
        D.print("getTimerRegularityForCyclesBurnRate timerRegularity " # debug_show(timerRegularity));

        return timerRegularity;
    };

}