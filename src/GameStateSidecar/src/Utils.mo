import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";

module {

    /// Hex digit for the low nibble of `n`.
    ///
    /// Computed rather than written as a 16-case switch (the shape used elsewhere
    /// in this repo) so there is no unreachable default to fall off. `n` is masked
    /// by the caller, so the value is always 0-15.
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

    /// Lowercase hex for a byte array.
    ///
    /// Used to render an ICP account identifier for the index canister, which takes
    /// `account_identifier` as hex TEXT while the ledger uses a 32-byte Blob. The
    /// index answers a malformed or wrongly-cased identifier with an EMPTY
    /// transaction list rather than an error, so getting this wrong looks exactly
    /// like having nothing to sweep. Lowercase is what dfx's `ledger account-id`
    /// prints and what the index expects.
    public func bytesToHex(bytes : [Nat8]) : Text {
        Text.join("", Iter.map<Nat8, Text>(Iter.fromArray(bytes), func(n : Nat8) : Text { nat8ToText(n) }));
    };

    /// Lowercase hex for a Blob.
    public func blobToHex(b : Blob) : Text {
        bytesToHex(Blob.toArray(b));
    };
};
