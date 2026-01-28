import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";

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
}
