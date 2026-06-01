import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Text "mo:base/Text";

module Util {

    /// Slice an array with offset and limit for pagination
    public func sliceArray<T>(arr : [T], offset : Nat, limit : Nat) : [T] {
        let size = arr.size();
        if (offset >= size) { return []; };
        let end = Nat.min(offset + limit, size);
        Array.tabulate<T>(end - offset, func(i) { arr[offset + i] });
    };

    /// Collect items matching predicate with early-stop optimization
    /// Assumes array is sorted DESC by the field used in predicate
    public func collectWithEarlyStop<T>(
        arr : [T],
        predicate : T -> Bool,
        offset : Nat,
        limit : Nat
    ) : ([T], Nat) {
        let result = Buffer.Buffer<T>(limit);
        var totalMatching : Nat = 0;
        var skipped : Nat = 0;

        label scanning for (item in arr.vals()) {
            if (predicate(item)) {
                totalMatching += 1;
                if (skipped < offset) { skipped += 1; }
                else if (result.size() < limit) { result.add(item); };
            } else {
                break scanning;
            };
        };

        (Buffer.toArray(result), totalMatching)
    };

    /// Format an Int timestamp (nanoseconds since 1970-01-01 UTC) as a YYYY-MM-DD
    /// date string. Uses Howard Hinnant's civil_from_days algorithm, which is
    /// branch-free for the Gregorian calendar and valid across the full Int range.
    public func toIsoDate(nanos : Int) : Text {
        let nsPerDay : Int = 86_400_000_000_000;
        // Floor-divide nanos by nsPerDay so dates before 1970 (Int<0) round toward
        // negative infinity, matching civil_from_days' expectation.
        var days : Int = nanos / nsPerDay;
        if (nanos < 0 and nanos % nsPerDay != 0) { days -= 1; };

        let shifted : Int = days + 719468;
        let era : Int = if (shifted >= 0) { shifted / 146097 } else { (shifted - 146096) / 146097 };
        let doe : Int = shifted - era * 146097;
        let yoe : Int = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        var y : Int = yoe + era * 400;
        let doy : Int = doe - (365 * yoe + yoe / 4 - yoe / 100);
        let mp : Int = (5 * doy + 2) / 153;
        let d : Int = doy - (153 * mp + 2) / 5 + 1;
        let m : Int = if (mp < 10) { mp + 3 } else { mp - 9 };
        if (m <= 2) { y += 1; };

        Int.toText(y) # "-" # pad2(m) # "-" # pad2(d)
    };

    func pad2(n : Int) : Text {
        let s = Int.toText(n);
        if (Text.size(s) < 2) { "0" # s } else { s };
    };
}
