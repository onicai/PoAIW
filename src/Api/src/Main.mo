import Principal "mo:base/Principal";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Time "mo:base/Time";
import Float "mo:base/Float";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Nat64 "mo:base/Nat64";
import Timer "mo:base/Timer";
import List "mo:base/List";
import D "mo:base/Debug";
import Error "mo:base/Error";
import Cycles "mo:base/ExperimentalCycles";

import Types "../../common/Types";
import ICManagementCanister "../../common/ICManagementCanister";
import Util "Utils";
import { migration } "Migration";

(with migration)
persistent actor class ApiCanister() = this {

    var MASTER_CANISTER_ID : Text = "r5m5y-diaaa-aaaaa-qanaa-cai"; // Corresponds to prd Game State canister

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
    // ShareService canister ID — defaults to prd ShareService (mainer_service_canister
    // entry from PoAIW/src/mAIner/canister_ids.json). Non-prd networks override via
    // setShareServiceCanisterIdAdmin after deploy.

    var SHARE_SERVICE_CANISTER_ID : Text = "rilmv-caaaa-aaaaa-qandq-cai";

    public shared (msg) func setShareServiceCanisterIdAdmin(newShareServiceCanisterId : Text) : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        SHARE_SERVICE_CANISTER_ID := newShareServiceCanisterId;
        let authRecord = { auth = "You set the ShareService canister id for this canister to: " # SHARE_SERVICE_CANISTER_ID };
        return #Ok(authRecord);
    };

    public query (msg) func getShareServiceCanisterIdAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not hasAdminRole(msg.caller, #AdminQuery)) {
            return #Err(#Unauthorized);
        };
        let authRecord = { auth = "ShareService canister id for this canister: " # SHARE_SERVICE_CANISTER_ID };
        return #Ok(authRecord);
    };

    // -------------------------------------------------------------------------------
    // Daily burn-rate tier constants (cycles per day per ShareAgent in that tier).
    // Mirror the defaults defined on GameState. Hardcoded so the daily aggregation
    // doesn't need a cross-canister fetch; if GameState ever changes its tier
    // values, this canister must be upgraded.

    let BURN_RATE_LOW_CYCLES : Nat = 1_000_000_000_000;
    let BURN_RATE_MID_CYCLES : Nat = 2_000_000_000_000;
    let BURN_RATE_HIGH_CYCLES : Nat = 4_000_000_000_000;
    let BURN_RATE_VERY_HIGH_CYCLES : Nat = 6_000_000_000_000;

    // -------------------------------------------------------------------------------
    // Pricing cache (refreshed by HTTPS outcalls; consumed by daily metrics aggregator)
    //
    // Two values feed the FunnAI index + USD reporting:
    //   - usdPerComputedXdr: USD value of 1 trillion cycles (= 1 Computed XDR).
    //     Derived from Coinbase USD/ICP + CMC XDR/ICP.
    //   - icApiTcycleBurnRatePerDay: IC-wide tcycle burn rate per day.
    //     Pulled from https://ic-api.internetcomputer.org cycle-burn-rate endpoint.
    //
    // Outcalls run on a separate hourly timer; the cache survives upgrades so a
    // single failed refresh doesn't blank pricing on the next metric write.

    transient let IC0 : ICManagementCanister.IC_Management = actor("aaaaa-aa");

    // Seeded with placeholder defaults so a freshly-deployed canister has usable
    // pricing immediately. Replaced by the first successful refreshPricingCache
    // run via the hourly timer. The default xdrPermyriadPerIcp of 30_000
    // (≈ 3 XDR/ICP) is in the ballpark of mainnet on May 2026.
    var pricingCache : ?Types.PricingCache = ?{
        xdrPermyriadPerIcp = 30_000 : Nat64;
        usdPerComputedXdr = 1.5;
        icApiTcycleBurnRatePerDay = 42.5;
        lastUpdatedNs = 0 : Nat64;
    };

    public query (msg) func getPricingCacheAdmin() : async Types.PricingCacheResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not hasAdminRole(msg.caller, #AdminQuery)) { return #Err(#Unauthorized); };
        switch (pricingCache) {
            case (?p) { #Ok(p) };
            case null { #Err(#Other("Pricing cache is empty")) };
        };
    };

    // Transform function for HTTPS outcalls. Strips response headers so all
    // subnet replicas agree on body+status only. Invoked by the management
    // canister as part of processing http_request — NOT a self-call — so no
    // caller assertion is possible. The function is a pure deterministic
    // transformation of its input; calling it from outside the outcall flow
    // costs the canister nothing meaningful beyond standard query overhead.
    public query func pricingTransform(args : { context : Blob; response : ICManagementCanister.http_request_result }) : async ICManagementCanister.http_request_result {
        { status = args.response.status; body = args.response.body; headers = [] }
    };

    // Walk the body looking for `"<key>":"<value>"` and return the value, or null
    // when the key is absent or the value isn't string-quoted. Sufficient for the
    // Coinbase exchange-rates endpoint.
    private func extractQuotedValue(body : Text, key : Text) : ?Text {
        let parts = Iter.toArray(Text.split(body, #text "\""));
        var i : Nat = 0;
        while (i + 2 < parts.size()) {
            if (parts[i] == key) {
                return ?parts[i + 2];
            };
            i += 1;
        };
        null
    };

    // Issue a GET, returning the body as Text on HTTP 200 or null otherwise.
    // 100B cycles attached covers a typical IC application subnet HTTPS outcall.
    private func httpGet(url : Text, maxBytes : Nat64) : async ?Text {
        let request : ICManagementCanister.http_request_args = {
            url = url;
            method = #get;
            body = null;
            max_response_bytes = ?maxBytes;
            transform = ?{
                function = pricingTransform;
                context = Blob.fromArray([]);
            };
            headers = [];
        };
        Cycles.add<system>(100_000_000_000);
        let response = try {
            await IC0.http_request(request);
        } catch (e) {
            D.print("Api: httpGet - http_request threw for " # url # ": " # Error.message(e));
            return null;
        };
        if (response.status != 200) {
            D.print("Api: httpGet - non-200 status " # Nat.toText(response.status) # " for " # url);
            return null;
        };
        Text.decodeUtf8(response.body)
    };

    // Refresh the pricing cache:
    //   1. CMC inter-canister call for xdr_permyriad_per_icp → cycles per ICP.
    //   2. Coinbase HTTPS outcall for USD/ICP.
    //   3. Derive USD per Computed XDR.
    //   4. IC API HTTPS outcall for protocol-wide cycle burn rate → Tcycles/day.
    private func refreshPricingCache() : async Bool {
        D.print("Api: refreshPricingCache - starting");

        // Each upstream is refreshed independently: when one fails, the prior
        // value carries forward. Coinbase is the brittle one — its failure must
        // not block CMC / IC API updates.
        let prior : Types.PricingCache = switch (pricingCache) {
            case (?c) { c };
            case null {
                D.print("Api: refreshPricingCache - pricingCache is null, aborting");
                return false;
            };
        };

        // 1. CMC inter-canister call. On failure, keep prior xdrPermyriadPerIcp.
        D.print("Api: refreshPricingCache - calling CMC get_icp_xdr_conversion_rate");
        let xdrPermyriad : Nat64 = try {
            let cmcResponse = await Types.CyclesMintingCanister_Actor.get_icp_xdr_conversion_rate();
            D.print("Api: refreshPricingCache - CMC returned, xdr_permyriad_per_icp=" # Nat64.toText(cmcResponse.data.xdr_permyriad_per_icp));
            cmcResponse.data.xdr_permyriad_per_icp
        } catch (e) {
            D.print("Api: refreshPricingCache - CMC call failed: " # Error.message(e) # "; keeping previous xdrPermyriadPerIcp");
            prior.xdrPermyriadPerIcp
        };

        // 2. Coinbase USD/ICP via HTTPS outcall. Brittle — on any failure path
        //    (throw, http error, parse failure) keep the prior usdPerComputedXdr.
        D.print("Api: refreshPricingCache - calling Coinbase HTTPS outcall");
        let coinbaseBody : ?Text = try {
            await httpGet("https://api.coinbase.com/v2/exchange-rates?currency=ICP", 65_536);
        } catch (e) {
            D.print("Api: refreshPricingCache - Coinbase outcall threw: " # Error.message(e));
            null
        };
        D.print("Api: refreshPricingCache - Coinbase outcall returned " # (if (Option.isSome(coinbaseBody)) "body" else "null"));
        let usdPerComputedXdr : Float = switch (coinbaseBody) {
            case (?body) {
                switch (extractQuotedValue(body, "USD")) {
                    case (?valueText) {
                        switch (parseFloat(valueText)) {
                            case (?v) {
                                // 1 ICP = (xdr_permyriad_per_icp / 10000) XDR. 1 Computed XDR = 1T cycles.
                                // cycles_per_icp = xdr_permyriad_per_icp / 10000 * 1e12.
                                let xdrPermyriadFloat : Float = Float.fromInt(Nat64.toNat(xdrPermyriad));
                                let cyclesPerIcp : Float = xdrPermyriadFloat * 1_000_000_000_000.0 / 10_000.0;
                                v / (cyclesPerIcp / 1_000_000_000_000.0)
                            };
                            case null {
                                D.print("Api: refreshPricingCache - failed to parse Coinbase USD value '" # valueText # "'; keeping previous usdPerComputedXdr");
                                prior.usdPerComputedXdr
                            };
                        };
                    };
                    case null {
                        D.print("Api: refreshPricingCache - Coinbase response missing 'USD' field; keeping previous usdPerComputedXdr");
                        prior.usdPerComputedXdr
                    };
                };
            };
            case null {
                D.print("Api: refreshPricingCache - Coinbase body unavailable; keeping previous usdPerComputedXdr");
                prior.usdPerComputedXdr
            };
        };

        // 3. IC API protocol-wide cycle burn rate via HTTPS outcall. On any
        //    failure path keep the prior icApiTcycleBurnRatePerDay.
        D.print("Api: refreshPricingCache - calling IC API HTTPS outcall");
        let icApiBody : ?Text = try {
            await httpGet("https://ic-api.internetcomputer.org/api/v3/metrics/cycle-burn-rate", 65_536);
        } catch (e) {
            D.print("Api: refreshPricingCache - IC API outcall threw: " # Error.message(e));
            null
        };
        D.print("Api: refreshPricingCache - IC API outcall returned " # (if (Option.isSome(icApiBody)) "body" else "null"));
        let icApiTcycleBurnRatePerDay : Float = switch (icApiBody) {
            case (?body) {
                switch (extractQuotedValue(body, "cycle_burn_rate")) {
                    case (?valueText) {
                        switch (parseFloat(valueText)) {
                            case (?v) { v * 86_400.0 / 1_000_000_000_000.0 };
                            case null {
                                D.print("Api: refreshPricingCache - failed to parse IC API value '" # valueText # "'; keeping previous icApiTcycleBurnRatePerDay");
                                prior.icApiTcycleBurnRatePerDay
                            };
                        };
                    };
                    case null {
                        D.print("Api: refreshPricingCache - 'cycle_burn_rate' not found in IC API body; keeping previous icApiTcycleBurnRatePerDay");
                        prior.icApiTcycleBurnRatePerDay
                    };
                };
            };
            case null {
                D.print("Api: refreshPricingCache - IC API body unavailable; keeping previous icApiTcycleBurnRatePerDay");
                prior.icApiTcycleBurnRatePerDay
            };
        };

        pricingCache := ?{
            xdrPermyriadPerIcp = xdrPermyriad;
            usdPerComputedXdr = usdPerComputedXdr;
            icApiTcycleBurnRatePerDay = icApiTcycleBurnRatePerDay;
            lastUpdatedNs = Nat64.fromNat(Int.abs(Time.now()));
        };
        D.print("Api: refreshPricingCache - cache updated (usdPerComputedXdr=" # Float.toText(usdPerComputedXdr) # ", icApiTcycleBurnRatePerDay=" # Float.toText(icApiTcycleBurnRatePerDay) # ")");
        true
    };

    // Hourly recurring pricing-refresh timer. Disabled by default; start via admin.
    transient var pricingTimerId : ?Timer.TimerId = null;
    var pricingTimerIntervalSeconds : Nat = 3600;

    public shared (msg) func startPricingTimerAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        switch (pricingTimerId) {
            case (?id) { Timer.cancelTimer(id); pricingTimerId := null; };
            case null {};
        };
        // Fire once immediately so the cache is fresh before the first
        // interval-tick — otherwise we'd run on seeded defaults for an hour.
        try {
            let _ = await refreshPricingCache();
        } catch (e) {
            D.print("Api: startPricingTimerAdmin - initial refreshPricingCache threw: " # Error.message(e));
        };
        let id = Timer.recurringTimer<system>(#seconds pricingTimerIntervalSeconds, func () : async () {
            try {
                let _ = await refreshPricingCache();
            } catch (e) {
                D.print("Api: pricingTimer - refreshPricingCache threw: " # Error.message(e));
            };
        });
        pricingTimerId := ?id;
        return #Ok({ auth = "Pricing refresh timer started." });
    };

    public shared (msg) func stopPricingTimerAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        switch (pricingTimerId) {
            case (?id) { Timer.cancelTimer(id); pricingTimerId := null; };
            case null {};
        };
        return #Ok({ auth = "Pricing refresh timer stopped." });
    };

    private func parseFloat(s : Text) : ?Float {
        // mo:base has no Float parser, so digit-walk by hand. Accepts an optional
        // leading '-', decimal digits, optional '.', a fractional part, and an
        // optional exponent ('e'/'E' followed by an optional '+'/'-' and digits).
        // Anything else returns null after emitting a debug log identifying the
        // input and the reason — useful for spotting upstream API format changes.
        func logFail(reason : Text) {
            D.print("Api: parseFloat - failed to parse '" # s # "': " # reason);
        };

        var seenDot = false;
        var negative = false;
        var intPart : Float = 0.0;
        var fracPart : Float = 0.0;
        var fracScale : Float = 1.0;
        var anyDigit = false;
        var first = true;

        var inExponent = false;
        var expFirst = true;
        var expNegative = false;
        var expValue : Int = 0;
        var anyExpDigit = false;

        for (c in s.chars()) {
            if (inExponent) {
                if (expFirst and (c == '+' or c == '-')) {
                    if (c == '-') { expNegative := true; };
                    expFirst := false;
                } else {
                    expFirst := false;
                    if (c >= '0' and c <= '9') {
                        let digit : Int = Nat32.toNat(Char.toNat32(c) - 48);
                        anyExpDigit := true;
                        expValue := expValue * 10 + digit;
                    } else {
                        logFail("non-digit '" # Text.fromChar(c) # "' in exponent");
                        return null;
                    };
                };
            } else if (first and c == '-') {
                negative := true;
                first := false;
            } else {
                first := false;
                if (c == '.') {
                    if (seenDot) {
                        logFail("second '.' in mantissa");
                        return null;
                    };
                    seenDot := true;
                } else if (c == 'e' or c == 'E') {
                    if (not anyDigit) {
                        logFail("exponent marker '" # Text.fromChar(c) # "' before any digit");
                        return null;
                    };
                    inExponent := true;
                } else if (c >= '0' and c <= '9') {
                    let codePoint : Nat32 = Char.toNat32(c);
                    let digit : Float = Float.fromInt(Nat32.toNat(codePoint - 48));
                    anyDigit := true;
                    if (seenDot) {
                        fracScale *= 10.0;
                        fracPart := fracPart * 10.0 + digit;
                    } else {
                        intPart := intPart * 10.0 + digit;
                    };
                } else {
                    logFail("unexpected character '" # Text.fromChar(c) # "' in mantissa");
                    return null;
                };
            };
        };
        if (not anyDigit) {
            logFail("no digits in input");
            return null;
        };
        if (inExponent and not anyExpDigit) {
            logFail("exponent marker with no digits");
            return null;
        };

        let mantissa = intPart + (fracPart / fracScale);
        var v = if (negative) { -mantissa } else { mantissa };
        if (inExponent) {
            let exp : Int = if (expNegative) { -expValue } else { expValue };
            v := v * Float.pow(10.0, Float.fromInt(exp));
        };
        ?v
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
    var dailyMetricsEntries : [(Text, Types.DailyMetric)] = [];
    transient var dailyMetrics = HashMap.HashMap<Text, Types.DailyMetric>(10, Text.equal, Text.hash);

    //-------------------------------------------------------------------------
    // Admin RBAC Storage
    //-------------------------------------------------------------------------
    var adminRoleAssignmentsStable : [(Text, Types.AdminRoleAssignment)] = [];
    transient var adminRoleAssignmentsStorage : HashMap.HashMap<Text, Types.AdminRoleAssignment> = HashMap.HashMap(0, Text.equal, Text.hash);

    private func putAdminRole(principal : Text, assignment : Types.AdminRoleAssignment) : Bool {
        adminRoleAssignmentsStorage.put(principal, assignment);
        return true;
    };

    private func getAdminRole(principal : Text) : ?Types.AdminRoleAssignment {
        switch (adminRoleAssignmentsStorage.get(principal)) {
            case (null) { return null; };
            case (?assignment) { return ?assignment; };
        };
    };

    private func removeAdminRole(principal : Text) : Bool {
        switch (adminRoleAssignmentsStorage.get(principal)) {
            case (null) { return false; };
            case (?assignment) {
                let removeResult = adminRoleAssignmentsStorage.remove(principal);
                return true;
            };
        };
    };

    private func getAllAdminRoles() : [Types.AdminRoleAssignment] {
        let assignments : Iter.Iter<Types.AdminRoleAssignment> = adminRoleAssignmentsStorage.vals();
        return Iter.toArray(assignments);
    };

    // Helper function to check admin permissions
    private func hasAdminRole(principal : Principal, requiredRole : Types.AdminRole) : Bool {
        // Controllers automatically have all permissions
        if (Principal.isController(principal)) {
            return true;
        };

        // Check for assigned role
        let principalText = Principal.toText(principal);
        switch (getAdminRole(principalText)) {
            case (null) { return false; };
            case (?assignment) {
                switch (assignment.role, requiredRole) {
                    // AdminUpdate includes AdminQuery
                    case (#AdminUpdate, #AdminQuery) { true };
                    case (#AdminUpdate, #AdminUpdate) { true };
                    // AdminQuery only has query permissions
                    case (#AdminQuery, #AdminQuery) { true };
                    // All other combinations fail
                    case _ { false };
                };
            };
        };
    };

    //-------------------------------------------------------------------------

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
                quarter = "Q3 2025";
                total_minted = 0.0;
                rewards_per_challenge = 181.9032733;
                rewards_per_quarter = 2390209.011;
                notes = "";
            },
            {
                date = "2025-09-29";
                quarter = "Q4 2025";
                total_minted = 2390209.011;
                rewards_per_challenge = 139.9194939;
                rewards_per_quarter = 1838542.15;
                notes = "";
            },
            {
                date = "2025-12-29";
                quarter = "Q1 2026";
                total_minted = 4228751.161;
                rewards_per_challenge = 109.9310802;
                rewards_per_quarter = 1444494.393;
                notes = "";
            },
            {
                date = "2026-03-29";
                quarter = "Q2 2026";
                total_minted = 5673245.554;
                rewards_per_challenge = 88.51078458;
                rewards_per_quarter = 1163031.71;
                notes = "";
            },
            {
                date = "2026-06-29";
                quarter = "Q3 2026";
                total_minted = 6836277.264;
                rewards_per_challenge = 73.21057346;
                rewards_per_quarter = 961986.935;
                notes = "";
            },
            {
                date = "2026-09-29";
                quarter = "Q4 2026";
                total_minted = 7798264.199;
                rewards_per_challenge = 62.28185123;
                rewards_per_quarter = 818383.525;
                notes = "";
            },
            {
                date = "2026-12-29";
                quarter = "Q1 2027";
                total_minted = 8616647.724;
                rewards_per_challenge = 54.47562107;
                rewards_per_quarter = 715809.661;
                notes = "";
            },
            {
                date = "2027-03-29";
                quarter = "Q2 2027";
                total_minted = 9332457.385;
                rewards_per_challenge = 48.89974238;
                rewards_per_quarter = 642542.615;
                notes = "";
            },
            {
                date = "2027-06-29";
                quarter = "Q3 2027";
                total_minted = 9975000.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "Rewards per challenge stabilized at 34.96004566 from this date onward until max supply is reached";
            },
            {
                date = "2027-09-29";
                quarter = "Q4 2027";
                total_minted = 10434375.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2027-12-29";
                quarter = "Q1 2028";
                total_minted = 10893750.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2028-03-29";
                quarter = "Q2 2028";
                total_minted = 11353125.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2028-06-29";
                quarter = "Q3 2028";
                total_minted = 11812500.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2028-09-29";
                quarter = "Q4 2028";
                total_minted = 12271875.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2028-12-29";
                quarter = "Q1 2029";
                total_minted = 12731250.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2029-03-29";
                quarter = "Q2 2029";
                total_minted = 13190625.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2029-06-29";
                quarter = "Q3 2029";
                total_minted = 13650000.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2029-09-29";
                quarter = "Q4 2029";
                total_minted = 14109375.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2029-12-29";
                quarter = "Q1 2030";
                total_minted = 14568750.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2030-03-29";
                quarter = "Q2 2030";
                total_minted = 15028125.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2030-06-29";
                quarter = "Q3 2030";
                total_minted = 15487500.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2030-09-29";
                quarter = "Q4 2030";
                total_minted = 15946875.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2030-12-29";
                quarter = "Q1 2031";
                total_minted = 16406250.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2031-03-29";
                quarter = "Q2 2031";
                total_minted = 16865625.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2031-06-29";
                quarter = "Q3 2031";
                total_minted = 17325000.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2031-09-29";
                quarter = "Q4 2031";
                total_minted = 17784375.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2031-12-29";
                quarter = "Q1 2032";
                total_minted = 18243750.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2032-03-29";
                quarter = "Q2 2032";
                total_minted = 18703125.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2032-06-29";
                quarter = "Q3 2032";
                total_minted = 19162500.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2032-09-29";
                quarter = "Q4 2032";
                total_minted = 19621875.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2032-12-29";
                quarter = "Q1 2033";
                total_minted = 20081250.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2033-03-29";
                quarter = "Q2 2033";
                total_minted = 20540625.0;
                rewards_per_challenge = 34.96004566;
                rewards_per_quarter = 459375.0;
                notes = "";
            },
            {
                date = "2033-06-29";
                quarter = "Q3 2033";
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
                total_cycles = switch (input.total_cycles_all, input.total_cycles_all_usd,
                                       input.total_cycles_protocol, input.total_cycles_protocol_usd,
                                       input.total_cycles_mainers_usd) {
                    case (?all, ?allUsd, ?protocol, ?protocolUsd, ?mainersUsd) {
                        ?{
                            all = { cycles = all; usd = allUsd };
                            protocol = { cycles = protocol; usd = protocolUsd };
                            mainers = { cycles = input.total_cycles_all_mainers; usd = mainersUsd };
                        }
                    };
                    case (_, _, _, _, _) { null };
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
    // Admin RBAC Management Endpoints
    // -------------------------------------------------------------------------------

    // Add an admin role assignment (controller-only)
    public shared(msg) func assignAdminRole(input : Types.AssignAdminRoleInputRecord) : async Types.AdminRoleAssignmentResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let assignment : Types.AdminRoleAssignment = {
            principal = input.principal;
            role = input.role;
            assignedBy = Principal.toText(msg.caller);
            assignedAt = Nat64.fromNat(Int.abs(Time.now()));
            note = input.note;
        };

        // Store the assignment (replaces any existing assignment for this principal)
        let _ = putAdminRole(input.principal, assignment);

        #Ok(assignment)
    };

    // Remove an admin role assignment (controller-only)
    public shared(msg) func revokeAdminRole(principal: Text) : async Types.TextResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let removed = removeAdminRole(principal);
        if (removed) {
            #Ok("Admin role revoked for principal: " # principal)
        } else {
            #Err(#Other("No admin role found for principal: " # principal))
        }
    };

    // Get all admin role assignments (controller-only)
    public shared query(msg) func getAdminRoles() : async Types.AdminRoleAssignmentsResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        #Ok(getAllAdminRoles())
    };

    // -------------------------------------------------------------------------------
    // Admin CRUD Endpoints

    // Fill pricing-derived fields (funnai_index, *_usd) from the pricing cache
    // when the caller has left them at their zero/null default. Cache misses leave
    // those fields as-is; a future write (manual or from the next timer tick) can
    // patch them via updateDailyMetricAdmin's merge-on-update semantic.
    private func enrichWithPricing(input : Types.DailyMetricInput) : Types.DailyMetricInput {
        switch (pricingCache) {
            case null { input };
            case (?cache) {
                let cyclesFloat = Float.fromInt(input.daily_burn_rate_cycles);
                let usd = if (input.daily_burn_rate_usd == 0.0 and input.daily_burn_rate_cycles > 0) {
                    cyclesFloat * cache.usdPerComputedXdr
                } else { input.daily_burn_rate_usd };
                let index = if (input.funnai_index == 0.0 and cache.icApiTcycleBurnRatePerDay > 0.0) {
                    let raw = 0.9 * cyclesFloat / cache.icApiTcycleBurnRatePerDay;
                    if (raw < 0.0) { 0.0 } else if (raw > 100.0) { 100.0 } else { raw }
                } else { input.funnai_index };
                let mainersUsd = switch (input.total_cycles_mainers_usd) {
                    case (?v) { ?v };
                    case null {
                        if (cache.usdPerComputedXdr > 0.0) {
                            ?(Float.fromInt(input.total_cycles_all_mainers) * cache.usdPerComputedXdr)
                        } else { null };
                    };
                };
                let allUsd = switch (input.total_cycles_all_usd) {
                    case (?v) { ?v };
                    case null {
                        if (cache.usdPerComputedXdr > 0.0) {
                            let cyclesAll = switch (input.total_cycles_all) {
                                case (?n) { Float.fromInt(n) };
                                case null { Float.fromInt(input.total_cycles_all_mainers) };
                            };
                            ?(cyclesAll * cache.usdPerComputedXdr)
                        } else { null };
                    };
                };
                {
                    input with
                    daily_burn_rate_usd = usd;
                    funnai_index = index;
                    total_cycles_mainers_usd = mainersUsd;
                    total_cycles_all_usd = allUsd;
                }
            };
        };
    };

    // Internal create-or-replace used by both the admin endpoint and the on-chain
    // daily-metrics timer. Validates the date format, enriches missing pricing
    // fields from the cache, and writes the metric.
    // Validate + enrich + convert; no storage write. Reusable by both the
    // "store" path and the "preview" admin endpoint.
    private func computeDailyMetric(input: Types.DailyMetricInput) : Types.DailyMetricResult {
        if (not isValidDateFormat(input.date)) {
            return #Err(#Other("Invalid date format. Use YYYY-MM-DD"));
        };
        let enriched = enrichWithPricing(input);
        #Ok(inputToDailyMetric(enriched, false))
    };

    private func storeDailyMetric(input: Types.DailyMetricInput) : Types.DailyMetricResult {
        switch (computeDailyMetric(input)) {
            case (#Err(e)) { #Err(e) };
            case (#Ok(metric)) {
                dailyMetrics.put(metric.metadata.date, metric);
                #Ok(metric)
            };
        };
    };

    public shared (msg) func createDailyMetricAdmin(input: Types.DailyMetricInput) : async Types.DailyMetricResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // Check if caller has AdminUpdate permission
        if (not hasAdminRole(msg.caller, #AdminUpdate)) {
            return #Err(#Unauthorized);
        };
        return storeDailyMetric(input);
    };

    public shared (msg) func updateDailyMetricAdmin(params: Types.UpdateDailyMetricAdminInput) : async Types.DailyMetricResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not hasAdminRole(msg.caller, #AdminUpdate)) {
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
                // Extract existing total_cycles values (if present)
                // Now TotalCycles contains CycleAmount records with .cycles and .usd fields
                let existingTotalCyclesAll : ?Nat = switch (existing.system_metrics.total_cycles) {
                    case (?tc) { ?tc.all.cycles };
                    case null { null };
                };
                let existingTotalCyclesAllUsd : ?Float = switch (existing.system_metrics.total_cycles) {
                    case (?tc) { ?tc.all.usd };
                    case null { null };
                };
                let existingTotalCyclesProtocol : ?Nat = switch (existing.system_metrics.total_cycles) {
                    case (?tc) { ?tc.protocol.cycles };
                    case null { null };
                };
                let existingTotalCyclesProtocolUsd : ?Float = switch (existing.system_metrics.total_cycles) {
                    case (?tc) { ?tc.protocol.usd };
                    case null { null };
                };
                let existingTotalCyclesMainersUsd : ?Float = switch (existing.system_metrics.total_cycles) {
                    case (?tc) { ?tc.mainers.usd };
                    case null { null };
                };

                // Merge input with existing: prefer input if provided, else keep existing
                let mergedTotalCyclesAll : ?Nat = switch (params.input.total_cycles_all) {
                    case (?val) { ?val };
                    case null { existingTotalCyclesAll };
                };
                let mergedTotalCyclesAllUsd : ?Float = switch (params.input.total_cycles_all_usd) {
                    case (?val) { ?val };
                    case null { existingTotalCyclesAllUsd };
                };
                let mergedTotalCyclesProtocol : ?Nat = switch (params.input.total_cycles_protocol) {
                    case (?val) { ?val };
                    case null { existingTotalCyclesProtocol };
                };
                let mergedTotalCyclesProtocolUsd : ?Float = switch (params.input.total_cycles_protocol_usd) {
                    case (?val) { ?val };
                    case null { existingTotalCyclesProtocolUsd };
                };
                let mergedTotalCyclesMainersUsd : ?Float = switch (params.input.total_cycles_mainers_usd) {
                    case (?val) { ?val };
                    case null { existingTotalCyclesMainersUsd };
                };

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
                    total_cycles_all = mergedTotalCyclesAll;
                    total_cycles_all_usd = mergedTotalCyclesAllUsd;
                    total_cycles_protocol = mergedTotalCyclesProtocol;
                    total_cycles_protocol_usd = mergedTotalCyclesProtocolUsd;
                    total_cycles_mainers_usd = mergedTotalCyclesMainersUsd;
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
        if (not hasAdminRole(msg.caller, #AdminUpdate)) {
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
        if (not hasAdminRole(msg.caller, #AdminQuery)) {
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
        if (not hasAdminRole(msg.caller, #AdminUpdate)) {
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
    // Daily Metrics On-Chain Aggregation
    //
    //   1. ShareAgents send burn-rate + cycle balance to ShareService on every
    //      addChallengeToShareServiceQueue call (heartbeat).
    //   2. ShareService caches the latest heartbeat per agent in shareAgentActivityStorage.
    //   3. The Api canister (this canister) runs a 24h timer anchored to 00:00 UTC.
    //   4. On each fire we call ShareService.getShareAgentRegistryWithActivityAdmin,
    //      bucket active/paused × tier using a 25h staleness cutoff, enrich with
    //      pricing from the local cache, and store yesterday's DailyMetric.
    // -------------------------------------------------------------------------------

    transient var dailyMetricsTimerId : ?Timer.TimerId = null;
    var lastSuccessfulMetricDate : ?Text = null;
    var lastDailyMetricsFailure : ?Text = null;

    // 25-hour staleness window (in ns): a ShareAgent that hasn't called
    // addChallengeToShareServiceQueue within this window is bucketed as paused
    // and excluded from total_cycles_all_mainers.
    let STALENESS_CUTOFF_NS : Nat64 = 25 * 3600 * 1_000_000_000;
    let ONE_DAY_SECONDS : Nat = 86_400;
    let ONE_DAY_NS : Int = 86_400 * 1_000_000_000;

    // Snapshot of last aggregation result, exposed for monitoring.
    public type DailyMetricsRunStatus = {
        lastSuccessfulMetricDate : ?Text;
        lastFailureMessage : ?Text;
        timerActive : Bool;
    };
    public query (msg) func getDailyMetricsRunStatusAdmin() : async Types.Result<DailyMetricsRunStatus, Types.ApiError> {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not hasAdminRole(msg.caller, #AdminQuery)) { return #Err(#Unauthorized); };
        #Ok({
            lastSuccessfulMetricDate = lastSuccessfulMetricDate;
            lastFailureMessage = lastDailyMetricsFailure;
            timerActive = Option.isSome(dailyMetricsTimerId);
        })
    };

    public shared (msg) func startDailyMetricsTimerAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        switch (dailyMetricsTimerId) {
            case (?id) { Timer.cancelTimer(id); dailyMetricsTimerId := null; };
            case null {};
        };
        let nowNs : Int = Time.now();
        let nowSeconds : Int = nowNs / 1_000_000_000;
        let oneDaySecondsInt : Int = ONE_DAY_SECONDS;
        let secondsIntoDay : Int = nowSeconds % oneDaySecondsInt;
        let secondsUntilNextMidnight : Nat = Int.abs(oneDaySecondsInt - secondsIntoDay);
        // Initial setTimer to the next 00:00 UTC; on first fire we kick off the
        // 24h recurring timer so subsequent runs stay phase-locked.
        let _ = Timer.setTimer<system>(#seconds secondsUntilNextMidnight, func () : async () {
            try {
                let _ = await triggerDailyMetricsAggregation();
            } catch (e) {
                D.print("Api: dailyMetricsTimer (initial) - triggerDailyMetricsAggregation threw: " # Error.message(e));
            };
            let recurringId = Timer.recurringTimer<system>(#seconds ONE_DAY_SECONDS, func () : async () {
                try {
                    let _ = await triggerDailyMetricsAggregation();
                } catch (e) {
                    D.print("Api: dailyMetricsTimer (recurring) - triggerDailyMetricsAggregation threw: " # Error.message(e));
                };
            });
            dailyMetricsTimerId := ?recurringId;
        });
        return #Ok({ auth = "Daily metrics timer scheduled — first fire at next 00:00 UTC." });
    };

    public shared (msg) func stopDailyMetricsTimerAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        switch (dailyMetricsTimerId) {
            case (?id) { Timer.cancelTimer(id); dailyMetricsTimerId := null; };
            case null {};
        };
        return #Ok({ auth = "Daily metrics timer stopped." });
    };

    // Translate a CyclesBurnRateDefault into one of (low, mid, high, very_high,
    // custom). `custom` carries the per-day cycles for that agent so the
    // aggregator can sum them into customBurnRateTotal.
    private type TierBucket = { #Low; #Mid; #High; #VeryHigh; #Custom : Nat };

    private func classifyBurnRate(rate : Types.CyclesBurnRateDefault) : TierBucket {
        switch (rate) {
            case (#Low) { #Low };
            case (#Mid) { #Mid };
            case (#High) { #High };
            case (#VeryHigh) { #VeryHigh };
            case (#Custom(custom)) {
                // Only #Daily is currently defined in TimeInterval; treat anything
                // else as "no contribution to daily burn-rate total" while still
                // counting the agent toward custom-tier counts.
                switch (custom.timeInterval) {
                    case (#Daily) { #Custom(custom.cycles) };
                };
            };
        };
    };

    // Snapshot of aggregation state, used both by the timer and by a debug-only
    // controller-callable variant for tests.
    private func aggregateFromSnapshot(snapshot : Types.ShareAgentRegistryWithActivity) : Types.DailyMetricInput {
        let cutoff : Nat64 = Nat64.fromNat(Int.abs(Time.now())) - STALENESS_CUTOFF_NS;

        // Index activity by canister address text for O(1) join with the registry.
        let activityIndex = HashMap.HashMap<Text, Types.ShareAgentActivity>(snapshot.activity.size(), Text.equal, Text.hash);
        for (a in snapshot.activity.vals()) {
            activityIndex.put(a.address, a);
        };

        var total_mainers_created : Nat = 0;
        var total_active : Nat = 0;
        var total_paused : Nat = 0;
        var total_cycles_active : Nat = 0;
        var active_low : Nat = 0;
        var active_mid : Nat = 0;
        var active_high : Nat = 0;
        var active_very_high : Nat = 0;
        var active_custom : Nat = 0;
        var paused_low : Nat = 0;
        var paused_mid : Nat = 0;
        var paused_high : Nat = 0;
        var paused_very_high : Nat = 0;
        var paused_custom : Nat = 0;
        var custom_burn_rate_total : Nat = 0;

        for (entry in snapshot.registry.vals()) {
            total_mainers_created += 1;
            switch (activityIndex.get(entry.address)) {
                case null {
                    // Never heartbeated → paused, custom-tier bucket, no cycles
                    total_paused += 1;
                    paused_custom += 1;
                };
                case (?a) {
                    let isActive = a.lastChallengeRequestTimestamp >= cutoff;
                    let bucket = classifyBurnRate(a.cyclesBurnRate);
                    if (isActive) {
                        total_active += 1;
                        total_cycles_active += a.cycleBalance;
                        switch (bucket) {
                            case (#Low) { active_low += 1; };
                            case (#Mid) { active_mid += 1; };
                            case (#High) { active_high += 1; };
                            case (#VeryHigh) { active_very_high += 1; };
                            case (#Custom(cycles)) {
                                active_custom += 1;
                                custom_burn_rate_total += cycles;
                            };
                        };
                    } else {
                        total_paused += 1;
                        switch (bucket) {
                            case (#Low) { paused_low += 1; };
                            case (#Mid) { paused_mid += 1; };
                            case (#High) { paused_high += 1; };
                            case (#VeryHigh) { paused_very_high += 1; };
                            case (#Custom(_)) { paused_custom += 1; };
                        };
                    };
                };
            };
        };

        let totalTcyclesMainers : Nat = total_cycles_active / 1_000_000_000_000;
        let daily_burn_rate_raw : Nat =
            active_low * BURN_RATE_LOW_CYCLES
            + active_mid * BURN_RATE_MID_CYCLES
            + active_high * BURN_RATE_HIGH_CYCLES
            + active_very_high * BURN_RATE_VERY_HIGH_CYCLES
            + custom_burn_rate_total;
        let daily_burn_rate_tcycles : Nat = daily_burn_rate_raw / 1_000_000_000_000;

        // Always report yesterday's row — phase-aligned with the midnight tick.
        let yesterdayNs : Int = Time.now() - ONE_DAY_NS;
        let dateText = Util.toIsoDate(yesterdayNs);

        {
            date = dateText;
            funnai_index = 0.0;          // filled by enrichWithPricing
            daily_burn_rate_cycles = daily_burn_rate_tcycles;
            daily_burn_rate_usd = 0.0;   // filled by enrichWithPricing
            total_mainers_created = total_mainers_created;
            total_active_mainers = total_active;
            total_paused_mainers = total_paused;
            total_cycles_all_mainers = totalTcyclesMainers;
            active_low_burn_rate_mainers = active_low;
            active_medium_burn_rate_mainers = active_mid;
            active_high_burn_rate_mainers = active_high;
            active_very_high_burn_rate_mainers = active_very_high;
            active_custom_burn_rate_mainers = active_custom;
            paused_low_burn_rate_mainers = paused_low;
            paused_medium_burn_rate_mainers = paused_mid;
            paused_high_burn_rate_mainers = paused_high;
            paused_very_high_burn_rate_mainers = paused_very_high;
            paused_custom_burn_rate_mainers = paused_custom;
            total_cycles_all = ?totalTcyclesMainers;     // protocol cycles = 0, so = mainers
            total_cycles_all_usd = null;                 // filled by enrichWithPricing
            total_cycles_protocol = ?0;                  // dropped per design
            total_cycles_protocol_usd = ?0.0;            // dropped per design
            total_cycles_mainers_usd = null;             // filled by enrichWithPricing
        }
    };

    // Pull snapshot from ShareService, aggregate, and compute the DailyMetric
    // record. Does NOT write to dailyMetrics and does NOT mutate any status
    // markers — callers handle those concerns. Reusable by both the recurring
    // timer (which then stores) and the preview admin (which doesn't).
    private func computeDailyMetricFromSnapshot() : async Types.DailyMetricResult {
        let shareService : Types.ShareServiceCanister_Actor = actor(SHARE_SERVICE_CANISTER_ID);
        let snapshotResult = try {
            await shareService.getShareAgentRegistryWithActivityAdmin();
        } catch (e) {
            return #Err(#Other("ShareService snapshot call threw: " # Error.message(e)));
        };
        switch (snapshotResult) {
            case (#Err(err)) { #Err(err) };
            case (#Ok(snapshot)) { computeDailyMetric(aggregateFromSnapshot(snapshot)) };
        };
    };

    // Called by the daily timer (or by triggerDailyMetricsAggregationAdmin for tests).
    // Computes the DailyMetric via the shared helper, then writes it and updates
    // the run-status markers.
    private func triggerDailyMetricsAggregation() : async Types.DailyMetricResult {
        let computed = await computeDailyMetricFromSnapshot();
        switch (computed) {
            case (#Err(err)) {
                let msg = debug_show(err);
                D.print("Api: triggerDailyMetricsAggregation - " # msg);
                lastDailyMetricsFailure := ?msg;
                #Err(err)
            };
            case (#Ok(metric)) {
                dailyMetrics.put(metric.metadata.date, metric);
                lastSuccessfulMetricDate := ?metric.metadata.date;
                lastDailyMetricsFailure := null;
                D.print("Api: triggerDailyMetricsAggregation - stored metric for " # metric.metadata.date);
                #Ok(metric)
            };
        };
    };

    // Controller-only debug helpers — fire aggregation immediately without
    // waiting for the timer, and inspect the raw ShareService snapshot. Used by
    // smoke tests and by ops to verify a fresh aggregation end-to-end.

    public shared (msg) func triggerDailyMetricsAggregationAdmin() : async Types.DailyMetricResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        try {
            await triggerDailyMetricsAggregation()
        } catch (e) {
            let msg = "triggerDailyMetricsAggregation threw: " # Error.message(e);
            D.print("Api: triggerDailyMetricsAggregationAdmin - " # msg);
            lastDailyMetricsFailure := ?msg;
            #Err(#Other(msg))
        };
    };

    // Same compute path as triggerDailyMetricsAggregationAdmin (snapshot → aggregate →
    // enrich → DailyMetric record) but does NOT write into dailyMetrics and does NOT
    // touch the run-status markers. Use as the post-upgrade smoke test: confirms the
    // cross-canister read, the RBAC grant, the pricing cache, and the aggregation
    // math — without overwriting Django's row.
    public shared (msg) func previewDailyMetricsAggregationAdmin() : async Types.DailyMetricResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        try {
            await computeDailyMetricFromSnapshot()
        } catch (e) {
            #Err(#Other("computeDailyMetricFromSnapshot threw: " # Error.message(e)))
        };
    };

    // TODO - outcomment once proven in production
    public query (msg) func previewIsoDateAdmin(nanos : Int) : async Types.TextResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not hasAdminRole(msg.caller, #AdminQuery)) { return #Err(#Unauthorized); };
        #Ok(Util.toIsoDate(nanos))
    };

    // Commented out — not for production. Re-enable only for local debugging of
    // parseFloat against new upstream API formats. The pytest cases in
    // test_api_canister.py (test__previewParseFloatAdmin_*) need this to run.
    // public query (msg) func previewParseFloatAdmin(input : Text) : async Types.FloatResult {
    //     if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
    //     if (not hasAdminRole(msg.caller, #AdminQuery)) { return #Err(#Unauthorized); };
    //     switch (parseFloat(input)) {
    //         case (?v) { #Ok(v) };
    //         case null { #Err(#Other("parseFloat: could not parse '" # input # "'")) };
    //     };
    // };

    public shared (msg) func pullShareServiceSnapshotAdmin() : async Types.ShareAgentRegistryWithActivityResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        let shareService : Types.ShareServiceCanister_Actor = actor(SHARE_SERVICE_CANISTER_ID);
        try {
            await shareService.getShareAgentRegistryWithActivityAdmin();
        } catch (e) {
            #Err(#Other("ShareService call threw: " # Error.message(e)))
        };
    };

    // -------------------------------------------------------------------------------
    // Token Rewards Public Query Endpoints

    public shared query func getTokenRewardsData() : async Types.TokenRewardsDataResult {
        return #Ok(getTokenRewardsDataInternal());
    };

    // -------------------------------------------------------------------------------
    // Activity Feed Cache Storage
    // -------------------------------------------------------------------------------

    // Cache stores array-optimized types for efficient queries
    // INVARIANT: Arrays are always sorted by timestamp DESC (newest first)
    transient var cachedWinnerDeclarations : [Types.ChallengeWinnerDeclarationArray] = [];
    transient var cachedChallenges : [Types.Challenge] = [];

    // Cache metadata
    transient var activityFeedLastSyncTimestamp : Nat64 = 0;

    // Timer state
    transient var recurringTimerId : ?Timer.TimerId = null;
    var syncIntervalInSeconds : Nat = 300;
    transient var IS_SYNCING : Bool = false;

    // Configuration
    let MAX_CACHED_WINNERS : Nat = 500;
    let MAX_CACHED_CHALLENGES : Nat = 100;

    // -------------------------------------------------------------------------------
    // Activity Feed Sorting Functions
    // -------------------------------------------------------------------------------

    // Sort winners by finalizedTimestamp DESC (newest first)
    func sortWinnersDesc(arr : [Types.ChallengeWinnerDeclarationArray]) : [Types.ChallengeWinnerDeclarationArray] {
        Array.sort<Types.ChallengeWinnerDeclarationArray>(arr, func(a, b) {
            if (a.finalizedTimestamp > b.finalizedTimestamp) { #less }
            else if (a.finalizedTimestamp < b.finalizedTimestamp) { #greater }
            else { #equal }
        })
    };

    // Sort challenges by challengeCreationTimestamp DESC (newest first)
    func sortChallengesDesc(arr : [Types.Challenge]) : [Types.Challenge] {
        Array.sort<Types.Challenge>(arr, func(a, b) {
            if (a.challengeCreationTimestamp > b.challengeCreationTimestamp) { #less }
            else if (a.challengeCreationTimestamp < b.challengeCreationTimestamp) { #greater }
            else { #equal }
        })
    };

    // Cache eviction helper
    func trimToMaxSize<T>(arr : [T], maxSize : Nat) : [T] {
        if (arr.size() <= maxSize) { arr }
        else { Util.sliceArray(arr, 0, maxSize) }
    };

    // -------------------------------------------------------------------------------
    // Activity Feed Timer Admin Endpoints
    // -------------------------------------------------------------------------------

    public shared query (msg) func getActivityFeedSyncIntervalAdmin() : async Types.NatResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        return #Ok(syncIntervalInSeconds);
    };

    public shared (msg) func setActivityFeedSyncIntervalAdmin(_syncIntervalInSeconds : Nat) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        D.print("API: setActivityFeedSyncIntervalAdmin - Setting interval from " # debug_show(syncIntervalInSeconds) # " to " # debug_show(_syncIntervalInSeconds) # " seconds");
        syncIntervalInSeconds := _syncIntervalInSeconds;
        let _ = await startActivityFeedTimer();
        return #Ok({ status_code = 200 });
    };

    public shared (msg) func startActivityFeedTimerAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        D.print("API: startActivityFeedTimerAdmin - Called by controller");
        return await startActivityFeedTimer();
    };

    public shared (msg) func stopActivityFeedTimerAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        D.print("API: stopActivityFeedTimerAdmin - Called by controller");
        return await stopActivityFeedTimer();
    };

    // -------------------------------------------------------------------------------
    // Activity Feed Private Timer Functions
    // -------------------------------------------------------------------------------

    private func startActivityFeedTimer() : async Types.AuthRecordResult {
        D.print("API: startActivityFeedTimer - Stopping any existing timer first");
        let _ = await stopActivityFeedTimer();
        IS_SYNCING := false;
        D.print("API: startActivityFeedTimer - Scheduling initial sync in 5 seconds, then recurring every " # debug_show(syncIntervalInSeconds) # " seconds");
        ignore Timer.setTimer<system>(#seconds 5,
            func () : async () {
                D.print("API: startActivityFeedTimer - Initial timer fired, setting up recurring timer");
                let id = Timer.recurringTimer<system>(#seconds syncIntervalInSeconds, triggerActivityFeedSync);
                recurringTimerId := ?id;
                D.print("API: startActivityFeedTimer - Recurring timer ID: " # debug_show(id) # ", triggering first sync now");
                await triggerActivityFeedSync();
        });
        return #Ok({ auth = "Activity feed sync timer started." });
    };

    private func stopActivityFeedTimer() : async Types.AuthRecordResult {
        switch (recurringTimerId) {
            case (?id) {
                D.print("API: stopActivityFeedTimer - Cancelling timer ID: " # debug_show(id));
                Timer.cancelTimer(id);
                recurringTimerId := null;
                return #Ok({ auth = "Activity feed sync timer stopped." });
            };
            case null {
                D.print("API: stopActivityFeedTimer - No active timer to stop");
                return #Ok({ auth = "No active activity feed sync timer." });
            };
        };
    };

    // -------------------------------------------------------------------------------
    // Activity Feed Sync Logic
    // -------------------------------------------------------------------------------

    func toArrayDeclaration(decl : Types.ChallengeWinnerDeclaration) : Types.ChallengeWinnerDeclarationArray {
        {
            challengeId = decl.challengeId;
            finalizedTimestamp = decl.finalizedTimestamp;
            winner = decl.winner;
            secondPlace = decl.secondPlace;
            thirdPlace = decl.thirdPlace;
            participants = List.toArray(decl.participants);
        }
    };

    func triggerActivityFeedSync() : async () {
        if (IS_SYNCING) {
            D.print("API: triggerActivityFeedSync - Already syncing, skipping");
            return;
        };
        IS_SYNCING := true;
        D.print("API: triggerActivityFeedSync - Starting sync from GameState canister: " # MASTER_CANISTER_ID);

        try {
            let gameStateActor : Types.GameStateCanister_Actor = actor(MASTER_CANISTER_ID);

            D.print("API: triggerActivityFeedSync - Calling getRecentProtocolActivity");
            let activityResult = await gameStateActor.getRecentProtocolActivity();
            switch (activityResult) {
                case (#Ok(activity)) {
                    D.print("API: triggerActivityFeedSync - Received " # debug_show(activity.winners.size()) # " winners, " # debug_show(activity.challenges.size()) # " challenges from GameState");

                    // Transform winners: List → Array, then sort DESC by finalizedTimestamp
                    let transformedWinners = Array.map<
                        Types.ChallengeWinnerDeclaration,
                        Types.ChallengeWinnerDeclarationArray
                    >(activity.winners, toArrayDeclaration);
                    let sortedWinners = sortWinnersDesc(transformedWinners);

                    // Sort challenges (HashMap order is unpredictable)
                    let sortedChallenges = sortChallengesDesc(activity.challenges);

                    // Apply cache eviction
                    cachedWinnerDeclarations := trimToMaxSize(sortedWinners, MAX_CACHED_WINNERS);
                    cachedChallenges := trimToMaxSize(sortedChallenges, MAX_CACHED_CHALLENGES);

                    D.print("API: triggerActivityFeedSync - Sync completed - cached " # debug_show(cachedWinnerDeclarations.size()) # " winners, " # debug_show(cachedChallenges.size()) # " challenges");
                };
                case (#Err(e)) {
                    D.print("API: triggerActivityFeedSync - Sync failed with error: " # debug_show(e));
                };
            };

            activityFeedLastSyncTimestamp := Nat64.fromNat(Int.abs(Time.now()));
            D.print("API: triggerActivityFeedSync - Updated lastSyncTimestamp to " # debug_show(activityFeedLastSyncTimestamp));
        } catch (e) {
            D.print("API: triggerActivityFeedSync - Exception caught - will retry on next timer tick");
        };

        IS_SYNCING := false;
        D.print("API: triggerActivityFeedSync - Sync cycle complete");
    };

    // -------------------------------------------------------------------------------
    // Activity Feed Public Endpoints
    // -------------------------------------------------------------------------------

    /// Get recent protocol activity with independent pagination
    public shared query func getActivityFeed(input : Types.ActivityFeedQuery) : async Types.ActivityFeedResult {
        let winnersLimit = switch (input.winnersLimit) {
            case (?l) { if (l > 100) 100 else l };
            case null { 20 };
        };
        let winnersOffset = switch (input.winnersOffset) { case (?o) { o }; case null { 0 }; };
        let challengesLimit = switch (input.challengesLimit) {
            case (?l) { if (l > 100) 100 else l };
            case null { 20 };
        };
        let challengesOffset = switch (input.challengesOffset) { case (?o) { o }; case null { 0 }; };

        // Apply timestamp filter + pagination
        let (filteredWinners, totalWinners) = switch (input.sinceTimestamp) {
            case (?since) {
                Util.collectWithEarlyStop<Types.ChallengeWinnerDeclarationArray>(
                    cachedWinnerDeclarations,
                    func(w) { w.finalizedTimestamp > since },
                    winnersOffset, winnersLimit
                );
            };
            case null {
                (Util.sliceArray(cachedWinnerDeclarations, winnersOffset, winnersLimit),
                 cachedWinnerDeclarations.size());
            };
        };

        let (filteredChallenges, totalChallenges) = switch (input.sinceTimestamp) {
            case (?since) {
                Util.collectWithEarlyStop<Types.Challenge>(
                    cachedChallenges,
                    func(c) { c.challengeCreationTimestamp > since },
                    challengesOffset, challengesLimit
                );
            };
            case null {
                (Util.sliceArray(cachedChallenges, challengesOffset, challengesLimit),
                 cachedChallenges.size());
            };
        };

        return #Ok({
            winners = filteredWinners;
            challenges = filteredChallenges;
            totalWinners = totalWinners;
            totalChallenges = totalChallenges;
            cacheTimestamp = activityFeedLastSyncTimestamp;
        });
    };

    /// Get current open challenges from cache
    public shared query func getOpenChallengesFromCache() : async Types.ChallengesResult {
        return #Ok(cachedChallenges);
    };

    /// Get cache status for monitoring
    public shared query func getActivityFeedCacheStatus() : async Types.CacheStatusResult {
        return #Ok({
            lastSyncTimestamp = activityFeedLastSyncTimestamp;
            cachedWinnersCount = cachedWinnerDeclarations.size();
            cachedChallengesCount = cachedChallenges.size();
            syncIntervalSeconds = syncIntervalInSeconds;
        });
    };

    // System upgrade hooks
    system func preupgrade() {
        dailyMetricsEntries := Iter.toArray(dailyMetrics.entries());
        adminRoleAssignmentsStable := Iter.toArray(adminRoleAssignmentsStorage.entries());
    };

    system func postupgrade() {
        dailyMetrics := HashMap.fromIter<Text, Types.DailyMetric>(dailyMetricsEntries.vals(), dailyMetricsEntries.size(), Text.equal, Text.hash);
        dailyMetricsEntries := [];

        adminRoleAssignmentsStorage := HashMap.fromIter(Iter.fromArray(adminRoleAssignmentsStable), adminRoleAssignmentsStable.size(), Text.equal, Text.hash);
        adminRoleAssignmentsStable := [];
    };
};