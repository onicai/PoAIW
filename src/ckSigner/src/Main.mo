import Array "mo:base/Array";
import Blob "mo:base/Blob";
import D "mo:base/Debug";
import Error "mo:base/Error";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

import Common "mo:bitcoin/Common";
import Curves "mo:bitcoin/ec/Curves";
import Hash "mo:bitcoin/Hash";
import { tweakPublicKey } "mo:bitcoin/bitcoin/P2tr";
import Segwit "mo:bitcoin/Segwit";

import Types "../../common/Types";
import ICManagement "../../common/ICManagementCanister";
import TokenLedger "../../common/icp-ledger-interface";

persistent actor class CkSigner(initSchnorrKeyName : Text) = self {

    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------

    // Schnorr key name — set via init argument per environment:
    //   "dfx_test_key" = local replica
    //   "test_key_1"   = IC mainnet testing/development (cheaper, 13-node subnet)
    //   "key_1"        = IC mainnet production (34-node fiduciary subnet)
    var schnorrKeyName : Text = initSchnorrKeyName;

    // Cycles to attach for management canister calls
    let SCHNORR_CYCLES : Nat = 100_000_000_000;

    // Management canister
    let ic : ICManagement.IC_Management = actor ("aaaaa-aa");

    // ---------------------------------------------------------------
    // Fee collection
    // ---------------------------------------------------------------
    // Accepted fee tokens for sign(). Supports any ICRC-2 compatible ledger.
    // Empty map = free signing. Controller configures via addFeeToken /
    // removeFeeToken. Caller specifies payment in sign() — O(1)
    // lookup, single transfer_from, no looping.

    var feeTokensStable : [(Principal, Types.FeeToken)] = [];

    // Treasury — receives all signing fees. Default: funnAI Treasury Canister (prd).
    // Controller can update via setTreasury.
    var treasury : Types.Treasury = {
        treasuryName = "funnAI Treasury Canister";
        treasuryPrincipal = Principal.fromText("qbhxa-ziaaa-aaaaa-qbqza-cai");
    };

    // ---------------------------------------------------------------
    // Transient state (cleared on upgrade, rebuilt in postupgrade)
    // ---------------------------------------------------------------

    transient var feeTokens : HashMap.HashMap<Principal, Types.FeeToken> = HashMap.HashMap(0, Principal.equal, Principal.hash);

    // Cached public keys: "principal:botName" -> Blob (x-only 32 bytes)
    // Deliberately NOT persisted across upgrades: cache entries are cheap to
    // recompute (one management canister call), and clearing on upgrade avoids
    // accumulating stale keys from callers who no longer use the service.
    transient var publicKeyCache : HashMap.HashMap<Text, Blob> = HashMap.HashMap(0, Text.equal, Text.hash);

    // ---------------------------------------------------------------
    // Helper functions
    // ---------------------------------------------------------------

    private func bytesToHex(bytes : [Nat8]) : Text {
        let hexChars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"];
        var result = "";
        for (byte in bytes.vals()) {
            let hi = Nat8.toNat(byte / 16);
            let lo = Nat8.toNat(byte % 16);
            result := result # hexChars[hi] # hexChars[lo];
        };
        result;
    };

    // Extract x-only public key (bytes 1..33 from SEC1 compressed 33-byte key)
    private func extractXOnly(compressedKey : Blob) : Blob {
        let bytes = Blob.toArray(compressedKey);
        let xOnly = Array.tabulate<Nat8>(32, func(i : Nat) : Nat8 {
            bytes[i + 1];
        });
        Blob.fromArray(xOnly);
    };

    // Build cache key scoped by caller principal and bot name
    private func buildCacheKey(caller : Principal, botName : Text) : Text {
        Principal.toText(caller) # ":" # botName;
    };

    // Build derivation path scoped by caller principal and bot name
    private func buildDerivationPath(caller : Principal, botName : Text) : [Blob] {
        [Principal.toBlob(caller), Text.encodeUtf8(botName)];
    };

    // Derive correct BIP341 P2TR address from x-only public key (with Taproot tweak)
    // Uses DFINITY's mo:bitcoin library for secp256k1 EC math and Bech32m encoding
    private func deriveP2TRAddress(xOnlyKeyBytes : [Nat8]) : Result.Result<Text, Text> {
        // BIP341 key-path-only: tweak = tagged_hash("TapTweak", P)
        // No merkle root appended (no script tree)
        let tweakBytes = Hash.taggedHash(xOnlyKeyBytes, "TapTweak");
        let tweakNat = Common.readBE256(tweakBytes, 0);
        if (tweakNat >= Curves.secp256k1.r) {
            return #err("tweak exceeds curve order");
        };
        let tweak = Curves.secp256k1.Fp(tweakNat);
        let tweakedKey = switch (tweakPublicKey(xOnlyKeyBytes, tweak)) {
            case (#ok pk) pk.bip340_public_key;
            case (#err e) return #err(e);
        };
        Segwit.encode("bc", { version = 1 : Nat8; program = tweakedKey });
    };

    // Build fee info string for self-discovery in sign() error responses
    private func buildFeeInfo() : Text {
        let canId = Principal.toText(Principal.fromActor(self));
        var tokenList = "";
        for ((_, ft) in feeTokensStable.vals()) {
            if (tokenList != "") { tokenList := tokenList # ", " };
            tokenList := tokenList # ft.tokenName # " (tokenLedger=" # Principal.toText(ft.tokenLedger) # ", fee=" # Nat.toText(ft.fee) # ")";
        };
        "canisterId=" # canId #
        ". " # treasury.treasuryName # " (" # Principal.toText(treasury.treasuryPrincipal) # ")" #
        ". Accepted tokens: " # tokenList #
        ". Usage: 1) Call icrc2_approve on the token ledger with spender=" # canId # " and amount >= fee (e.g. 100 sats for ckBTC). " #
        "2) Call sign() with payment = record { tokenName; tokenLedger; amount }. " #
        "The canister will transfer_from your account to the " # treasury.treasuryName # ". See also: getFeeTokens().";
    };

    // ---------------------------------------------------------------
    // Public endpoints
    // ---------------------------------------------------------------

    // Health check (public, no auth)
    public shared query func health() : async Types.StatusCodeRecordResult {
        D.print("ckSigner:health - called");
        #Ok({ status_code = 200 });
    };

    // Controller check
    public shared query (msg) func amiController() : async Types.StatusCodeRecordResult {
        D.print("ckSigner:amiController - called by " # Principal.toText(msg.caller));
        if (Principal.isAnonymous(msg.caller) or not Principal.isController(msg.caller)) {
            D.print("ckSigner:amiController - unauthorized caller " # Principal.toText(msg.caller));
            return #Err(#Unauthorized);
        };
        D.print("ckSigner:amiController - caller is controller");
        #Ok({ status_code = 200 });
    };

    // ---------------------------------------------------------------
    // Fee token management (controller only)
    // ---------------------------------------------------------------

    // Query: get all accepted fee tokens (public — SDK needs this)
    // Returns canisterId (for icrc2_approve spender), treasury, and usage instructions
    public shared query func getFeeTokens() : async Types.FeeTokensResult {
        D.print("ckSigner:getFeeTokens - called");
        let canId = Principal.fromActor(self);
        let tokens = Array.map<(Principal, Types.FeeToken), Types.FeeToken>(
            feeTokensStable,
            func((_, ft) : (Principal, Types.FeeToken)) : Types.FeeToken { ft },
        );
        #Ok({
            canisterId = canId;
            treasury = treasury;
            feeTokens = tokens;
            usage = "To pay for sign(): " #
                "1) Call icrc2_approve on the token ledger with spender=" # Principal.toText(canId) # " and amount >= fee (e.g. 100 sats for ckBTC). " #
                "2) Call sign() with payment = record { tokenName; tokenLedger; amount }. " #
                "The canister will transfer_from your account to the " # treasury.treasuryName # " (" # Principal.toText(treasury.treasuryPrincipal) # ").";
        });
    };

    // Add or update an accepted fee token (controller only, idempotent)
    public shared (msg) func addFeeToken(input : Types.AddFeeTokenInput) : async Types.StatusCodeRecordResult {
        D.print("ckSigner:addFeeToken - called by " # Principal.toText(msg.caller));
        if (Principal.isAnonymous(msg.caller) or not Principal.isController(msg.caller)) {
            D.print("ckSigner:addFeeToken - unauthorized caller " # Principal.toText(msg.caller));
            return #Err(#Unauthorized);
        };
        feeTokens.put(input.tokenLedger, { tokenName = input.tokenName; tokenLedger = input.tokenLedger; fee = input.fee });
        feeTokensStable := Iter.toArray(feeTokens.entries());
        D.print("ckSigner:addFeeToken - added fee token: " # input.tokenName # " (tokenLedger=" # Principal.toText(input.tokenLedger) # ", fee=" # Nat.toText(input.fee) # ")");
        #Ok({ status_code = 200 });
    };

    // Remove an accepted fee token (controller only, idempotent)
    public shared (msg) func removeFeeToken(input : Types.RemoveFeeTokenInput) : async Types.StatusCodeRecordResult {
        D.print("ckSigner:removeFeeToken - called by " # Principal.toText(msg.caller));
        if (Principal.isAnonymous(msg.caller) or not Principal.isController(msg.caller)) {
            D.print("ckSigner:removeFeeToken - unauthorized caller " # Principal.toText(msg.caller));
            return #Err(#Unauthorized);
        };
        feeTokens.delete(input.tokenLedger);
        feeTokensStable := Iter.toArray(feeTokens.entries());
        D.print("ckSigner:removeFeeToken - removed fee token for tokenLedger " # Principal.toText(input.tokenLedger));
        #Ok({ status_code = 200 });
    };

    // Treasury management (controller only)

    public shared query func getTreasury() : async Types.TreasuryResult {
        D.print("ckSigner:getTreasury - called");
        #Ok(treasury);
    };

    public shared (msg) func setTreasury(input : Types.Treasury) : async Types.StatusCodeRecordResult {
        D.print("ckSigner:setTreasury - called by " # Principal.toText(msg.caller));
        if (Principal.isAnonymous(msg.caller) or not Principal.isController(msg.caller)) {
            D.print("ckSigner:setTreasury - unauthorized caller " # Principal.toText(msg.caller));
            return #Err(#Unauthorized);
        };
        treasury := input;
        D.print("ckSigner:setTreasury - set to " # input.treasuryName # " (" # Principal.toText(input.treasuryPrincipal) # ")");
        #Ok({ status_code = 200 });
    };

    // ---------------------------------------------------------------
    // validateGetPublicKeyInput - Validate caller and botName
    // Returns null if valid, or the ApiError to return
    // ---------------------------------------------------------------
    private func validateGetPublicKeyInput(caller : Principal, botName : Text) : ?Types.ApiError {
        if (Principal.isAnonymous(caller)) { return ?#Unauthorized };
        if (Text.size(botName) == 0) { return ?#Other("botName cannot be empty") };
        null;
    };

    // ---------------------------------------------------------------
    // buildPublicKeyRecord - Build PublicKeyRecord from cached key bytes
    // ---------------------------------------------------------------
    private func buildPublicKeyRecord(botName : Text, keyBytes : [Nat8]) : Types.PublicKeyResult {
        let address = switch (deriveP2TRAddress(keyBytes)) {
            case (#ok addr) addr;
            case (#err e) return #Err(#Other("P2TR address derivation failed: " # e));
        };
        #Ok({
            botName = botName;
            publicKeyHex = bytesToHex(keyBytes);
            address = address;
        });
    };

    // ---------------------------------------------------------------
    // getPublicKeyQuery - Get public key from cache (query call)
    // Clients should call this first. On cache miss, call getPublicKey.
    // ---------------------------------------------------------------
    public shared query (msg) func getPublicKeyQuery(
        input : Types.GetPublicKeyInput,
    ) : async Types.PublicKeyResult {
        D.print("ckSigner:getPublicKeyQuery - entered with botName=" # input.botName # ", caller=" # Principal.toText(msg.caller));
        switch (validateGetPublicKeyInput(msg.caller, input.botName)) {
            case (?err) { return #Err(err) };
            case null {};
        };

        let ck = buildCacheKey(msg.caller, input.botName);
        switch (publicKeyCache.get(ck)) {
            case (?cachedKey) {
                D.print("ckSigner:getPublicKeyQuery - cache hit for " # ck);
                buildPublicKeyRecord(input.botName, Blob.toArray(cachedKey));
            };
            case null {
                D.print("ckSigner:getPublicKeyQuery - cache miss for " # ck);
                #Err(#Other("Not Found - call getPublicKey to populate cache."));
            };
        };
    };

    // ---------------------------------------------------------------
    // getPublicKey - Get public key for a named bot (update call)
    // Fetches from management canister on cache miss, populates cache.
    // ---------------------------------------------------------------
    public shared (msg) func getPublicKey(
        input : Types.GetPublicKeyInput,
    ) : async Types.PublicKeyResult {
        D.print("ckSigner:getPublicKey - entered with botName=" # input.botName # ", caller=" # Principal.toText(msg.caller));
        switch (validateGetPublicKeyInput(msg.caller, input.botName)) {
            case (?err) { return #Err(err) };
            case null {};
        };

        // Check cache first
        let ck = buildCacheKey(msg.caller, input.botName);
        switch (publicKeyCache.get(ck)) {
            case (?cachedKey) {
                D.print("ckSigner:getPublicKey - cache hit for " # ck);
                return buildPublicKeyRecord(input.botName, Blob.toArray(cachedKey));
            };
            case null {
                D.print("ckSigner:getPublicKey - cache miss for " # ck # ", calling management canister");
            };
        };

        D.print("ckSigner:getPublicKey - derivation path: [" # Principal.toText(msg.caller) # ", " # input.botName # "]");

        // Call management canister
        try {
            D.print("ckSigner:getPublicKey - calling schnorr_public_key with " # Nat.toText(SCHNORR_CYCLES) # " cycles");
            ExperimentalCycles.add<system>(SCHNORR_CYCLES);
            let result = await ic.schnorr_public_key({
                key_id = {
                    algorithm = #bip340secp256k1;
                    name = schnorrKeyName;
                };
                canister_id = null;
                derivation_path = buildDerivationPath(msg.caller, input.botName);
            });

            D.print("ckSigner:getPublicKey - schnorr_public_key returned, key size=" # Nat.toText(Blob.toArray(result.public_key).size()) # " bytes");
            let xOnlyKey = extractXOnly(result.public_key);
            let xOnlyBytes = Blob.toArray(xOnlyKey);
            D.print("ckSigner:getPublicKey - x-only key: " # bytesToHex(xOnlyBytes));

            // Cache the result
            publicKeyCache.put(ck, xOnlyKey);
            D.print("ckSigner:getPublicKey - cached key for " # ck);

            buildPublicKeyRecord(input.botName, xOnlyBytes);
        } catch (e : Error) {
            D.print("ckSigner:getPublicKey - schnorr_public_key FAILED: " # Error.message(e));
            #Err(#Other("schnorr_public_key failed: " # Error.message(e)));
        };
    };

    // ---------------------------------------------------------------
    // sign - Sign a message with a named bot's key
    // ---------------------------------------------------------------
    public shared (msg) func sign(
        input : Types.SignInput,
    ) : async Types.SignResult {
        D.print("ckSigner:sign - entered with botName=" # input.botName # ", caller=" # Principal.toText(msg.caller));
        if (Principal.isAnonymous(msg.caller)) {
            D.print("ckSigner:sign - rejected anonymous caller");
            return #Err(#Unauthorized);
        };
        // Validate bot name is not empty
        if (Text.size(input.botName) == 0) {
            D.print("ckSigner:sign - empty botName");
            return #Err(#Other("botName cannot be empty"));
        };

        // Validate message is 32 bytes (sighash)
        let messageBytes = Blob.toArray(input.message);
        D.print("ckSigner:sign - message size=" # Nat.toText(messageBytes.size()) # " bytes");
        if (messageBytes.size() != 32) {
            D.print("ckSigner:sign - invalid message size, expected 32 bytes");
            return #Err(#Other("message must be exactly 32 bytes (sighash)"));
        };

        // Fee collection: if fee tokens are configured, payment is required
        switch (input.payment) {
            case (?payment) {
                // Sanity check: verify payment matches a configured fee token
                switch (feeTokens.get(payment.tokenLedger)) {
                    case null {
                        D.print("ckSigner:sign - unknown fee token ledger " # Principal.toText(payment.tokenLedger));
                        return #Err(#Other("Unsupported fee token ledger: " # Principal.toText(payment.tokenLedger) # ". " # buildFeeInfo()));
                    };
                    case (?configured) {
                        if (payment.tokenName != configured.tokenName) {
                            D.print("ckSigner:sign - token name mismatch: expected " # configured.tokenName # ", got " # payment.tokenName);
                            return #Err(#Other("Token name mismatch: expected " # configured.tokenName # ", got " # payment.tokenName # ". " # buildFeeInfo()));
                        };
                        if (payment.amount < configured.fee) {
                            D.print("ckSigner:sign - insufficient payment: expected >= " # Nat.toText(configured.fee) # ", got " # Nat.toText(payment.amount));
                            return #Err(#Other("Insufficient payment amount: expected >= " # Nat.toText(configured.fee) # ", got " # Nat.toText(payment.amount) # ". " # buildFeeInfo()));
                        };
                        D.print("ckSigner:sign - payment sanity check passed for caller " # Principal.toText(msg.caller) # ", token " # payment.tokenName # " (" # Nat.toText(payment.amount) # ")");

                        // Collect fee via ICRC-2 transfer_from
                        let ledger : TokenLedger.TOKEN_LEDGER = actor (Principal.toText(payment.tokenLedger));
                        try {
                            let transferResult = await ledger.icrc2_transfer_from({
                                spender_subaccount = null;
                                from = { owner = msg.caller; subaccount = null };
                                to = { owner = treasury.treasuryPrincipal; subaccount = null };
                                amount = configured.fee;
                                fee = null;
                                memo = null;
                                created_at_time = null;
                            });
                            switch (transferResult) {
                                case (#Ok blockIndex) {
                                    D.print("ckSigner:sign - fee collected from " # Principal.toText(msg.caller) # ", block index " # Nat.toText(blockIndex));
                                };
                                case (#Err transferErr) {
                                    let errMsg = switch (transferErr) {
                                        case (#InsufficientFunds _) "Insufficient funds";
                                        case (#InsufficientAllowance _) "Insufficient allowance. Call icrc2_approve first.";
                                        case (#BadFee _) "Bad fee";
                                        case (#TemporarilyUnavailable) "Ledger temporarily unavailable";
                                        case (_) "Transfer failed";
                                    };
                                    D.print("ckSigner:sign - fee transfer failed for " # Principal.toText(msg.caller) # ": " # errMsg);
                                    return #Err(#Other("Fee payment failed: " # errMsg # ". " # buildFeeInfo()));
                                };
                            };
                        } catch (e : Error) {
                            D.print("ckSigner:sign - fee transfer call failed: " # Error.message(e));
                            return #Err(#Other("Fee payment failed: " # Error.message(e) # ". " # buildFeeInfo()));
                        };
                    };
                };
            };
            case null {
                // No payment provided — check if fees are required
                if (feeTokens.size() > 0) {
                    D.print("ckSigner:sign - fee required but no payment provided");
                    return #Err(#Other("Fee payment required. " # buildFeeInfo()));
                };
            };
        };

        D.print("ckSigner:sign - derivation path: [" # Principal.toText(msg.caller) # ", " # input.botName # "]");

        try {
            D.print("ckSigner:sign - calling sign_with_schnorr with " # Nat.toText(SCHNORR_CYCLES) # " cycles");
            ExperimentalCycles.add<system>(SCHNORR_CYCLES);
            let result = await ic.sign_with_schnorr({
                key_id = {
                    algorithm = #bip340secp256k1;
                    name = schnorrKeyName;
                };
                derivation_path = buildDerivationPath(msg.caller, input.botName);
                message = input.message;
                // BIP341 key-path spend: empty merkle root hash
                // This causes the IC to apply the Taproot tweak
                aux = ?#bip341({ merkle_root_hash = "" });
            });

            let sigBytes = Blob.toArray(result.signature);
            D.print("ckSigner:sign - sign_with_schnorr returned, sig size=" # Nat.toText(sigBytes.size()) # " bytes");
            D.print("ckSigner:sign - signature hex: " # bytesToHex(sigBytes));

            #Ok({
                botName = input.botName;
                signatureHex = bytesToHex(sigBytes);
            });
        } catch (e : Error) {
            D.print("ckSigner:sign - sign_with_schnorr FAILED: " # Error.message(e));
            #Err(#Other("sign_with_schnorr failed: " # Error.message(e)));
        };
    };

    // ---------------------------------------------------------------
    // Upgrade hooks
    // ---------------------------------------------------------------

    system func preupgrade() {
        feeTokensStable := Iter.toArray(feeTokens.entries());
    };

    system func postupgrade() {
        feeTokens := HashMap.fromIter(Iter.fromArray(feeTokensStable), feeTokensStable.size(), Principal.equal, Principal.hash);
        feeTokensStable := [];
    };

};
