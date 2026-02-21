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
import Sha256 "mo:sha2/Sha256";
import Witness "mo:bitcoin/bitcoin/Witness";

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
    // Accepted fee tokens for getPublicKey() and sign(). Supports any ICRC-2 compatible ledger.
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

    // Derive BIP341 tweaked key bytes from x-only public key
    private func deriveTweakedKeyBytes(xOnlyKeyBytes : [Nat8]) : Result.Result<[Nat8], Text> {
        let tweakBytes = Hash.taggedHash(xOnlyKeyBytes, "TapTweak");
        let tweakNat = Common.readBE256(tweakBytes, 0);
        if (tweakNat >= Curves.secp256k1.r) {
            return #err("tweak exceeds curve order");
        };
        let tweak = Curves.secp256k1.Fp(tweakNat);
        switch (tweakPublicKey(xOnlyKeyBytes, tweak)) {
            case (#ok pk) #ok(pk.bip340_public_key);
            case (#err e) #err(e);
        };
    };

    // Derive BIP341 P2TR address from x-only public key (with Taproot tweak)
    private func deriveP2TRAddress(xOnlyKeyBytes : [Nat8]) : Result.Result<Text, Text> {
        let tweakedKey = switch (deriveTweakedKeyBytes(xOnlyKeyBytes)) {
            case (#ok tk) tk;
            case (#err e) return #err(e);
        };
        Segwit.encode("bc", { version = 1 : Nat8; program = tweakedKey });
    };

    // Plain single SHA256 (not double-SHA256)
    private func sha256(data : [Nat8]) : [Nat8] {
        Blob.toArray(Sha256.fromArray(#sha256, data));
    };

    // RFC 4648 Base64 encoding
    private func base64Encode(data : [Nat8]) : Text {
        let alphabet = Iter.toArray("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".chars());
        let n = data.size();
        var result = "";
        var i = 0;
        while (i + 2 < n) {
            let b0 = Nat8.toNat(data[i]);
            let b1 = Nat8.toNat(data[i + 1]);
            let b2 = Nat8.toNat(data[i + 2]);
            result := result
                # Text.fromChar(alphabet[b0 / 4])
                # Text.fromChar(alphabet[(b0 % 4) * 16 + b1 / 16])
                # Text.fromChar(alphabet[(b1 % 16) * 4 + b2 / 64])
                # Text.fromChar(alphabet[b2 % 64]);
            i += 3;
        };
        if (n % 3 == 1) {
            let b0 = Nat8.toNat(data[i]);
            result := result # Text.fromChar(alphabet[b0 / 4])
                # Text.fromChar(alphabet[(b0 % 4) * 16]) # "==";
        } else if (n % 3 == 2) {
            let b0 = Nat8.toNat(data[i]);
            let b1 = Nat8.toNat(data[i + 1]);
            result := result # Text.fromChar(alphabet[b0 / 4])
                # Text.fromChar(alphabet[(b0 % 4) * 16 + b1 / 16])
                # Text.fromChar(alphabet[(b1 % 16) * 4]) # "=";
        };
        result;
    };

    // BIP322 tagged message hash
    private func bip0322Hash(message : Text) : [Nat8] {
        Hash.taggedHash(Blob.toArray(Text.encodeUtf8(message)), "BIP0322-signed-message");
    };

    // Serialize the BIP322 "toSpend" virtual transaction (128 bytes for P2TR)
    //
    // Layout:
    //   version(4) vinCount(1) txid(32) vout(4) scriptSigLen(1) scriptSig(34)
    //   sequence(4) voutCount(1) amount(8) spkLen(1) scriptPubKey(34) locktime(4)
    private func serializeToSpend(msgHash : [Nat8], tweakedKeyBytes : [Nat8]) : [Nat8] {
        let buf : [var Nat8] = Array.init<Nat8>(128, 0);
        var pos = 0;

        // nVersion = 0 (LE32, already 0)
        pos += 4;

        // vinCount = 1
        buf[pos] := 1;
        pos += 1;

        // txid = 32 zero bytes (already 0)
        pos += 32;

        // vout = 0xFFFFFFFF
        buf[pos] := 0xFF; buf[pos + 1] := 0xFF; buf[pos + 2] := 0xFF; buf[pos + 3] := 0xFF;
        pos += 4;

        // scriptSigLen = 34
        buf[pos] := 34;
        pos += 1;

        // scriptSig: OP_0(0x00) PUSH32(0x20) msgHash(32)
        buf[pos] := 0x00;
        buf[pos + 1] := 0x20;
        pos += 2;
        for (j in msgHash.vals()) { buf[pos] := j; pos += 1 };

        // sequence = 0 (already 0)
        pos += 4;

        // voutCount = 1
        buf[pos] := 1;
        pos += 1;

        // amount = 0 (LE64, already 0)
        pos += 8;

        // scriptPubKeyLen = 34
        buf[pos] := 34;
        pos += 1;

        // scriptPubKey: OP_1(0x51) 0x20 tweakedKeyBytes(32)
        buf[pos] := 0x51;
        buf[pos + 1] := 0x20;
        pos += 2;
        for (j in tweakedKeyBytes.vals()) { buf[pos] := j; pos += 1 };

        // locktime = 0 (already 0)
        Array.freeze(buf);
    };

    // BIP341 sighash for the BIP322 "toSign" virtual transaction
    // Custom: Transaction.mo hardcodes nVersion=2; BIP322 needs nVersion=0
    private func computeBip322Sighash(toSpendTxid : [Nat8], tweakedKeyBytes : [Nat8]) : [Nat8] {
        // sha_prevouts = SHA256(txid || LE32(0))
        let prevoutsData : [var Nat8] = Array.init<Nat8>(36, 0);
        var k = 0;
        for (b in toSpendTxid.vals()) { prevoutsData[k] := b; k += 1 };
        let shaPrevouts = sha256(Array.freeze(prevoutsData));

        // sha_amounts = SHA256(LE64(0))
        let shaAmounts = sha256(Array.freeze(Array.init<Nat8>(8, 0)));

        // sha_scriptpubkeys = SHA256(varint(34) || OP_1 || 0x20 || tweakedKey)
        let spkData : [var Nat8] = Array.init<Nat8>(35, 0);
        spkData[0] := 34;   // varint(34)
        spkData[1] := 0x51; // OP_1
        spkData[2] := 0x20; // PUSH32
        k := 3;
        for (b in tweakedKeyBytes.vals()) { spkData[k] := b; k += 1 };
        let shaScriptpubkeys = sha256(Array.freeze(spkData));

        // sha_sequences = SHA256(LE32(0))
        let shaSequences = sha256(Array.freeze(Array.init<Nat8>(4, 0)));

        // sha_outputs = SHA256(LE64(0) || varint(1) || OP_RETURN(0x6a))
        let outputData : [var Nat8] = Array.init<Nat8>(10, 0);
        outputData[8] := 1;    // varint(1)
        outputData[9] := 0x6a; // OP_RETURN
        let shaOutputs = sha256(Array.freeze(outputData));

        // Assemble sighash preimage (175 bytes)
        let preimage : [var Nat8] = Array.init<Nat8>(175, 0);
        // epoch(0x00) + sighash_type(0x00) + nVersion(0) + nLockTime(0) — all 0
        var pos = 10;

        for (b in shaPrevouts.vals()) { preimage[pos] := b; pos += 1 };
        for (b in shaAmounts.vals()) { preimage[pos] := b; pos += 1 };
        for (b in shaScriptpubkeys.vals()) { preimage[pos] := b; pos += 1 };
        for (b in shaSequences.vals()) { preimage[pos] := b; pos += 1 };
        for (b in shaOutputs.vals()) { preimage[pos] := b; pos += 1 };
        // spend_type(0x00) + input_index(LE32(0)) — all 0

        Hash.taggedHash(Array.freeze(preimage), "TapSighash");
    };

    // Build fee info string for self-discovery in error responses
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
        "2) Call the endpoint with payment = record { tokenName; tokenLedger; amount }. " #
        "The canister will transfer_from your account to the " # treasury.treasuryName # ". See also: getFeeTokens().";
    };

    // Collect fee via ICRC-2 transfer_from. Returns null on success, or an ApiError.
    private func collectFee(caller : Principal, payment : ?Types.Payment, endpoint : Text) : async ?Types.ApiError {
        switch (payment) {
            case (?p) {
                switch (feeTokens.get(p.tokenLedger)) {
                    case null {
                        D.print("ckSigner:" # endpoint # " - unknown fee token ledger " # Principal.toText(p.tokenLedger));
                        return ?#Other("Unsupported fee token ledger: " # Principal.toText(p.tokenLedger) # ". " # buildFeeInfo());
                    };
                    case (?configured) {
                        if (p.tokenName != configured.tokenName) {
                            D.print("ckSigner:" # endpoint # " - token name mismatch: expected " # configured.tokenName # ", got " # p.tokenName);
                            return ?#Other("Token name mismatch: expected " # configured.tokenName # ", got " # p.tokenName # ". " # buildFeeInfo());
                        };
                        if (p.amount < configured.fee) {
                            D.print("ckSigner:" # endpoint # " - insufficient payment: expected >= " # Nat.toText(configured.fee) # ", got " # Nat.toText(p.amount));
                            return ?#Other("Insufficient payment amount: expected >= " # Nat.toText(configured.fee) # ", got " # Nat.toText(p.amount) # ". " # buildFeeInfo());
                        };
                        D.print("ckSigner:" # endpoint # " - payment sanity check passed for caller " # Principal.toText(caller) # ", token " # p.tokenName # " (" # Nat.toText(p.amount) # ")");

                        let ledger : TokenLedger.TOKEN_LEDGER = actor (Principal.toText(p.tokenLedger));
                        try {
                            let transferResult = await ledger.icrc2_transfer_from({
                                spender_subaccount = null;
                                from = { owner = caller; subaccount = null };
                                to = { owner = treasury.treasuryPrincipal; subaccount = null };
                                amount = configured.fee;
                                fee = null;
                                memo = null;
                                created_at_time = null;
                            });
                            switch (transferResult) {
                                case (#Ok blockIndex) {
                                    D.print("ckSigner:" # endpoint # " - fee collected from " # Principal.toText(caller) # ", block index " # Nat.toText(blockIndex));
                                };
                                case (#Err transferErr) {
                                    let errMsg = switch (transferErr) {
                                        case (#InsufficientFunds _) "Insufficient funds";
                                        case (#InsufficientAllowance _) "Insufficient allowance. Call icrc2_approve first.";
                                        case (#BadFee _) "Bad fee";
                                        case (#TemporarilyUnavailable) "Ledger temporarily unavailable";
                                        case (_) "Transfer failed";
                                    };
                                    D.print("ckSigner:" # endpoint # " - fee transfer failed for " # Principal.toText(caller) # ": " # errMsg);
                                    return ?#Other("Fee payment failed: " # errMsg # ". " # buildFeeInfo());
                                };
                            };
                        } catch (e : Error) {
                            D.print("ckSigner:" # endpoint # " - fee transfer call failed: " # Error.message(e));
                            return ?#Other("Fee payment failed: " # Error.message(e) # ". " # buildFeeInfo());
                        };
                    };
                };
            };
            case null {
                if (feeTokens.size() > 0) {
                    D.print("ckSigner:" # endpoint # " - fee required but no payment provided");
                    return ?#Other("Fee payment required. " # buildFeeInfo());
                };
            };
        };
        null; // success
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
            usage = "To pay for getPublicKey() or sign(): " #
                "1) Call icrc2_approve on the token ledger with spender=" # Principal.toText(canId) # " and amount >= fee (e.g. 100 sats for ckBTC). " #
                "2) Call the endpoint with payment = record { tokenName; tokenLedger; amount }. " #
                "The canister will transfer_from your account to the " # treasury.treasuryName # " (" # Principal.toText(treasury.treasuryPrincipal) # "). " #
                "Tip: After getPublicKey(), use getPublicKeyQuery() for free cached access.";
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
    // May require fee payment when fee tokens are configured.
    // After first call, use getPublicKeyQuery for free cached access.
    // ---------------------------------------------------------------
    public shared (msg) func getPublicKey(
        input : Types.GetPublicKeyInput,
    ) : async Types.PublicKeyResult {
        D.print("ckSigner:getPublicKey - entered with botName=" # input.botName # ", caller=" # Principal.toText(msg.caller));
        switch (validateGetPublicKeyInput(msg.caller, input.botName)) {
            case (?err) { return #Err(err) };
            case null {};
        };

        // Fee collection (if configured)
        switch (await collectFee(msg.caller, input.payment, "getPublicKey")) {
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

        // Fee collection (if configured)
        switch (await collectFee(msg.caller, input.payment, "sign")) {
            case (?err) { return #Err(err) };
            case null {};
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
    // signBip322 - Produce a BIP322 simple signature for a UTF-8 message
    // ---------------------------------------------------------------
    public shared (msg) func signBip322(
        input : Types.SignBip322Input,
    ) : async Types.Bip322SignResult {
        D.print("ckSigner:signBip322 - entered with botName=" # input.botName # ", caller=" # Principal.toText(msg.caller));

        // Validate caller and botName (reuse existing helper)
        switch (validateGetPublicKeyInput(msg.caller, input.botName)) {
            case (?err) { return #Err(err) };
            case null {};
        };
        if (Text.size(input.message) == 0) {
            D.print("ckSigner:signBip322 - empty message");
            return #Err(#Other("message cannot be empty"));
        };

        // Fee collection (if configured)
        switch (await collectFee(msg.caller, input.payment, "signBip322")) {
            case (?err) { return #Err(err) };
            case null {};
        };

        // Get x-only public key (from cache or management canister)
        let ck = buildCacheKey(msg.caller, input.botName);
        let xOnlyBytes : [Nat8] = switch (publicKeyCache.get(ck)) {
            case (?cachedKey) {
                D.print("ckSigner:signBip322 - cache hit for " # ck);
                Blob.toArray(cachedKey);
            };
            case null {
                D.print("ckSigner:signBip322 - cache miss for " # ck # ", calling management canister");
                try {
                    ExperimentalCycles.add<system>(SCHNORR_CYCLES);
                    let pkResult = await ic.schnorr_public_key({
                        key_id = { algorithm = #bip340secp256k1; name = schnorrKeyName };
                        canister_id = null;
                        derivation_path = buildDerivationPath(msg.caller, input.botName);
                    });
                    let xOnly = extractXOnly(pkResult.public_key);
                    publicKeyCache.put(ck, xOnly);
                    D.print("ckSigner:signBip322 - cached key for " # ck);
                    Blob.toArray(xOnly);
                } catch (e : Error) {
                    D.print("ckSigner:signBip322 - schnorr_public_key FAILED: " # Error.message(e));
                    return #Err(#Other("schnorr_public_key failed: " # Error.message(e)));
                };
            };
        };

        // Compute tweaked key
        let tweakedKeyBytes = switch (deriveTweakedKeyBytes(xOnlyBytes)) {
            case (#ok tk) tk;
            case (#err e) return #Err(#Other("P2TR tweak failed: " # e));
        };

        // BIP322 sighash computation
        let msgHash = bip0322Hash(input.message);
        let toSpendBytes = serializeToSpend(msgHash, tweakedKeyBytes);
        let toSpendTxid = Hash.doubleSHA256(toSpendBytes);
        let sighash = computeBip322Sighash(toSpendTxid, tweakedKeyBytes);

        D.print("ckSigner:signBip322 - sighash: " # bytesToHex(sighash));

        // Sign the sighash
        try {
            ExperimentalCycles.add<system>(SCHNORR_CYCLES);
            let signResult = await ic.sign_with_schnorr({
                key_id = { algorithm = #bip340secp256k1; name = schnorrKeyName };
                derivation_path = buildDerivationPath(msg.caller, input.botName);
                message = Blob.fromArray(sighash);
                aux = ?#bip341({ merkle_root_hash = "" });
            });

            let sigBytes = Blob.toArray(signResult.signature);
            D.print("ckSigner:signBip322 - signature: " # bytesToHex(sigBytes));

            // Encode witness: [signature_bytes]
            let witnessBytes = Witness.toBytes([sigBytes]);
            let witnessB64 = base64Encode(witnessBytes);

            // Derive address
            let address = switch (Segwit.encode("bc", { version = 1 : Nat8; program = tweakedKeyBytes })) {
                case (#ok addr) addr;
                case (#err e) return #Err(#Other("P2TR address encoding failed: " # e));
            };

            #Ok({
                botName = input.botName;
                signatureHex = bytesToHex(sigBytes);
                witnessB64 = witnessB64;
                address = address;
            });
        } catch (e : Error) {
            D.print("ckSigner:signBip322 - sign_with_schnorr FAILED: " # Error.message(e));
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
