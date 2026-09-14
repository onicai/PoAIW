import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";

module {

    /// Hex digit for the low nibble of `n`. Callers mask, so v is always 0-15.
    func nat4ToChar(n : Nat8) : Char {
        let v = Nat32.fromNat(Nat8.toNat(n));
        if (v < 10) {
            Char.fromNat32(48 + v); // '0'..'9'
        } else {
            Char.fromNat32(87 + v); // 'a'..'f'
        };
    };

    /// Lowercase hex for one byte.
    func nat8ToText(byte : Nat8) : Text {
        Text.fromChar(nat4ToChar(byte >> 4)) # Text.fromChar(nat4ToChar(byte & 15));
    };

    /// Lowercase hex for a byte array. Renders an ICP account identifier for the
    /// index canister, which takes it as hex TEXT. Lowercase is what the index
    /// expects and what `dfx ledger account-id` prints.
    public func bytesToHex(bytes : [Nat8]) : Text {
        Text.join("", Iter.map<Nat8, Text>(Iter.fromArray(bytes), func(n : Nat8) : Text { nat8ToText(n) }));
    };

    /// Lowercase hex for a Blob.
    public func blobToHex(b : Blob) : Text {
        bytesToHex(Blob.toArray(b));
    };
};
