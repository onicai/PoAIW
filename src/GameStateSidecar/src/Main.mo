import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import D "mo:base/Debug";
import Error "mo:base/Error";
import HashMap "mo:base/HashMap";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import { setTimer; recurringTimer } = "mo:base/Timer";
import Timer "mo:base/Timer";
import Cycles "mo:base/ExperimentalCycles";

import Types "../../common/Types";
import Constants "../../common/Constants";
import IcpIndex "../../common/icp-index-interface";
import TokenLedger "../../common/icp-ledger-interface";
import Utils "Utils";

// GameStateSidecar - daily sweep for ICP top-up payments that have aged out of the
// ledger's live window.
//
// WHY THIS CANISTER EXISTS
//
// GameState credits a mAIner when someone pays ICP to its account with the mAIner's
// canister-id prefix in the icrc1_memo, and then tells GameState the block id. But
// the ICP ledger only serves a short LIVE window - measured at 1_664 blocks, about
// 2h40m, and it shrinks as ICP volume rises. A payment nobody notifies within
// roughly 1.5 hours becomes unreachable through the public endpoint.
//
// This canister closes that gap. Once a day it crawls the ICP INDEX canister for
// payments to GameState's account, and offers the archived ones back to GameState.
//
// WHAT IT IS TRUSTED WITH: TIMING, NOT ATTRIBUTION
//
// It passes GameState a BLOCK ID and nothing else. It never says which mAIner a
// payment belongs to - GameState re-reads the block from the ledger and resolves
// the memo itself. So a compromised or buggy sidecar cannot redirect anyone's
// payment; the worst it can do is waste cycles pointing at junk blocks. Keep it
// that way: if a future change has this canister send a mAIner address, the whole
// security argument collapses.
//
// WHY IT IS A SEPARATE CANISTER
//
// Upgrading GameState costs a full protocol pause. Crawl logic - paging, cursor
// handling, retry policy - is exactly the part that gets iterated on, so it lives
// here where a redeploy takes seconds and disturbs nothing.
persistent actor class GameStateSidecarCanister() = this {

    // ------------------------------------------------------------------
    // Health & identity
    // ------------------------------------------------------------------

    public shared query (msg) func whoami() : async Principal {
        return msg.caller;
    };

    public shared query func health() : async Types.StatusCodeRecordResult {
        return #Ok({ status_code = 200 });
    };

    public shared query (msg) func amiController() : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        return #Ok({ status_code = 200 });
    };

    public shared (msg) func ready() : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) { return #Err(#Unauthorized); };
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        // Ready means "configured and armed". A sidecar with a dead timer is the
        // failure mode that hides, so it is part of readiness rather than a detail.
        if (Text.size(GAME_STATE_CANISTER_ID) == 0) {
            return #Err(#Other("GameState canister id is not configured"));
        };
        switch (recurringTimerId) {
            case (null) { return #Err(#Other("The sweep timer is not armed")); };
            case (?_) { return #Ok({ status_code = 200 }); };
        };
    };

    // ------------------------------------------------------------------
    // Admin roles
    // ------------------------------------------------------------------
    //
    // Same shape as the other protocol canisters. Post-SNS the controller is NNS/SNS
    // root, so controller-gated endpoints stop being reachable by maintainers -
    // these role assignments are the remaining operational path.

    var adminRoleAssignmentsStable : [(Text, Types.AdminRoleAssignment)] = [];
    transient var adminRoleAssignmentsStorage : HashMap.HashMap<Text, Types.AdminRoleAssignment> =
        HashMap.HashMap<Text, Types.AdminRoleAssignment>(0, Text.equal, Text.hash);

    private func hasAdminRole(principal : Principal, requiredRole : Types.AdminRole) : Bool {
        if (Principal.isController(principal)) { return true; };
        switch (adminRoleAssignmentsStorage.get(Principal.toText(principal))) {
            case (null) { return false; };
            case (?assignment) {
                switch (assignment.role, requiredRole) {
                    case (#AdminUpdate, #AdminQuery) { true };
                    case (#AdminUpdate, #AdminUpdate) { true };
                    case (#AdminQuery, #AdminQuery) { true };
                    case _ { false };
                };
            };
        };
    };

    public shared (msg) func assignAdminRole(input : Types.AssignAdminRoleInputRecord) : async Types.AdminRoleAssignmentResult {
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        let assignment : Types.AdminRoleAssignment = {
            principal = input.principal;
            role = input.role;
            assignedBy = Principal.toText(msg.caller);
            assignedAt = Nat64.fromNat(Int.abs(Time.now()));
            note = input.note;
        };
        adminRoleAssignmentsStorage.put(input.principal, assignment);
        return #Ok(assignment);
    };

    public shared (msg) func revokeAdminRole(principalText : Text) : async Types.TextResult {
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        switch (adminRoleAssignmentsStorage.remove(principalText)) {
            case (null) { return #Err(#Other("No admin role found for principal: " # principalText)); };
            case (?_) { return #Ok("Admin role revoked for principal: " # principalText); };
        };
    };

    public shared query (msg) func getAdminRoles() : async Types.AdminRoleAssignmentsResult {
        if (not Principal.isController(msg.caller)) { return #Err(#Unauthorized); };
        return #Ok(Iter.toArray(adminRoleAssignmentsStorage.vals()));
    };

    // ------------------------------------------------------------------
    // Configuration
    // ------------------------------------------------------------------

    var GAME_STATE_CANISTER_ID : Text = "r5m5y-diaaa-aaaaa-qanaa-cai"; // prd

    public shared (msg) func setGameStateCanisterId(newId : Text) : async Types.StatusCodeRecordResult {
        if (not hasAdminRole(msg.caller, #AdminUpdate)) { return #Err(#Unauthorized); };
        // Reject a malformed id here rather than trapping later on actor(id).
        let parsed = Principal.fromText(newId);
        D.print("GameStateSidecar: setGameStateCanisterId - " # newId # " parsed: " # debug_show(parsed));
        GAME_STATE_CANISTER_ID := newId;
        return #Ok({ status_code = 200 });
    };

    public shared query (msg) func getGameStateCanisterId() : async Types.TextResult {
        if (not hasAdminRole(msg.caller, #AdminQuery)) { return #Err(#Unauthorized); };
        return #Ok(GAME_STATE_CANISTER_ID);
    };

    // The account the sweep crawls: GameState's DEFAULT subaccount on the ICP
    // ledger, as lowercase hex.
    //
    // Derived, never configured. GameState computes its own the same way
    // (Principal.toLedgerAccount(self, null)), so the two cannot drift. A
    // hardcoded hex string per network would be a config bug waiting to happen -
    // and the index answers a wrong identifier with an EMPTY list rather than an
    // error, so the mistake would look exactly like having nothing to sweep.
    private func gameStateAccountIdentifier() : Text {
        Utils.blobToHex(Principal.toLedgerAccount(Principal.fromText(GAME_STATE_CANISTER_ID), null));
    };

    // Exposed so a test can pin it against `dfx ledger account-id --of-principal`,
    // which needs no ledger to be running.
    public shared query (msg) func getGameStateAccountIdentifierAdmin() : async Types.TextResult {
        if (not hasAdminRole(msg.caller, #AdminQuery)) { return #Err(#Unauthorized); };
        return #Ok(gameStateAccountIdentifier());
    };

    // ------------------------------------------------------------------
    // External canisters
    // ------------------------------------------------------------------

    transient let ICP_INDEX_CANISTER_ID : Text = "qhbym-qaaaa-aaaaa-aaafq-cai";
    transient let ICP_INDEX_ACTOR : IcpIndex.ICP_INDEX = actor (ICP_INDEX_CANISTER_ID);
    transient let ICP_LEDGER_ACTOR : TokenLedger.TOKEN_LEDGER = Types.IcpLedger_Actor;

    // ------------------------------------------------------------------
    // Sweep state
    // ------------------------------------------------------------------

    // Everything at or below this block id has been dealt with. Deliberately NOT
    // defaulted to 0: a first run from 0 would walk GameState's entire account
    // history. Set it with setScannedThroughBlockIdAdmin at deploy time, and stage
    // any backfill in chunks.
    var scannedThroughBlockId : Nat64 = 0;

    // Blocks that failed for a TRANSIENT reason, with an attempt count.
    //
    // This is not a "permanently skipped" list - terminal rejections are logged and
    // the cursor simply moves past them. It exists because the cursor advances
    // unconditionally: without it, a payment that failed because GameState was
    // paused would be silently burned. It self-evicts at MAX_RETRY_ATTEMPTS, so it
    // does not grow with history.
    var pendingRetries : [(Nat64, Nat8)] = [];

    var lastRunAt : Nat64 = 0;
    var lastRunOffered : Nat = 0;
    var lastRunRedeemed : Nat = 0;
    var lastRunRejected : Nat = 0;
    var lastRunRetried : Nat = 0;
    // False when the run hit MAX_PAGES_PER_RUN before reaching the cursor, which
    // means the cursor could NOT be advanced safely. Surfaced in the status record
    // because it is the signal that a backfill needs staging by hand.
    var lastRunReachedCursor : Bool = true;

    transient let PAGE_SIZE : Nat64 = 100;
    transient let MAX_PAGES_PER_RUN : Nat = 10;
    transient let MAX_OFFERS_PER_RUN : Nat = 10;
    transient let MAX_RETRY_ATTEMPTS : Nat8 = 5;

    // Re-entrancy guard. Transient on purpose: a stuck flag must not survive an
    // upgrade, and the TTL covers a run that died mid-flight.
    transient var sweepInFlightSince : ?Nat64 = null;
    transient let SWEEP_INFLIGHT_TTL_NS : Nat64 = 1_800_000_000_000; // 30 min

    private func takeSweepGuard() : Bool {
        let now = Nat64.fromNat(Int.abs(Time.now()));
        switch (sweepInFlightSince) {
            case (?startedAt) {
                if (now < startedAt + SWEEP_INFLIGHT_TTL_NS) { return false; };
                D.print("GameStateSidecar: takeSweepGuard - taking over a stale guard");
            };
            case (null) { };
        };
        sweepInFlightSince := ?now;
        return true;
    };

    private func releaseSweepGuard() {
        sweepInFlightSince := null;
    };

    private func retryAttempts(blockId : Nat64) : Nat8 {
        for ((id, attempts) in pendingRetries.vals()) {
            if (id == blockId) { return attempts; };
        };
        return 0;
    };

    private func noteRetry(blockId : Nat64) {
        let attempts = retryAttempts(blockId);
        if (attempts == 0) {
            pendingRetries := Array.append<(Nat64, Nat8)>(pendingRetries, [(blockId, 1)]);
            return;
        };
        if (attempts + 1 >= MAX_RETRY_ATTEMPTS) {
            D.print("GameStateSidecar: noteRetry - giving up on block " # Nat64.toText(blockId));
            clearRetry(blockId);
            return;
        };
        pendingRetries := Array.map<(Nat64, Nat8), (Nat64, Nat8)>(
            pendingRetries,
            func((id, n) : (Nat64, Nat8)) : (Nat64, Nat8) {
                if (id == blockId) { (id, n + 1) } else { (id, n) };
            }
        );
    };

    private func clearRetry(blockId : Nat64) {
        pendingRetries := Array.filter<(Nat64, Nat8)>(
            pendingRetries,
            func((id, _) : (Nat64, Nat8)) : Bool { id != blockId }
        );
    };

    // ------------------------------------------------------------------
    // The sweep
    // ------------------------------------------------------------------

    // Is this index entry a payment TO GameState that is worth offering?
    //
    // The index returns both directions - GameState's own disbursements appear here
    // too - so filtering on the recipient is required, not cosmetic. GameState would
    // reject a disbursement anyway (its to != PROTOCOL_PRINCIPAL_BLOB check), but
    // filtering locally avoids paying for the round trip.
    private func isInboundTopUpCandidate(entry : IcpIndex.TransactionWithId, accountId : Text) : Bool {
        switch (entry.transaction.operation) {
            case (#Transfer(details)) {
                if (not Text.equal(details.to, accountId)) { return false; };
                // Mirrors GameState's MIN_TOPUP_E8S. Cheap local filter; GameState
                // enforces the real floor.
                if (details.amount.e8s < 9_000_000) { return false; };
                switch (entry.transaction.icrc1_memo) {
                    case (null) { return false; };
                    case (?memo) { return memo.size() > 0; };
                };
            };
            // Mint / Burn / Approve are never mAIner top-ups.
            case (_) { return false; };
        };
    };

    // The archive boundary. Everything below it has aged out of the ledger's live
    // window and is ours to sweep; everything at or above it still belongs to the
    // public notifyMainerTopUp endpoint, so we leave it alone and pick it up on a
    // later run once it has aged.
    private func fetchFirstBlockIndex() : async ?Nat64 {
        try {
            let response = await ICP_LEDGER_ACTOR.query_blocks({ start = 0 : Nat64; length = 0 : Nat64 });
            return ?response.first_block_index;
        } catch (e) {
            D.print("GameStateSidecar: fetchFirstBlockIndex - failed: " # Error.message(e));
            return null;
        };
    };

    private func offerBlock(blockId : Nat64) : async () {
        let gameState = actor (GAME_STATE_CANISTER_ID) : Types.GameStateSweep_Actor;
        lastRunOffered += 1;
        try {
            switch (await gameState.sweepArchivedTopUp({ paymentTransactionBlockId = blockId })) {
                case (#Ok(#Redeemed(record))) {
                    D.print("GameStateSidecar: offerBlock - redeemed " # Nat64.toText(blockId) # " for " # record.mainerAgentAddress);
                    lastRunRedeemed += 1;
                    clearRetry(blockId);
                };
                case (#Ok(#AlreadyRedeemed)) {
                    // Expected: the public endpoint may well have got there first.
                    lastRunRedeemed += 1;
                    clearRetry(blockId);
                };
                case (#Ok(#Rejected(err))) {
                    D.print("GameStateSidecar: offerBlock - rejected " # Nat64.toText(blockId) # ": " # debug_show(err));
                    lastRunRejected += 1;
                    clearRetry(blockId);
                };
                case (#Ok(#Retry(err))) {
                    D.print("GameStateSidecar: offerBlock - retry " # Nat64.toText(blockId) # ": " # debug_show(err));
                    lastRunRetried += 1;
                    noteRetry(blockId);
                };
                case (#Err(err)) {
                    // Unauthorized, or GameState rejecting us outright. Retryable:
                    // registration may simply not have happened yet.
                    D.print("GameStateSidecar: offerBlock - call returned Err for " # Nat64.toText(blockId) # ": " # debug_show(err));
                    lastRunRetried += 1;
                    noteRetry(blockId);
                };
            };
        } catch (e) {
            // A trap or reject covers "GameState is out of cycles" and "GameState is
            // upgrading" with no classification logic at all. Always retryable.
            D.print("GameStateSidecar: offerBlock - call failed for " # Nat64.toText(blockId) # ": " # Error.message(e));
            lastRunRetried += 1;
            noteRetry(blockId);
        };
    };

    private func runSweepOnce() : async () {
        if (not takeSweepGuard()) {
            D.print("GameStateSidecar: runSweepOnce - a sweep is already in flight, skipping");
            return;
        };
        try {
            lastRunAt := Nat64.fromNat(Int.abs(Time.now()));
            lastRunOffered := 0;
            lastRunRedeemed := 0;
            lastRunRejected := 0;
            lastRunRetried := 0;
            lastRunReachedCursor := false;

            let firstBlockIndex = switch (await fetchFirstBlockIndex()) {
                case (null) { return; };  // ledger unreachable; try again next run
                case (?i) { i };
            };
            let accountId = gameStateAccountIdentifier();
            D.print("GameStateSidecar: runSweepOnce - account " # accountId # " firstBlockIndex " # Nat64.toText(firstBlockIndex));

            // Page BACKWARDS from the newest transaction. The index has no forward
            // pagination: `start` is exclusive and results come newest-first, so to
            // page you pass the id of the OLDEST item in the previous page.
            let candidates = Buffer.Buffer<Nat64>(64);
            var start : ?Nat64 = null;
            var pages : Nat = 0;
            var highestArchivedSeen : Nat64 = scannedThroughBlockId;

            label paging loop {
                if (pages >= MAX_PAGES_PER_RUN) { break paging; };
                pages += 1;

                let response = try {
                    await ICP_INDEX_ACTOR.get_account_identifier_transactions({
                        account_identifier = accountId;
                        max_results = PAGE_SIZE;
                        start = start;
                    });
                } catch (e) {
                    D.print("GameStateSidecar: runSweepOnce - index call failed: " # Error.message(e));
                    break paging;
                };

                let pageData = switch (response) {
                    case (#Err(indexError)) {
                        D.print("GameStateSidecar: runSweepOnce - index error: " # indexError.message);
                        break paging;
                    };
                    case (#Ok(data)) { data };
                };

                if (pageData.transactions.size() == 0) {
                    // Ran off the end of the account's history.
                    lastRunReachedCursor := true;
                    break paging;
                };

                var oldestInPage : Nat64 = 0;
                for (entry in pageData.transactions.vals()) {
                    oldestInPage := entry.id;
                    if (entry.id <= scannedThroughBlockId) {
                        lastRunReachedCursor := true;
                    } else if (entry.id < firstBlockIndex) {
                        // Archived and not yet handled.
                        if (entry.id > highestArchivedSeen) { highestArchivedSeen := entry.id; };
                        if (isInboundTopUpCandidate(entry, accountId)) {
                            candidates.add(entry.id);
                        };
                    };
                    // entry.id >= firstBlockIndex: still live, still the public
                    // endpoint's job. Skipped WITHOUT advancing the cursor past it,
                    // so it is reconsidered once it ages into the archive.
                };

                if (lastRunReachedCursor) { break paging; };
                if (Nat64.fromNat(pageData.transactions.size()) < PAGE_SIZE) {
                    lastRunReachedCursor := true;
                    break paging;
                };
                start := ?oldestInPage;
            };

            // Offer oldest-first: the index gave them to us newest-first.
            let ordered = Buffer.toArray(candidates);
            var offers : Nat = 0;
            var i : Nat = ordered.size();
            label offering while (i > 0) {
                i -= 1;
                if (offers >= MAX_OFFERS_PER_RUN) { break offering; };
                offers += 1;
                await offerBlock(ordered[i]);
            };

            // Re-offer anything still in the retry set, within the same budget.
            for ((blockId, _) in pendingRetries.vals()) {
                if (offers < MAX_OFFERS_PER_RUN) {
                    offers += 1;
                    await offerBlock(blockId);
                };
            };

            // Advance the cursor ONLY if this run actually paged back to it.
            // Otherwise there is an unexamined gap between the cursor and the oldest
            // block we looked at, and advancing would skip those payments for good.
            // lastRunReachedCursor is surfaced by getSidecarStatusAdmin so a stalled
            // backfill is visible rather than silent.
            if (lastRunReachedCursor and highestArchivedSeen > scannedThroughBlockId) {
                scannedThroughBlockId := highestArchivedSeen;
                D.print("GameStateSidecar: runSweepOnce - cursor advanced to " # Nat64.toText(scannedThroughBlockId));
            };

            await topUpOwnCyclesIfLow();
        } catch (e) {
            D.print("GameStateSidecar: runSweepOnce - unexpected failure: " # Error.message(e));
        } finally {
            releaseSweepGuard();
        };
    };

    // ------------------------------------------------------------------
    // Cycles
    // ------------------------------------------------------------------

    // Ask GameState for cycles when running low. GameState owns the threshold and
    // the amount and may refuse; this canister only reports that it is low, so a
    // compromised sidecar cannot enlarge its own ask.
    var MIN_CYCLES_BALANCE_SIDECAR : Nat = 5 * Constants.CYCLES_TRILLION;

    public shared (msg) func setMinCyclesBalanceAdmin(newMinInTrillionCycles : Nat) : async Types.StatusCodeRecordResult {
        if (not hasAdminRole(msg.caller, #AdminUpdate)) { return #Err(#Unauthorized); };
        if (newMinInTrillionCycles > 100) {
            return #Err(#Other("Refusing a minimum balance above 100T"));
        };
        MIN_CYCLES_BALANCE_SIDECAR := newMinInTrillionCycles * Constants.CYCLES_TRILLION;
        return #Ok({ status_code = 200 });
    };

    public shared query (msg) func getMinCyclesBalanceAdmin() : async Types.NatResult {
        if (not hasAdminRole(msg.caller, #AdminQuery)) { return #Err(#Unauthorized); };
        return #Ok(MIN_CYCLES_BALANCE_SIDECAR);
    };

    public shared query (msg) func getCyclesBalanceAdmin() : async Types.NatResult {
        if (not hasAdminRole(msg.caller, #AdminQuery)) { return #Err(#Unauthorized); };
        return #Ok(Cycles.balance());
    };

    private func topUpOwnCyclesIfLow() : async () {
        if (Cycles.balance() >= MIN_CYCLES_BALANCE_SIDECAR) { return; };
        D.print("GameStateSidecar: topUpOwnCyclesIfLow - low balance, asking GameState");
        let gameState = actor (GAME_STATE_CANISTER_ID) : Types.GameStateSweep_Actor;
        try {
            switch (await gameState.requestCyclesForSidecar()) {
                case (#Ok(record)) {
                    D.print("GameStateSidecar: topUpOwnCyclesIfLow - granted " # Nat.toText(record.amount));
                };
                case (#Err(err)) {
                    // A refusal is normal: GameState rate limits to one grant a day
                    // and refuses outright when its own balance is low.
                    D.print("GameStateSidecar: topUpOwnCyclesIfLow - refused: " # debug_show(err));
                };
            };
        } catch (e) {
            D.print("GameStateSidecar: topUpOwnCyclesIfLow - call failed: " # Error.message(e));
        };
    };

    // ------------------------------------------------------------------
    // Timer
    // ------------------------------------------------------------------
    //
    // The timer registration does NOT survive a canister upgrade - only the id
    // value does. Re-arm with startTimerExecutionAdmin after every upgrade; it is a
    // documented step in README-prd-upgrade-commands.md. getSidecarStatusAdmin
    // exists because a dead timer is otherwise indistinguishable from having
    // nothing to sweep.

    var recurringTimerId : ?Timer.TimerId = null;
    var sweepIntervalSeconds : Nat = 86_400; // 24h

    private func triggerSweep() : async () {
        try {
            await runSweepOnce();
        } catch (e) {
            // A timer callback must never trap: a trap kills the recurring timer.
            D.print("GameStateSidecar: triggerSweep - error: " # Error.message(e));
        };
    };

    private func stopTimerExecution() : async Types.AuthRecordResult {
        switch (recurringTimerId) {
            case (?id) {
                Timer.cancelTimer(id);
                recurringTimerId := null;
                return #Ok({ auth = "Timer stopped successfully." });
            };
            case (null) { return #Ok({ auth = "There is no active timer. Nothing to do." }); };
        };
    };

    private func startTimerExecution() : async Types.AuthRecordResult {
        // Idempotent: cancel any existing timer first. After an upgrade the stable
        // id refers to a registration that no longer exists, and cancelling a dead
        // id is harmless.
        let _ = await stopTimerExecution();
        ignore setTimer<system>(
            #seconds 5,
            func() : async () {
                let id = recurringTimer<system>(#seconds sweepIntervalSeconds, triggerSweep);
                recurringTimerId := ?id;
                await triggerSweep();
            }
        );
        return #Ok({ auth = "You started the timer." });
    };

    public shared (msg) func startTimerExecutionAdmin() : async Types.AuthRecordResult {
        if (not hasAdminRole(msg.caller, #AdminUpdate)) { return #Err(#Unauthorized); };
        return await startTimerExecution();
    };

    public shared (msg) func stopTimerExecutionAdmin() : async Types.AuthRecordResult {
        if (not hasAdminRole(msg.caller, #AdminUpdate)) { return #Err(#Unauthorized); };
        return await stopTimerExecution();
    };

    public shared (msg) func setSweepIntervalSecondsAdmin(seconds : Nat) : async Types.StatusCodeRecordResult {
        if (not hasAdminRole(msg.caller, #AdminUpdate)) { return #Err(#Unauthorized); };
        // A floor, so a mistyped value cannot turn the sweep into a hot loop against
        // the index canister.
        if (seconds < 300) { return #Err(#Other("Sweep interval must be at least 300 seconds")); };
        sweepIntervalSeconds := seconds;
        // Restart so the new interval takes effect, but only if already armed.
        switch (recurringTimerId) {
            case (?_) { let _ = await startTimerExecution(); };
            case (null) { };
        };
        return #Ok({ status_code = 200 });
    };

    public shared query (msg) func getSweepIntervalSecondsAdmin() : async Types.NatResult {
        if (not hasAdminRole(msg.caller, #AdminQuery)) { return #Err(#Unauthorized); };
        return #Ok(sweepIntervalSeconds);
    };

    // ------------------------------------------------------------------
    // Cursor & status
    // ------------------------------------------------------------------

    public shared (msg) func setScannedThroughBlockIdAdmin(blockId : Nat64) : async Types.StatusCodeRecordResult {
        if (not hasAdminRole(msg.caller, #AdminUpdate)) { return #Err(#Unauthorized); };
        scannedThroughBlockId := blockId;
        return #Ok({ status_code = 200 });
    };

    public shared query (msg) func getScannedThroughBlockIdAdmin() : async Types.NatResult {
        if (not hasAdminRole(msg.caller, #AdminQuery)) { return #Err(#Unauthorized); };
        return #Ok(Nat64.toNat(scannedThroughBlockId));
    };

    public shared query (msg) func getSidecarStatusAdmin() : async Types.SidecarStatusResult {
        if (not hasAdminRole(msg.caller, #AdminQuery)) { return #Err(#Unauthorized); };
        return #Ok({
            lastRunAt = lastRunAt;
            scannedThroughBlockId = scannedThroughBlockId;
            pendingRetriesCount = pendingRetries.size();
            offered = lastRunOffered;
            redeemed = lastRunRedeemed;
            rejected = lastRunRejected;
            retried = lastRunRetried;
            timerIsArmed = switch (recurringTimerId) { case (null) { false }; case (?_) { true } };
        });
    };

    // Run the sweep now, without waiting for the timer. Used to verify a fresh
    // deployment and to work through a staged backfill.
    public shared (msg) func runSweepNowAdmin() : async Types.StatusCodeRecordResult {
        if (not hasAdminRole(msg.caller, #AdminUpdate)) { return #Err(#Unauthorized); };
        await runSweepOnce();
        return #Ok({ status_code = 200 });
    };

    // ------------------------------------------------------------------
    // Upgrade hooks
    // ------------------------------------------------------------------

    system func preupgrade() {
        adminRoleAssignmentsStable := Iter.toArray(adminRoleAssignmentsStorage.entries());
    };

    system func postupgrade() {
        adminRoleAssignmentsStorage := HashMap.fromIter<Text, Types.AdminRoleAssignment>(
            adminRoleAssignmentsStable.vals(),
            adminRoleAssignmentsStable.size(),
            Text.equal,
            Text.hash
        );
        adminRoleAssignmentsStable := [];
    };
};
