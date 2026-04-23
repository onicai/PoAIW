import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import D "mo:base/Debug";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Bool "mo:base/Bool";
import HashMap "mo:base/HashMap";
import List "mo:base/List";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Float "mo:base/Float";
import Cycles "mo:base/ExperimentalCycles";
import { setTimer; recurringTimer } = "mo:base/Timer";
import Timer "mo:base/Timer";
import Random "mo:base/Random";

import Types "../../common/Types";
import Constants "../../common/Constants";
import ICManagementCanister "../../common/ICManagementCanister";
import TimerRegularity "../../common/TimerRegularity";
import Utils "Utils";

persistent actor class MainerAgentCtrlbCanister() = this {

    transient let IC0 : ICManagementCanister.IC_Management = actor ("aaaaa-aa");

    var MAINER_AGENT_CANISTER_TYPE : Types.MainerAgentCanisterType = #Own;

    public shared (msg) func setMainerCanisterType(_mainer_agent_canister_type : Types.MainerAgentCanisterType) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        MAINER_AGENT_CANISTER_TYPE := _mainer_agent_canister_type;

        // Avoid wrong timers from running when changing mainer canister type
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): setMainerCanisterType - Stopping Timers");
        let result = try {
            await stopTimerExecution();
        } catch (error) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): setMainerCanisterType - stopTimerExecution threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
            return #Err(#Other("stopTimerExecution failed: " # Error.message(error)));
        };
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): setMainerCanisterType - " # debug_show(result));

        return #Ok({ status_code = 200 });
    };

    public query (msg) func getMainerCanisterType() : async Types.MainerAgentCanisterTypeResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        return #Ok(MAINER_AGENT_CANISTER_TYPE);
    };

    // -------------------------------
    var GAME_STATE_CANISTER_ID : Text = "r5m5y-diaaa-aaaaa-qanaa-cai"; // prd
    
    public shared (msg) func setGameStateCanisterId(_game_state_canister_id : Text) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        GAME_STATE_CANISTER_ID := _game_state_canister_id;
        return #Ok({ status_code = 200 });
    };

    public query (msg) func getGameStateCanisterId() : async Text {
        if (Principal.isAnonymous(msg.caller)) {
            return "#Err(#Unauthorized)";
        };
        if (not Principal.isController(msg.caller)) {
            return "#Err(#Unauthorized)";
        };

        return GAME_STATE_CANISTER_ID;
    };

    // Flag to pause mAIner for maintenance
    var MAINTENANCE : Bool = false;

    public shared (msg) func toggleMaintenanceFlagAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        MAINTENANCE := not MAINTENANCE;
        let authRecord = { auth = "You set the flag to " # debug_show(MAINTENANCE) };
        return #Ok(authRecord);
    };

    public query func getMaintenanceFlag() : async Types.FlagResult {
        return #Ok({ flag = MAINTENANCE });
    };

    // Official cycle balance.
    //
    // We add INSTALL_CODE_REFUND_BUFFER to compensate for an undocumented IC
    // mechanism: install_code charges MAX_INSTRUCTIONS_PER_INSTALL_CODE
    // (= 300 B cycles) UPFRONT before canister_init runs, and refunds the
    // unused portion AFTER install completes. So Cycles.balance() inside
    // canister_init returns a value that is ~300 B LOWER than the canister's
    // true post-install balance. (Pre-reinstall snapshot create adds another
    // ~130 B refund the same way.) Without this buffer, officialCyclesBalance
    // would be ~430 B lower than reality, and the first storeAndSubmitResponse
    // would falsely trigger the 90% unofficial-topup penalty.
    //
    // 1 T = comfortably above the largest refund we've observed across runs
    // (~430 B in early runs, ~595 B in later runs — refund varies with snapshot
    // size and instructions actually consumed by canister_init, so a single
    // hard-coded value can't be tight). The buffer is one-time only:
    // line 1294 (officialCyclesBalance := currentCyclesBalance - cyclesToSend)
    // resets it to the actual balance after the first successful submit, so
    // normal unofficial-topup detection resumes from then on.
    //
    // Refs:
    //   - dfinity/ic subnet_config.rs (MAX_INSTRUCTIONS_PER_INSTALL_CODE = 300 B)
    //   - dfinity/ic canister_manager.rs (prepay_execution_cycles / refund_unused_execution_cycles)
    //   - https://forum.dfinity.org/t/temporary-canister-cycles-balance-drop-when-upgrading-a-canister/19345
    let INSTALL_CODE_REFUND_BUFFER : Nat = 1_000_000_000_000;
    var officialCyclesBalance : Nat = Cycles.balance() + INSTALL_CODE_REFUND_BUFFER;
    // Top-level expression statement: runs as part of the actor body init,
    // immediately after the var initializer above. Logs the captured value
    // on every install/reinstall. Note: MAINER_AGENT_CANISTER_TYPE still
    // holds its declared default #Own here — it gets reassigned later via
    // setMainerCanisterType.
    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): INIT - field initializer captured officialCyclesBalance = " # Nat.toText(officialCyclesBalance) # " (= Cycles.balance() " # Nat.toText(Cycles.balance()) # " + INSTALL_CODE_REFUND_BUFFER " # Nat.toText(INSTALL_CODE_REFUND_BUFFER) # "). Buffer compensates for the install_code prepay/refund: Cycles.balance() at canister_init is ~300 B lower than the true post-install balance because install_code charges its 300 B instruction-cost cap upfront and refunds unused cycles AFTER init returns. See dfinity/ic canister_manager.rs prepay/refund and forum post 19345.");

    // Diagnostic: log balance + officialCyclesBalance at strategic points so we
    // can trace exactly when officialCyclesBalance drifts from Cycles.balance()
    // (the gap is what triggers the unofficial-topup penalty in storeAndSubmitResponse).
    // The caller passes the FULL prefix string ("mAIner (#TYPE): <site> - <state>")
    // so the resulting log line follows the same grep-able convention as every
    // other D.print in the file. This matters when many mAIner logs land in one file.
    private func logCycleState(prefix : Text) : () {
        D.print(prefix # " | CYCLES balance=" # Nat.toText(Cycles.balance()) # " official=" # Nat.toText(officialCyclesBalance) # " diff(balance-official)=" # (if (Cycles.balance() >= officialCyclesBalance) { Nat.toText(Cycles.balance() - officialCyclesBalance) } else { "-" # Nat.toText(officialCyclesBalance - Cycles.balance()) }));
    };

    public shared (msg) func addCycles() : async Types.AddCyclesResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addCycles - entry, available=" # Nat.toText(Cycles.available()) # " caller=" # Principal.toText(msg.caller));
        // Accept the cycles the call is charged with
        let cyclesAdded = Cycles.accept<system>(Cycles.available());
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addCycles - Accepted " # Nat.toText(cyclesAdded) # " Cycles from caller " # Principal.toText(msg.caller));
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addCycles - after accept");

        // Unpause the mAIner if it was paused due to low cycle balance
        PAUSED_DUE_TO_LOW_CYCLE_BALANCE := false;

        // Add to official cycle balance
        if (Principal.equal(msg.caller, Principal.fromText(GAME_STATE_CANISTER_ID))) {
            // Game State can make official top ups (via its top up flow)
            officialCyclesBalance := officialCyclesBalance + cyclesAdded;
            logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addCycles - after official update (caller=GameState)");
        } else {
            logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addCycles - caller is NOT GameState - officialCyclesBalance NOT updated");
        };

        return #Ok({
            added : Bool = true;
            amount : Nat = cyclesAdded;
        });
    };

    // -------------------------------
    var SHARE_SERVICE_CANISTER_ID : Text = "bkyz2-fmaaa-aaaaa-qaaaq-cai"; // Dummy value; Only used by ShareAgent
    var shareServiceCanisterActor = actor (SHARE_SERVICE_CANISTER_ID) : Types.MainerCanister_Actor;
    
    public shared (msg) func setShareServiceCanisterId(_share_service_canister_id : Text) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        SHARE_SERVICE_CANISTER_ID := _share_service_canister_id;
        shareServiceCanisterActor := actor (SHARE_SERVICE_CANISTER_ID);
        return #Ok({ status_code = 200 });
    };

    public query (msg) func getShareServiceCanisterId() : async Text {
        if (Principal.isAnonymous(msg.caller)) {
            return "#Err(#Unauthorized)";
        };
        if (not Principal.isController(msg.caller)) {
            return "#Err(#Unauthorized)";
        };

        return SHARE_SERVICE_CANISTER_ID;
    };

    // --------------------------------------------------------------------------
// Storage & functions used by SharedService mAiner canister to manage SharedAgent mAIner canisters

    // Official mAIner Creator canisters
    var mainerCreatorCanistersStorageStable : [(Text, Types.OfficialProtocolCanister)] = [];
    transient var mainerCreatorCanistersStorage : HashMap.HashMap<Text, Types.OfficialProtocolCanister> = HashMap.HashMap(0, Text.equal, Text.hash);
    
    private func putMainerCreatorCanister(canisterAddress : Text, canisterEntry : Types.OfficialProtocolCanister) : Bool {
        mainerCreatorCanistersStorage.put(canisterAddress, canisterEntry);
        return true;
    };

    private func getMainerCreatorCanister(canisterAddress : Text) : ?Types.OfficialProtocolCanister {
        switch (mainerCreatorCanistersStorage.get(canisterAddress)) {
            case (null) { return null; };
            case (?canisterEntry) { return ?canisterEntry; };
        };
    };

    private func removeMainerCreatorCanister(canisterAddress : Text) : Bool {
        switch (mainerCreatorCanistersStorage.get(canisterAddress)) {
            case (null) { return false; };
            case (?canisterEntry) {
                let removeResult = mainerCreatorCanistersStorage.remove(canisterAddress);
                return true;
            };
        };
    };

    private func getNextMainerCreatorCanisterEntry() : ?Types.OfficialProtocolCanister {
        return mainerCreatorCanistersStorage.vals().next();
    };

    // ShareAgent Registry: Official ShareAgent canisters (owned by users)
    var shareAgentCanistersStorageStable : [(Text, Types.OfficialMainerAgentCanister)] = [];
    transient var shareAgentCanistersStorage : HashMap.HashMap<Text, Types.OfficialMainerAgentCanister> = HashMap.HashMap(0, Text.equal, Text.hash);
    var userToShareAgentsStorageStable : [(Principal, List.List<Types.OfficialMainerAgentCanister>)] = [];
    transient var userToShareAgentsStorage : HashMap.HashMap<Principal, List.List<Types.OfficialMainerAgentCanister>> = HashMap.HashMap(0, Principal.equal, Principal.hash);

    private func putShareAgentCanister(canisterAddress : Text, canisterEntry : Types.OfficialMainerAgentCanister) : Types.MainerAgentCanisterResult {
        switch (getShareAgentCanister(canisterAddress)) {
            case (null) {
                shareAgentCanistersStorage.put(canisterAddress, canisterEntry);
                switch (putUserShareAgent(canisterEntry)) {
                    case (false) {
                        return #Err(#Other("Error in putUserShareAgent"));
                    };
                    case (true) {
                        return #Ok(canisterEntry);
                    };
                };
            };
            case (?canisterEntry) { 
                //existing entry
                D.print("GameState: putShareAgentCanister - canisterEntry already exists -" # debug_show(canisterEntry));
                return #Err(#Other("Canister entry already exists"));
            }; 
        };
    };

    private func getShareAgentCanister(canisterAddress : Text) : ?Types.OfficialMainerAgentCanister {
        switch (shareAgentCanistersStorage.get(canisterAddress)) {
            case (null) { return null; };
            case (?canisterEntry) { return ?canisterEntry; };
        };
    };

    private func removeShareAgentCanister(canisterAddress : Text) : Bool {
        switch (shareAgentCanistersStorage.get(canisterAddress)) {
            case (null) { return false; };
            case (?canisterEntry) {
                let removeResult = shareAgentCanistersStorage.remove(canisterAddress);
                // TODO - Implementation: remove from userToShareAgentsStorage
                return true;
            };
        };
    };

    private func putUserShareAgent(canisterEntry : Types.OfficialMainerAgentCanister) : Bool {
        switch (getUserShareAgents(canisterEntry.ownedBy)) {
            case (null) {
                // first entry
                let userCanistersList : List.List<Types.OfficialMainerAgentCanister> = List.make<Types.OfficialMainerAgentCanister>(canisterEntry);
                userToShareAgentsStorage.put(canisterEntry.ownedBy, userCanistersList);
                return true;
            };
            case (?userCanistersList) { 
                // existing list, add entry to it
                let updatedUserCanistersList : List.List<Types.OfficialMainerAgentCanister> = List.push<Types.OfficialMainerAgentCanister>(canisterEntry, userCanistersList);
                userToShareAgentsStorage.put(canisterEntry.ownedBy, updatedUserCanistersList);
                return true;
            }; 
        };
    };

    private func getUserShareAgents(userId : Principal) : ?List.List<Types.OfficialMainerAgentCanister> {
        switch (userToShareAgentsStorage.get(userId)) {
            case (null) { return null; };
            case (?userCanistersList) { return ?userCanistersList; };
        };
    };

    // Caution: function that returns all ShareAgent canisters
    private func getShareAgents() : [Types.OfficialMainerAgentCanister] {
        var shareAgents : List.List<Types.OfficialMainerAgentCanister> = List.nil<Types.OfficialMainerAgentCanister>();
        for (userShareAgentsList in userToShareAgentsStorage.vals()) {
            shareAgents := List.append<Types.OfficialMainerAgentCanister>(userShareAgentsList, shareAgents);    
        };
        return List.toArray(shareAgents);
    };

    private func removeUserShareAgent(canisterEntry : Types.OfficialMainerAgentCanister) : Bool {
        switch (getUserShareAgents(canisterEntry.ownedBy)) {
            case (null) { return false; };
            case (?userCanistersList) { 
                //existing list, remove entry from it
                let updatedUserCanistersList : List.List<Types.OfficialMainerAgentCanister> = List.filter(userCanistersList, func(listEntry: Types.OfficialMainerAgentCanister) : Bool { listEntry.address != canisterEntry.address });
                userToShareAgentsStorage.put(canisterEntry.ownedBy, updatedUserCanistersList);
                return true;
            }; 
        };
    };

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

    //-------------------------------------------------------------------------

    // --------------------------------------------------------------------------
    // Orthogonal Persisted Data storage


    // The minimum cycle balance we want to maintain.
    //
    // Sized to keep the canister above the IC's prepay-deduction floor during
    // an upgrade or reinstall. install_code charges its full instruction-cost
    // cap UPFRONT (MAX_INSTRUCTIONS_PER_INSTALL_CODE = 300 B instructions ≈
    // 300 B cycles on a 13-node subnet) and refunds the unused portion only
    // AFTER canister_init / postupgrade returns. Snapshot create prepays
    // similarly (~130-150 B for our canister size). Combined we've observed
    // ~440 B temporarily deducted around a reinstall flow.
    //
    // If CYCLE_BALANCE_MINIMUM is below the prepay deduction, the canister
    // would dip below the freezing reserve mid-install, and outgoing
    // inter-canister calls (including the self-calls inside startTimer →
    // pullNextChallenge → GameState) start failing silently with #call_error.
    // 1 T gives comfortable headroom: ~440 B prepay + ~160 B freezing reserve
    // + ~400 B operational margin.
    //
    // Refs:
    //   - dfinity/ic subnet_config.rs (MAX_INSTRUCTIONS_PER_INSTALL_CODE)
    //   - dfinity/ic canister_manager.rs (prepay_execution_cycles / refund_unused_execution_cycles)
    //   - https://forum.dfinity.org/t/temporary-canister-cycles-balance-drop-when-upgrading-a-canister/19345
    let CYCLE_BALANCE_MINIMUM = 1 * Constants.CYCLES_TRILLION;

    // A flag for the frontend to pick up and display a message to the user
    var PAUSED_DUE_TO_LOW_CYCLE_BALANCE : Bool = false;

    // Internal functions to check if the canister has enough cycles
    private func sufficientCyclesToProcessChallenge(challenge : Types.Challenge) : Bool {
        // The ShareService canister does not Queue or Submit
        if (MAINER_AGENT_CANISTER_TYPE == #ShareService) {
            return true;
        };

        let availableCycles = Cycles.balance();
        var requiredCycles = challenge.cyclesSubmitResponse + CYCLE_BALANCE_MINIMUM;
        if (MAINER_AGENT_CANISTER_TYPE == #ShareAgent) {
            requiredCycles := requiredCycles + challenge.cyclesGenerateResponseSactrlSsctrl;
        };
        if (MAINER_AGENT_CANISTER_TYPE == #Own) {
            // TODO: do calculation based on actual setting for LOW, MEDIUM, HIGH
            requiredCycles := requiredCycles + challenge.cyclesGenerateResponseOwnctrlGs + challenge.cyclesGenerateResponseOwnctrlOwnllmHIGH;
        };
        if (availableCycles < requiredCycles) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): CYCLE BALANCE TOO LOW TO PROCESS CHALLENGE:");
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): requiredCycles  = " # debug_show(requiredCycles));
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): availableCycles = " # debug_show(availableCycles));
            return false;
        };
        return true;
    };

    private func sufficientCyclesToSubmit(cyclesSubmitResponse : Nat) : Bool {
        // The ShareService canister does not submit
        if (MAINER_AGENT_CANISTER_TYPE == #ShareService) {
            return true;
        };

        let availableCycles = Cycles.balance();
        let requiredCycles = cyclesSubmitResponse + CYCLE_BALANCE_MINIMUM;
        if (availableCycles < requiredCycles) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): CYCLE BALANCE TOO LOW TO SUBMIT RESPONSE TO GAMESTATE:");
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): requiredCycles  = " # debug_show(requiredCycles));
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): availableCycles = " # debug_show(availableCycles));
            return false;
        };
        return true;
    };

    public query (msg) func getIssueFlagsAdmin() : async Types.IssueFlagsRetrievalResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // Check if caller has AdminQuery permission
        if (not hasAdminRole(msg.caller, #AdminQuery)) {
            return #Err(#Unauthorized);
        };
        let response : Types.IssueFlagsRecord = {
            lowCycleBalance = PAUSED_DUE_TO_LOW_CYCLE_BALANCE;
        };
        return #Ok(response);
    };

    // Statistics
    var TOTAL_MAINER_CYCLES_BURNT : Nat = 100 * Constants.CYCLES_BILLION; // Initial value represents costs for creating this canister

    private func increaseTotalCyclesBurnt(cyclesBurntToAdd : Nat) : Bool {
        TOTAL_MAINER_CYCLES_BURNT := TOTAL_MAINER_CYCLES_BURNT + cyclesBurntToAdd;
        return true;
    };

    let CYCLES_BURNT_RESPONSE_GENERATION : Nat = 200 * Constants.CYCLES_BILLION;

    // This is just a placeholder to be used until the startTimerExecution is called.
    let CYCLES_BURN_RATE_DEFAULT : Types.CyclesBurnRate = {
        cycles : Nat = 1 * Constants.CYCLES_TRILLION;
        timeInterval : Types.TimeInterval = #Daily;
    };

    public query (msg) func getMainerStatisticsAdmin() : async Types.StatisticsRetrievalResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // Check if caller has AdminQuery permission
        if (not hasAdminRole(msg.caller, #AdminQuery)) {
            return #Err(#Unauthorized);
        };
        var cyclesBurnRateToReturn : Types.CyclesBurnRate = CYCLES_BURN_RATE_DEFAULT;
        switch (getCurrentAgentSettings()) {
            case (null) {};
            case (?agentSettings) {
                cyclesBurnRateToReturn := cyclesBurnRateFromGameState;
            };
        };
        let response : Types.StatisticsRecord = {
            totalCyclesBurnt = TOTAL_MAINER_CYCLES_BURNT;
            cycleBalance = Cycles.balance();
            cyclesBurnRate = cyclesBurnRateToReturn;
        };
        return #Ok(response);
    };

    // Returns both Cycles.balance() AND officialCyclesBalance in a single
    // atomic query. Useful for diagnosing unofficial-topup penalty triggers
    // (the penalty fires when officialCyclesBalance < Cycles.balance()).
    public query (msg) func getOfficialCyclesBalanceAdmin() : async Types.CycleBalanceResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not hasAdminRole(msg.caller, #AdminQuery)) {
            return #Err(#Unauthorized);
        };
        return #Ok({
            cycleBalance = Cycles.balance();
            officialCyclesBalance = officialCyclesBalance;
        });
    };

    // timer IDs for reporting purposes (actual stopping uses the buffers)
    // Note: they're stable for historical reasons; could be transient because timers do not survive upgrades
    //       is ok, because startTimer & stopTimer functions will reset them
    var initialTimerId1 : ?Timer.TimerId = null;  // For reporting only
    var recurringTimerId1 : ?Timer.TimerId = null;
    var recurringTimerId2 : ?Timer.TimerId = null;

    // Configurable buffer max size for timer IDs
    var TIMER_BUFFER_MAX_SIZE : Nat = 4;

    // Non-stable buffers to track timer IDs created since last upgrade
    // These reset to empty after each upgrade, which is the desired behavior
    // FIFO buffers with configurable max length
    transient let bufferTimerId1 = Buffer.Buffer<Timer.TimerId>(TIMER_BUFFER_MAX_SIZE);
    transient let bufferTimerId2 = Buffer.Buffer<Timer.TimerId>(TIMER_BUFFER_MAX_SIZE);

    // Helper function to add timer ID using FIFO approach with configurable max length
    private func addTimerToBuffer(buffer : Buffer.Buffer<Timer.TimerId>, timerId : Timer.TimerId) : () {
        if (buffer.size() >= TIMER_BUFFER_MAX_SIZE) {
            // Remove the oldest entry (FIFO)
            ignore buffer.removeLast();
        };
        // Add new timer ID to the beginning
        buffer.insert(0, timerId);
    };

    // Record of settings
    var agentSettings : List.List<Types.MainerAgentSettings> = List.nil<Types.MainerAgentSettings>();

    private func putAgentSettings(settingsEntry : Types.MainerAgentSettings) : Bool {
        agentSettings := List.push<Types.MainerAgentSettings>(settingsEntry, agentSettings);
        return true;
    };

    private func getCurrentAgentSettings() : ?Types.MainerAgentSettings {
        return List.get<Types.MainerAgentSettings>(agentSettings, 0);
    };

    public shared query (msg) func getCurrentAgentSettingsAdmin() : async Types.MainerAgentSettingsResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        switch (getCurrentAgentSettings()) {
            case (null) {
                return #Err(#Other("No agent settings found"));
            };
            case (?settings) {
                return #Ok(settings);
            };
        };
    };

    public shared query (msg) func getAgentSettingsAdmin() : async Types.MainerAgentSettingsListResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let settingsArray = List.toArray<Types.MainerAgentSettings>(agentSettings);
        return #Ok(settingsArray);
    };

    // Record of timers since last upgrade
    transient var agentTimers : List.List<Types.MainerAgentTimers> = List.nil<Types.MainerAgentTimers>();

    private func putAgentTimers(timersEntry : Types.MainerAgentTimers) : Bool {
        agentTimers := List.push<Types.MainerAgentTimers>(timersEntry, agentTimers);
        return true;
    };

    private func getCurrentAgentTimers() : ?Types.MainerAgentTimers {
        return List.get<Types.MainerAgentTimers>(agentTimers, 0);
    };

    public shared query (msg) func getCurrentAgentTimersAdmin() : async Types.MainerAgentTimersResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        switch (getCurrentAgentTimers()) {
            case (null) {
                return #Err(#Other("No agent timers found"));
            };
            case (?timers) {
                return #Ok(timers);
            };
        };
    };

    public shared query (msg) func getAgentTimersAdmin() : async Types.MainerAgentTimersListResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let timersArray = List.toArray<Types.MainerAgentTimers>(agentTimers);
        return #Ok(timersArray);
    };

    // FIFO queue of challenges: retrieved from GameState; to be processed
    var MAX_CHALLENGES_IN_QUEUE : Nat = 5;
    // Self-cleanup thresholds for the challenge queue, ported from the
    // previously off-chain daily cleanup job. The queue is wiped when either
    // condition holds (see cleanupChallengeQueueIfNeeded).
    let CHALLENGE_QUEUE_RESET_LENGTH_THRESHOLD : Nat = 4;
    let CHALLENGE_QUEUE_STALENESS_NANOS : Nat64 = 86_400_000_000_000; // 24 hours
    var challengeQueue : List.List<Types.ChallengeQueueInput> = List.nil<Types.ChallengeQueueInput>();

    private func pushChallengeQueue(challengeQueueInput : Types.ChallengeQueueInput) : Bool {
        challengeQueue := List.push<Types.ChallengeQueueInput>(challengeQueueInput, challengeQueue);
        return true;
    };

    private func popChallengeQueue() : ?Types.ChallengeQueueInput {
        let (head, tail) = List.pop(challengeQueue);
        challengeQueue := tail;
        head;
    };

    private func getChallengeQueueFromId(challengeQueuedId : Text) : ?Types.ChallengeQueueInput {
        return List.find<Types.ChallengeQueueInput>(challengeQueue, func(challengeQueueInput : Types.ChallengeQueueInput) : Bool { challengeQueueInput.challengeQueuedId == challengeQueuedId });
    };

    private func removeChallengeQueue(challengeQueuedId : Text) : Bool {
        challengeQueue := List.filter(challengeQueue, func(challengeQueueInputEntry : Types.ChallengeQueueInput) : Bool { challengeQueueInputEntry.challengeQueuedId != challengeQueuedId });
        return true;
    };

    // Returns the reason for a reset, or null if no reset is needed.
    // Mirrors the off-chain rules: length >= threshold, OR all entries older
    // than the staleness window.
    private func challengeQueueResetReason() : ?Text {
        let size = List.size<Types.ChallengeQueueInput>(challengeQueue);
        if (size >= CHALLENGE_QUEUE_RESET_LENGTH_THRESHOLD) {
            return ?("length " # debug_show(size) # " >= " # debug_show(CHALLENGE_QUEUE_RESET_LENGTH_THRESHOLD));
        };
        if (size == 0) { return null };
        let now : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
        let allStale = List.all<Types.ChallengeQueueInput>(
            challengeQueue,
            func(e : Types.ChallengeQueueInput) : Bool {
                now >= e.challengeQueuedTimestamp + CHALLENGE_QUEUE_STALENESS_NANOS
            }
        );
        if (allStale) { return ?("all " # debug_show(size) # " entries older than 24h") };
        return null;
    };

    private func cleanupChallengeQueueIfNeeded() : () {
        switch (challengeQueueResetReason()) {
            case (null) { };
            case (?reason) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): cleanupChallengeQueueIfNeeded - resetting challengeQueue; reason = " # reason);
                challengeQueue := List.nil<Types.ChallengeQueueInput>();
            };
        };
    };

    public query (msg) func getChallengeQueueAdmin() : async Types.ChallengeQueueInputsResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not hasAdminRole(msg.caller, #AdminQuery)) {
            return #Err(#Unauthorized);
        };
        let challengeQueueInputs : [Types.ChallengeQueueInput] = List.toArray<Types.ChallengeQueueInput>(challengeQueue);
        return #Ok(challengeQueueInputs);
    };

    public shared (msg) func resetChallengeQueueAdmin() : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not hasAdminRole(msg.caller, #AdminUpdate)) {
            return #Err(#Unauthorized);
        };
        challengeQueue := List.nil<Types.ChallengeQueueInput>();
        return #Ok({ status_code = 200 });
    };

    // Record of submitted responses (capped to bound stable memory growth)
    let MAX_SUBMITTED_RESPONSES : Nat = 100;
    var submittedResponses : List.List<Types.ChallengeResponseSubmission> = List.nil<Types.ChallengeResponseSubmission>();

    private func putSubmittedResponse(responseEntry : Types.ChallengeResponseSubmission) : Bool {
        submittedResponses := List.push<Types.ChallengeResponseSubmission>(responseEntry, submittedResponses);
        submittedResponses := List.take<Types.ChallengeResponseSubmission>(submittedResponses, MAX_SUBMITTED_RESPONSES);
        return true;
    };

    private func getSubmittedResponse(submissionId : Text) : ?Types.ChallengeResponseSubmission {
        return List.find<Types.ChallengeResponseSubmission>(submittedResponses, func(responseEntry : Types.ChallengeResponseSubmission) : Bool { responseEntry.submissionId == submissionId });
    };

    private func getSubmittedResponses() : [Types.ChallengeResponseSubmission] {
        return List.toArray<Types.ChallengeResponseSubmission>(submittedResponses);
    };

    private func getLastSubmittedResponses(numberToRetrieve : Nat) : [Types.ChallengeResponseSubmission] {
        return List.toArray<Types.ChallengeResponseSubmission>(List.take<Types.ChallengeResponseSubmission>(submittedResponses, numberToRetrieve));
    };

    private func removeSubmittedResponse(submissionId : Text) : Bool {
        submittedResponses := List.filter(submittedResponses, func(responseEntry : Types.ChallengeResponseSubmission) : Bool { responseEntry.submissionId != submissionId });
        return true;
    };

    public query (msg) func getSubmittedResponsesAdmin() : async Types.ChallengeResponseSubmissionsResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let submissions : [Types.ChallengeResponseSubmission] = getSubmittedResponses();
        return #Ok(submissions);
    };

    public query (msg) func getRecentSubmittedResponsesAdmin() : async Types.ChallengeResponseSubmissionsResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let submissions : [Types.ChallengeResponseSubmission] = getLastSubmittedResponses(5);
        return #Ok(submissions);
    };

    // -------------------------------------------------------------------------------
    // The C++ LLM canisters that can be called

    var llmCanistersStable : [Text] = [];
    private transient var llmCanisters : Buffer.Buffer<Types.LLMCanister> = Buffer.fromArray([]);

    // Round-robin load balancer for LLM canisters to call
    private transient var roundRobinIndex : Nat = 0;
    private transient var roundRobinUseAll : Bool = true;
    private transient var roundRobinLLMs : Nat = 0; // Only used when roundRobinUseAll is false

    public shared query (msg) func get_llm_canisters() : async Types.LlmCanistersRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let llmCanisterIds : [Types.CanisterAddress] = Buffer.toArray(
            Buffer.map<Types.LLMCanister, Text>(llmCanisters, func (llm : Types.LLMCanister) : Text {
                Principal.toText(Principal.fromActor(llm))
            })
        );
        return #Ok({ 
            llmCanisterIds = llmCanisterIds;
            roundRobinUseAll = roundRobinUseAll;
            roundRobinLLMs = roundRobinLLMs;
        });
    };

    public shared (msg) func reset_llm_canisters() : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "):  reset_llm_canisters - Resetting all LLM canisters & round-robin state");
        llmCanisters.clear();
        resetRoundRobinLLMs_();
        return #Ok({ status_code = 200 });
    };

    public shared (msg) func add_llm_canister(llmCanisterIdRecord : Types.CanisterIDRecord) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "):  add_llm_canister - Adding llm: " # llmCanisterIdRecord.canister_id);
        let llmCanister = actor (llmCanisterIdRecord.canister_id) : Types.LLMCanister;
        llmCanisters.add(llmCanister);
        return #Ok({ status_code = 200 });
    };

    public shared (msg) func remove_llm_canister(llmCanisterIdRecord : Types.CanisterIDRecord) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let targetCanisterText = llmCanisterIdRecord.canister_id;

        // Remove the LLM canister if found
        for (i in Iter.range(0, llmCanisters.size())) {
            let existing = llmCanisters.getOpt(i);
            switch (existing) {
                case (?item) {
                    let principalText = Principal.toText(Principal.fromActor(item));
                    if (principalText == targetCanisterText) {
                        ignore llmCanisters.remove(i);

                        // For safety against out-of-bounds, reset roundRobinIndex
                        roundRobinIndex := 0;

                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "):  remove_llm_canister - Removed llm: " # targetCanisterText);
                        return #Ok({ status_code = 200 });
                    };
                };
                case null {}; // Skip if none
            };
        };
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "):  remove_llm_canister - Cannot find llm in the list: " # targetCanisterText);
        return #Err(#StatusCode(404)); // Not found
    };


    // Admin function to reset roundRobinLLMs
    public shared (msg) func resetRoundRobinLLMs() : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        resetRoundRobinLLMs_();
        return #Ok({ status_code = 200 });
    };
    private func resetRoundRobinLLMs_() {
        roundRobinUseAll := true;
        roundRobinLLMs := 0; // Use all LLMs
        roundRobinIndex := 0;
    };

    // Admin function to set roundRobinLLMs
    public shared (msg) func setRoundRobinLLMs(_roundRobinLLMs : Nat) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        roundRobinUseAll := false;
        roundRobinLLMs := _roundRobinLLMs;
        roundRobinIndex := 0;

        return #Ok({ status_code = 200 });
    };

    public shared query (msg) func whoami() : async Principal {
        return msg.caller;
    };

    // Function to verify that canister is up & running
    public shared query func health() : async Types.StatusCodeRecordResult {
        if (MAINTENANCE) {
            return #Err(#Other("mAIner is under maintenance"));
        };
        return #Ok({ status_code = 200 });
    };

    // Function to verify that canister is ready for inference
    public shared (msg) func ready() : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        for (llmCanister in llmCanisters.vals()) {
            try {
                let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.ready();
                switch (statusCodeRecordResult) {
                    case (#Err(_)) { return statusCodeRecordResult };
                    case (_) {
                        // If it's not an error, do nothing and continue the loop
                    };
                };
            } catch (_) {
                // Handle errors, such as llm canister not responding
                return #Err(#Other("Failed to call ready endpoint of llm canister = " # Principal.toText(Principal.fromActor(llmCanister))));
            };
        };
        return #Ok({ status_code = 200 });
    };

    // Admin function to verify that caller is a controller of this canister
    public shared query (msg) func amiController() : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        return #Ok({ status_code = 200 });
    };

    // Admin function to verify that mainer_ctrlb_canister is a controller of all the llm canisters
    public shared (msg) func checkAccessToLLMs() : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Call all the llm canisters to verify that mainer_ctrlb_canister is a controller
        for (llmCanister in llmCanisters.vals()) {
            try {
                let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.check_access();
                switch (statusCodeRecordResult) {
                    case (#Err(_)) { return statusCodeRecordResult };
                    case (_) {
                        // If it's not an error, do nothing and continue the loop
                    };
                };
            } catch (_) {
                // Handle errors, such as llm canister not responding
                return #Err(#Other("Call failed to llm canister = " # Principal.toText(Principal.fromActor(llmCanister))));
            };
        };
        return #Ok({ status_code = 200 });
    };

    // Alternative function: get_llm_canisters
    public query (msg) func getLLMCanisterIds() : async Types.CanisterAddressesResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        var llmCanisterIds : List.List<Types.CanisterAddress> = List.nil<Types.CanisterAddress>();

        for (llmCanister in llmCanisters.vals()) {
            try {
                llmCanisterIds := List.push<Types.CanisterAddress>(Principal.toText(Principal.fromActor(llmCanister)), llmCanisterIds);
            } catch (error : Error) {
                return #Err(#Other("Call failed to load llm canisters = " # Principal.toText(Principal.fromActor(llmCanister)) # Error.message(error)));
            };
        };

        return #Ok(List.toArray(llmCanisterIds));
    };

    // Settings

    private func areAgentSettingsUpdateable() : Bool {
        switch (getCurrentAgentSettings()) {
            case (null) {
                // first update, so all good
                return true;
            };
            case (?agentSettings) {
                // Check that last update was more than a day ago (one update per day is allowed)
                let currentTime = Nat64.fromNat(Int.abs(Time.now()));
                let oneDayNanos : Nat64 = 86_400_000_000_000; // 24h in nanoseconds

                if (currentTime - agentSettings.creationTimestamp < oneDayNanos) {
                    return false;
                };
                return true;            
            };
        };
    };

    public shared (msg) func canAgentSettingsBeUpdated() : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (areAgentSettingsUpdateable()) {
            case (true) {
                return #Ok({ status_code = 200 }); 
            };
            case (false) {
                return #Err(#Other("Last update is not yet 24h ago."));           
            };
        };
    };

    public shared (msg) func timeToNextAgentSettingsUpdate() : async Types.NatResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (getCurrentAgentSettings()) {
            case (null) {
                // first update, so all good
                return #Ok(0);
            };
            case (?agentSettings) {
                // one update per day is allowed
                let currentTime = Nat64.fromNat(Int.abs(Time.now()));
                let oneDayNanos : Nat64 = 86_400_000_000_000; // 24h in nanoseconds

                if (currentTime - agentSettings.creationTimestamp >= oneDayNanos) {
                    return #Ok(0); // last update was more than a day, so may be updated now
                };
                let remainingTime = oneDayNanos - (currentTime - agentSettings.creationTimestamp);
                return #Ok(Nat64.toNat(remainingTime));
            };
        };        
    };

    public shared (msg) func updateAgentSettings(settingsInput : Types.MainerAgentSettingsInput) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (settingsInput.cyclesBurnRate) {
            case (#Low) {
                // continue
            };
            case (#Mid) {
                // continue
            };
            case (#High) {
                // continue
            };
            case (#VeryHigh) {
                // continue
            };
            case (#Custom(customCyclesBurnRate)) {
                // currently not supported
                return #Err(#StatusCode(400));
            };
            case (_) {
                return #Err(#StatusCode(400));
            };
        };
        switch (areAgentSettingsUpdateable()) {
            case (true) {
                // continue
            };
            case (false) {
                return #Err(#Other("Last update is not yet 24h ago."));           
            };
        };

        let settingsEntry : Types.MainerAgentSettings = {
            cyclesBurnRate : Types.CyclesBurnRateDefault = settingsInput.cyclesBurnRate;
            creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            createdBy : Principal = msg.caller;
        };
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): updateAgentSettings - settingsEntry = " # debug_show(settingsEntry));
        let putResult = putAgentSettings(settingsEntry);
        if (not putResult) {
            return #Err(#StatusCode(500));
        };

        // Restart the timers to apply the new settings
        let stopResult = try {
            await stopTimerExecution();
        } catch (error) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): updateAgentSettings - stopTimerExecution threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
            return #Err(#Other("stopTimerExecution failed: " # Error.message(error)));
        };
        ignore startTimerExecution(msg.caller, "updateAgentSettings");

        return #Ok({ status_code = 200 });
    };

    // Respond to challenges

    private func processRespondingToChallenge(challengeQueueInput : Types.ChallengeQueueInput) : async () {
        // Generate the response for the challengeQueueInput and:
        // (-) 'Own' canister submits it to GameState
        // (-) 'ShareService' canister sends it back to the 'ShareAgent' canister which submits it to GameState
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processRespondingToChallenge - entry");

        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processRespondingToChallenge - calling respondToChallengeDoIt_");
        let respondingResult : Types.ChallengeResponseResult = try {
            await respondToChallengeDoIt_(challengeQueueInput);
        } catch (error) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processRespondingToChallenge - respondToChallengeDoIt_ threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
            return;
        };
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processRespondingToChallenge - returned from respondToChallengeDoIt_");
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondingResult = " # debug_show (respondingResult));

        switch (respondingResult) {
            case (#Err(error)) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processRespondingToChallenge error" # debug_show (error));
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): WARNING - ShareService is likely broken & admin must call resetChallengeQueueAdmin of the ShareAgent " # debug_show(challengeQueueInput.challengeQueuedBy) # " once the ShareService is fixed");
                // NOTE:
                // - We are NOT sending anything back to the ShareAgent.
                // - This is the safest approach to avoid sucking all cycles out of the ShareAgent in case the ShareService is not working
                // - The ShareAgent's challengeQueue will simply fill up with challenges that cannot be processed
                //
                // -> Admin must run a script to reset the challengeQueue of all the ShareAgent caniseters once the ShareService is fixed
            };
            case (#Ok(respondingOutput : Types.ChallengeResponse)) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondingOutput = " # debug_show (respondingOutput));
                ignore increaseTotalCyclesBurnt(CYCLES_BURNT_RESPONSE_GENERATION);
                
                var submittedBy : Principal = Principal.fromActor(this);
                if (MAINER_AGENT_CANISTER_TYPE == #ShareService) {
                    // Prefill this, so the ShareAgent canister can submit it with the correct Principal
                    submittedBy := challengeQueueInput.challengeQueuedBy;
                };
                let challengeResponseSubmissionInput : Types.ChallengeResponseSubmissionInput = {
                    challengeTopic : Text = challengeQueueInput.challengeTopic;
                    challengeTopicId : Text = challengeQueueInput.challengeTopicId;
                    challengeTopicCreationTimestamp : Nat64 = challengeQueueInput.challengeTopicCreationTimestamp;
                    challengeTopicStatus : Types.ChallengeTopicStatus = challengeQueueInput.challengeTopicStatus;
                    cyclesGenerateChallengeGsChctrl : Nat = challengeQueueInput.cyclesGenerateChallengeGsChctrl;
                    cyclesGenerateChallengeChctrlChllm : Nat = challengeQueueInput.cyclesGenerateChallengeChctrlChllm;
                    challengeQuestion : Text = challengeQueueInput.challengeQuestion;
                    challengeQuestionSeed : Nat32 = challengeQueueInput.challengeQuestionSeed;
                    mainerPromptId : Text = challengeQueueInput.mainerPromptId;
                    mainerMaxContinueLoopCount : Nat = challengeQueueInput.mainerMaxContinueLoopCount;
                    mainerNumTokens : Nat64 = challengeQueueInput.mainerNumTokens;
                    mainerTemp : Float = challengeQueueInput.mainerTemp;
                    judgePromptId : Text = challengeQueueInput.judgePromptId;
                    challengeId : Text = challengeQueueInput.challengeId;
                    challengeCreationTimestamp : Nat64 = challengeQueueInput.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = challengeQueueInput.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = challengeQueueInput.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = challengeQueueInput.challengeClosedTimestamp;
                    cyclesSubmitResponse : Nat = challengeQueueInput.cyclesSubmitResponse;
                    protocolOperationFeesCut : Nat = challengeQueueInput.protocolOperationFeesCut;
                    cyclesGenerateResponseSactrlSsctrl : Nat = challengeQueueInput.cyclesGenerateResponseSactrlSsctrl;
                    cyclesGenerateResponseSsctrlGs : Nat = challengeQueueInput.cyclesGenerateResponseSsctrlGs;
                    cyclesGenerateResponseSsctrlSsllm : Nat = challengeQueueInput.cyclesGenerateResponseSsctrlSsllm;
                    cyclesGenerateResponseOwnctrlGs : Nat = challengeQueueInput.cyclesGenerateResponseOwnctrlGs;
                    cyclesGenerateResponseOwnctrlOwnllmLOW : Nat = challengeQueueInput.cyclesGenerateResponseOwnctrlOwnllmLOW;
                    cyclesGenerateResponseOwnctrlOwnllmMEDIUM : Nat = challengeQueueInput.cyclesGenerateResponseOwnctrlOwnllmMEDIUM;
                    cyclesGenerateResponseOwnctrlOwnllmHIGH : Nat = challengeQueueInput.cyclesGenerateResponseOwnctrlOwnllmHIGH;
                    challengeQueuedId : Text = challengeQueueInput.challengeQueuedId;
                    challengeQueuedBy : Principal = challengeQueueInput.challengeQueuedBy;
                    challengeQueuedTo : Principal = challengeQueueInput.challengeQueuedTo;
                    challengeQueuedTimestamp : Nat64 = challengeQueueInput.challengeQueuedTimestamp;
                    challengeAnswer : Text = respondingOutput.generatedResponseText;
                    challengeAnswerSeed : Nat32 = respondingOutput.generationSeed;
                    submittedBy : Principal = submittedBy;
                };

                if (MAINER_AGENT_CANISTER_TYPE == #ShareService) {
                    // Send the response back to the ShareAgent canister
                    ignore sendResponseToShareAgent(challengeResponseSubmissionInput);
                } else {
                    ignore storeAndSubmitResponse(challengeResponseSubmissionInput);
                };
            };
        };
    };

    private func sendResponseToShareAgent(challengeResponseSubmissionInput : Types.ChallengeResponseSubmissionInput) : async () {
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): sendResponseToShareAgent - entry");
        let shareAgentCanisterActor = actor (Principal.toText(challengeResponseSubmissionInput.challengeQueuedBy)) : Types.MainerCanister_Actor;
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): sendResponseToShareAgent- calling addChallengeResponseToShareAgent of shareAgentCanisterActor = " # Principal.toText(Principal.fromActor(shareAgentCanisterActor)));
        let result : Types.StatusCodeRecordResult = try {
            await shareAgentCanisterActor.addChallengeResponseToShareAgent(challengeResponseSubmissionInput);
        } catch (error) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): sendResponseToShareAgent - addChallengeResponseToShareAgent threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
            return;
        };
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): sendResponseToShareAgent - after await (any refund visible here)");
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): sendResponseToShareAgent - returned from addChallengeResponseToShareAgent.challengeResponseSubmissionInput with result = " # debug_show(result));
    };

    // Callback function of ShareAgent canister to receive the challengeResponseSubmissionInput from the ShareService canister
    public shared (msg) func addChallengeResponseToShareAgent(challengeResponseSubmissionInput : Types.ChallengeResponseSubmissionInput) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addChallengeResponseToShareAgent - entry, available=" # Nat.toText(Cycles.available()) # " caller=" # Principal.toText(msg.caller));

        // Only ShareAgent can handle this call
        if (MAINER_AGENT_CANISTER_TYPE != #ShareAgent) {
            return #Err(#Unauthorized);
        };

        // Only the ShareService canister may call this
        if (Principal.toText(msg.caller) != SHARE_SERVICE_CANISTER_ID) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addChallengeResponseToShareAgent - caller is not a ShareService");
            return #Err(#Unauthorized);
        };
        // Check that the record looks correct
        
        // queuedBy must be this canister
        if (challengeResponseSubmissionInput.challengeQueuedBy != Principal.fromActor(this)) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addChallengeResponseToShareAgent - challengeQueuedBy error");
            return #Err(#Unauthorized);
        };

        // queuedTo must be the caller 
        if (challengeResponseSubmissionInput.challengeQueuedTo != msg.caller) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addChallengeResponseToShareAgent - challengeQueuedTo error");
            return #Err(#Unauthorized);
        };

        // The entry must exist in the ShareAgent canisters own ChallengeQueue
        let challengeQueuedId = challengeResponseSubmissionInput.challengeQueuedId;
        let challengeQueueInput : ?Types.ChallengeQueueInput = getChallengeQueueFromId(challengeQueuedId);
        if (challengeQueueInput == null) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addChallengeResponseToShareAgent - challengeQueuedId error");
            return #Err(#Unauthorized);
        };

        // Ok, all looks kosher
        let _ = removeChallengeQueue(challengeQueuedId);
        ignore storeAndSubmitResponse(challengeResponseSubmissionInput);
        
        return #Ok({ status_code = 200 });
    };

    private func storeAndSubmitResponse(challengeResponseSubmissionInput : Types.ChallengeResponseSubmissionInput) : async () {
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - entry");
        // Check if the canister still has enough cycles to submit it
        // Check against the number sent by the GameState for this particular Challenge
        if (not sufficientCyclesToSubmit(challengeResponseSubmissionInput.cyclesSubmitResponse)) {
            // Note: do not pause, to avoid blocking the canister in case of a single challenge with a really high cycle requirement
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - insufficientCyclesToSubmit");
            return;
        };

        // Check if there were any unofficial cycle top ups and if so pay the appropriate fee for the Protocol's operational expenses
        var cyclesToSend = challengeResponseSubmissionInput.cyclesSubmitResponse;
        let currentCyclesBalance = Cycles.balance();
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - UNOFFICIAL CHECK: currentCyclesBalance=" # Nat.toText(currentCyclesBalance) # " officialCyclesBalance=" # Nat.toText(officialCyclesBalance) # " unofficialDetected=" # Bool.toText(officialCyclesBalance < currentCyclesBalance) # " (if true: diff=" # (if (currentCyclesBalance >= officialCyclesBalance) { Nat.toText(currentCyclesBalance - officialCyclesBalance) } else { "0" }) # ", protocolOperationFeesCut=" # Nat.toText(challengeResponseSubmissionInput.protocolOperationFeesCut) # ")");
        if (officialCyclesBalance < currentCyclesBalance) {
            // Unofficial top ups were made, thus pay the fee for these top ups to Game State now as a share of the balances difference
            // Use protocolOperationFeesCut that was sent by the GameState canister with the Challenge
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - Unofficial top ups were made");
            try {
                let DIRECT_CYCLES_TOPUP_MULTIPLIER : Nat = 9;
                let cyclesForOperationalExpenses = (currentCyclesBalance - officialCyclesBalance) * (challengeResponseSubmissionInput.protocolOperationFeesCut * DIRECT_CYCLES_TOPUP_MULTIPLIER) / 100;
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - Increasing cycles for operational expenses = " # debug_show(cyclesForOperationalExpenses));
                cyclesToSend := cyclesToSend + cyclesForOperationalExpenses;
            } catch (error : Error) {
                // Continue nevertheless
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - catch error when calculating fee to pay for unofficial top ups : ");
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - error: " # Error.message(error));
            };
        };

        // Add the required amount of cycles
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - calling Cycles.add for = " # debug_show(cyclesToSend) # " Cycles");
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - before Cycles.add for GameState");
        Cycles.add<system>(cyclesToSend);

        let gameStateCanisterActor = actor (GAME_STATE_CANISTER_ID) : Types.GameStateCanister_Actor;
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - calling submitChallengeResponse of gameStateCanisterActor = " # Principal.toText(Principal.fromActor(gameStateCanisterActor)));
        let submitMetadaResult : Types.ChallengeResponseSubmissionMetadataResult = try {
            await gameStateCanisterActor.submitChallengeResponse(challengeResponseSubmissionInput);
        } catch (error) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - submitChallengeResponse threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
            return;
        };
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse  - returned from gameStateCanisterActor.submitChallengeResponse");
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - after submitChallengeResponse await (any GameState refund visible here)");
        switch (submitMetadaResult) {
            case (#Err(error)) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - submitMetada error");
                D.print(debug_show (error));
            };
            case (#Ok(submitMetada : Types.ChallengeResponseSubmissionMetadata)) {
                // Successfully submitted to Game State
                let challengeResponseSubmission : Types.ChallengeResponseSubmission = {
                    challengeTopic : Text = challengeResponseSubmissionInput.challengeTopic;
                    challengeTopicId : Text = challengeResponseSubmissionInput.challengeTopicId;
                    challengeTopicCreationTimestamp : Nat64 = challengeResponseSubmissionInput.challengeTopicCreationTimestamp;
                    challengeTopicStatus : Types.ChallengeTopicStatus = challengeResponseSubmissionInput.challengeTopicStatus;
                    cyclesGenerateChallengeGsChctrl : Nat = challengeResponseSubmissionInput.cyclesGenerateChallengeGsChctrl;
                    cyclesGenerateChallengeChctrlChllm : Nat = challengeResponseSubmissionInput.cyclesGenerateChallengeChctrlChllm;
                    challengeQuestion : Text = challengeResponseSubmissionInput.challengeQuestion;
                    challengeQuestionSeed : Nat32 = challengeResponseSubmissionInput.challengeQuestionSeed;
                    mainerPromptId : Text = challengeResponseSubmissionInput.mainerPromptId;
                    mainerMaxContinueLoopCount : Nat = challengeResponseSubmissionInput.mainerMaxContinueLoopCount;
                    mainerNumTokens : Nat64 = challengeResponseSubmissionInput.mainerNumTokens;
                    mainerTemp : Float = challengeResponseSubmissionInput.mainerTemp;
                    judgePromptId : Text = challengeResponseSubmissionInput.judgePromptId;
                    challengeId : Text = challengeResponseSubmissionInput.challengeId;
                    challengeCreationTimestamp : Nat64 = challengeResponseSubmissionInput.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = challengeResponseSubmissionInput.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = challengeResponseSubmissionInput.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = challengeResponseSubmissionInput.challengeClosedTimestamp;
                    cyclesSubmitResponse : Nat = challengeResponseSubmissionInput.cyclesSubmitResponse;
                    protocolOperationFeesCut : Nat = challengeResponseSubmissionInput.protocolOperationFeesCut;
                    cyclesGenerateResponseSactrlSsctrl : Nat = challengeResponseSubmissionInput.cyclesGenerateResponseSactrlSsctrl;
                    cyclesGenerateResponseSsctrlGs : Nat = challengeResponseSubmissionInput.cyclesGenerateResponseSsctrlGs;
                    cyclesGenerateResponseSsctrlSsllm : Nat = challengeResponseSubmissionInput.cyclesGenerateResponseSsctrlSsllm;
                    cyclesGenerateResponseOwnctrlGs : Nat = challengeResponseSubmissionInput.cyclesGenerateResponseOwnctrlGs;
                    cyclesGenerateResponseOwnctrlOwnllmLOW : Nat = challengeResponseSubmissionInput.cyclesGenerateResponseOwnctrlOwnllmLOW;
                    cyclesGenerateResponseOwnctrlOwnllmMEDIUM : Nat = challengeResponseSubmissionInput.cyclesGenerateResponseOwnctrlOwnllmMEDIUM;
                    cyclesGenerateResponseOwnctrlOwnllmHIGH : Nat = challengeResponseSubmissionInput.cyclesGenerateResponseOwnctrlOwnllmHIGH;
                    challengeQueuedId : Text = challengeResponseSubmissionInput.challengeQueuedId;
                    challengeQueuedBy : Principal = challengeResponseSubmissionInput.challengeQueuedBy;
                    challengeQueuedTo : Principal = challengeResponseSubmissionInput.challengeQueuedTo;
                    challengeQueuedTimestamp : Nat64 = challengeResponseSubmissionInput.challengeQueuedTimestamp;
                    challengeAnswer : Text = challengeResponseSubmissionInput.challengeAnswer;
                    challengeAnswerSeed : Nat32 = challengeResponseSubmissionInput.challengeAnswerSeed;
                    submittedBy : Principal = challengeResponseSubmissionInput.submittedBy;
                    submissionId : Text = submitMetada.submissionId;
                    submittedTimestamp : Nat64 = submitMetada.submittedTimestamp;
                    submissionStatus : Types.ChallengeResponseSubmissionStatus = submitMetada.submissionStatus;
                    cyclesGenerateScoreGsJuctrl : Nat = submitMetada.cyclesGenerateScoreGsJuctrl;
                    cyclesGenerateScoreJuctrlJullm : Nat = submitMetada.cyclesGenerateScoreJuctrlJullm;
                };
                // Update official cycles balance after the successful submission
                // Any outstanding top up fees were paid and it's reflected in cyclesToSend
                officialCyclesBalance := currentCyclesBalance - cyclesToSend;
                logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - after officialCyclesBalance := (pre-call balance - cyclesToSend)");
                // Sanity check
                let newCyclesBalance = Cycles.balance();
                if (officialCyclesBalance < newCyclesBalance) {
                    D.print("mAIner storeAndSubmitResponse - after updating the official cycles balance, it is still smaller than the actual balance");
                    D.print("mAIner storeAndSubmitResponse - officialCyclesBalance: " # debug_show(officialCyclesBalance));
                    D.print("mAIner storeAndSubmitResponse - newCyclesBalance: " # debug_show(newCyclesBalance));
                };

                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - calling putSubmittedResponse");
                let putResult = putSubmittedResponse(challengeResponseSubmission);
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - return from putSubmittedResponse");
                switch (putResult) {
                    case (false) {
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - putResult error");
                    };
                    case (true) {
                        ignore increaseTotalCyclesBurnt(CYCLES_BURNT_RESPONSE_GENERATION);
                    };
                };
            };
        };
    };

    private func respondToChallengeDoIt_(challengeQueueInput : Types.ChallengeQueueInput) : async Types.ChallengeResponseResult {
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - entry");
        let maxContinueLoopCount : Nat = challengeQueueInput.mainerMaxContinueLoopCount; // After this many calls to run_update, we stop.
        let num_tokens : Nat64 = challengeQueueInput.mainerNumTokens; // Mostly we stop after maxContinueLoopCount update calls & this is never actually used
        let temp : Float = challengeQueueInput.mainerTemp;

        // --------------------------------------------------------
        // var promptRepetitive : Text = "<|im_start|>user\nAnswer the following question as brief as possible. This is the question: ";
        // var prompt : Text = promptRepetitive # challengeQueueInput.challengeQuestion # "\n<|im_end|>\n<|im_start|>assistant\n";
        let mainerPromptId : Text = challengeQueueInput.mainerPromptId;
        let gameStateCanisterActor = actor (GAME_STATE_CANISTER_ID) : Types.GameStateCanister_Actor;
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): calling getMainerPromptInfo of gameStateCanisterActor = " # Principal.toText(Principal.fromActor(gameStateCanisterActor)));
        let mainerPromptInfoResult : Types.MainerPromptInfoResult = await gameStateCanisterActor.getMainerPromptInfo(mainerPromptId);
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): getMainerPromptInfo returned.");
        var prompt : Text = "";
        var promptCacheSha256 : Text = "";
        var promptSaveCache : Text = ""; // We will upload this into the LLM canister
        var promptCacheNumberOfChunks : Nat = 0;
        switch (mainerPromptInfoResult) {
            case (#Err(error)) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): getMainerPromptInfo error " # debug_show (error));
                return #Err(error);
            };
            case (#Ok(mainerPromptInfo)) {
                prompt := mainerPromptInfo.promptText;
                promptCacheSha256 := mainerPromptInfo.promptCacheSha256;
                promptSaveCache := mainerPromptInfo.promptCacheFilename;
                promptCacheNumberOfChunks := mainerPromptInfo.promptCacheNumberOfChunks;
            };
        };

        // --------------------------------------------------------
        let llmCanister = _getRoundRobinCanister();
        let llmCanisterPrincipal : Principal = Principal.fromActor(llmCanister);

        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - llmCanister = " # Principal.toText(Principal.fromActor(llmCanister)));

        // Check health of llmCanister
        // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - calling health endpoint of LLM");
        let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.health();
        // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - returned from health endpoint of LLM with : ");
        // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
        switch (statusCodeRecordResult) {
            case (#Err(error)) {
                return #Err(error);
            };
            case (#Ok(_statusCodeRecord)) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - LLM is healthy");
            };
        };

        // First send cycles to the LLM
        var cyclesAdded : Nat = challengeQueueInput.cyclesGenerateResponseSsctrlSsllm;
        if (MAINER_AGENT_CANISTER_TYPE == #Own) {
            cyclesAdded := challengeQueueInput.cyclesGenerateResponseOwnctrlOwnllmHIGH; // TODO: adjust for mAIners with setting LOW or MEDIUM
        };
        try {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - calling Cycles.add for = " # debug_show(cyclesAdded) # " Cycles");
            Cycles.add<system>(cyclesAdded);

            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - calling IC0.deposit_cycles for LLM " # debug_show(llmCanisterPrincipal));
            let deposit_cycles_args = { canister_id : Principal = llmCanisterPrincipal; };
            let _ = await IC0.deposit_cycles(deposit_cycles_args);

            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - Successfully deposited " # debug_show(cyclesAdded) # " cycles to LLM canister " # debug_show(llmCanisterPrincipal) ); 
        } catch (e) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - Failed to deposit " # debug_show(cyclesAdded) # " cycles to LLM canister " # debug_show(llmCanisterPrincipal));
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - Failed to deposit error is" # Error.message(e));

            return #Err(#FailedOperation);
        };    

        let generationId : Text = try {
            await Utils.newRandomUniqueId();
        } catch (error) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - Utils.newRandomUniqueId threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
            return #Err(#FailedOperation);
        };

        // Use the generationId to create a highly variable seed for the LLM
        let seed : Nat32 = Utils.getRandomLlmSeed(generationId);
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - seed = " # debug_show(seed));

        var generationOutput : Text = "";
        let generationPrompt : Text = prompt;

        // The prompt cache file
        let promptCache : Text = generationId # ".cache";

        // Start the generation for this challengeQueueInput
        var num_update_calls : Nat64 = 0;

        // data returned from new_chat
        var status_code : Nat16 = 0;
        var output : Text = "";
        var conversation : Text = "";
        var error : Text = "";
        var prompt_remaining : Text = "";
        var generated_eog : Bool = false;

        // ----------------------------------------------------------------------
        // Step 0
        // Restore a previously saved prompt cache file
        // let promptSaveCache : Text = Nat32.toText(Text.hash(promptRepetitive)) # ".cache";
        // We will check if the one from the Challenger is already in this LLM
        var foundPromptSaveCache : Bool = false;

        try {
            let copyPromptCacheInputRecord : Types.CopyPromptCacheInputRecord = { 
                from = promptSaveCache; 
                to =  promptCache
            };
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): calling copy_prompt_cache to restore a previously saved promptCache if it exists. promptSaveCache: " # promptSaveCache);
            num_update_calls += 1;
            let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.copy_prompt_cache(copyPromptCacheInputRecord);
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): returned from copy_prompt_cache with statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
            switch (statusCodeRecordResult) {
                case (#Err(_)) {
                    foundPromptSaveCache := false;
                };
                case (#Ok(_)) {
                    foundPromptSaveCache := true;
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - foundPromptSaveCache ! (no need to get it again from Gamestate.) " # debug_show(promptCache));
                };
            };
        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): catch error when calling copy_prompt_cache : ");
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to copy_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };

        if (not foundPromptSaveCache) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - Did not find promptCache (will get it from Gamestate & upload to LLM) " # debug_show(promptCache));
            let mainerPromptCacheBuffer : Buffer.Buffer<Blob> = Buffer.Buffer<Blob>(0);
            for (i in Iter.range(0, promptCacheNumberOfChunks - 1)) {
                var delay : Nat = 2_000_000_000; // 2 seconds
                let maxAttempts : Nat = 8;
                let downloadMainerPromptCacheBytesChunkInput : Types.DownloadMainerPromptCacheBytesChunkInput = {
                    mainerPromptId = mainerPromptId;
                    chunkID = i;
                };
                let downloadMainerPromptCacheBytesChunkRecordResult: Types.DownloadMainerPromptCacheBytesChunkRecordResult = try {
                    await retryGameStateMainerPromptCacheChunkDownloadWithDelay(gameStateCanisterActor, downloadMainerPromptCacheBytesChunkInput, maxAttempts, delay);
                } catch (error) {
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - retryGameStateMainerPromptCacheChunkDownloadWithDelay threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
                    return #Err(#FailedOperation);
                };
                switch (downloadMainerPromptCacheBytesChunkRecordResult) {
                    case (#Err(error)) {
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # ") - ERROR during download of mAIner prompt cache chunk - statusCodeRecordResult:" # debug_show (statusCodeRecordResult));
                        return #Err(error);
                    };
                    case (#Ok(downloadMainerPromptCacheBytesChunkRecord)) {
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # ") - download of mAIner prompt cache chunk successful - chunkID: " # debug_show (downloadMainerPromptCacheBytesChunkRecord.chunkID));
                        mainerPromptCacheBuffer.add(downloadMainerPromptCacheBytesChunkRecord.bytesChunk);
                    };
                };
            };

            // ---------------------------------------------------------
            // Upload prompt cache file
            var chunkSize : Nat = 0;
            var offset : Nat = 0;
            var nextChunk : [Nat8] = [];

            // For progress reporting
            var modelUploadProgress : Nat8 = 0;
            let modelUploadProgressInterval : Nat = 10; // 10% progress interval

            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - Downloaded the promptCache from Gamestate. Will now upload to LLM - " # debug_show(promptCache));
            var chunkCount : Nat = 0;
            let totalChunks : Nat = mainerPromptCacheBuffer.size();
            var nextProgressThreshold : Nat = 0;

            var fileUploadRecordResult : Types.FileUploadRecordResult = #Ok({ filename = promptCache; filesha256 = ""; filesize = 0 }); // Placeholder
            for (chunk in mainerPromptCacheBuffer.vals()) {
                var progress : Nat = (chunkCount * 100) / totalChunks; // Integer division rounds down
                if (chunkCount + 1 == totalChunks) {
                    progress := 100; // Set to 100% for the last chunk
                };
                if (progress >= nextProgressThreshold) {
                    modelUploadProgress := Nat8.fromNat(nextProgressThreshold); // Set to 0, 10, 20, ..., 100
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - uploading promptCache chunk " # debug_show (chunkCount) # "(modelUploadProgress = " # debug_show (modelUploadProgress) # "%)");
                    nextProgressThreshold += modelUploadProgressInterval;
                };
                chunkCount := chunkCount + 1;
                
                nextChunk := Blob.toArray(chunk);
                chunkSize := nextChunk.size();
                let uploadChunk : Types.UploadPromptCacheInputRecord = {
                    promptcache = promptCache;
                    chunk = nextChunk;
                    chunksize = Nat64.fromNat(chunkSize);
                    offset = Nat64.fromNat(offset);
                };

                var delay : Nat = 2_000_000_000; // 2 seconds
                let maxAttempts : Nat = 8;
                fileUploadRecordResult := try {
                    await retryLlmPrompCacheChunkUploadWithDelay(llmCanister, uploadChunk, maxAttempts, delay);
                } catch (error) {
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - retryLlmPrompCacheChunkUploadWithDelay threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
                    return #Err(#FailedOperation);
                };
                switch (fileUploadRecordResult) {
                    case (#Err(error)) {
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - ERROR uploading a promptCache chunk - uploadModelFileResult:");
                        D.print(debug_show (fileUploadRecordResult));
                        return #Err(error);
                    };
                    case (#Ok(_)) {
                        // all good, continue with next chunk
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - success uploading a promptCache chunk - fileUploadRecordResult = " # debug_show (fileUploadRecordResult));
                        offset := offset + chunkSize;
                    };
                };
            };

            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - after prompt cache upload -- checking filesha256.");
            switch (fileUploadRecordResult) {
                case (#Err(error)) {
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - ERROR - fileUploadRecordResult:" # debug_show (fileUploadRecordResult));
                    return #Err(error);
                };
                case (#Ok(fileUploadRecordResult)) {
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - fileUploadRecordResult" # debug_show (fileUploadRecordResult));
                    // Check the sha256
                    let filesha256 : Text = fileUploadRecordResult.filesha256;
                    let expectedSha256 : Text = promptCacheSha256;
                    
                    if (not (filesha256 == expectedSha256)) {
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - ERROR: filesha256 = " # debug_show (filesha256) # "does not match expectedSha256 = " # debug_show (expectedSha256));
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - THIS IS A TODO FOR THE CHALLENGER !!!");
                        // TODO - Challenger must set the promptCacheSha256
                        // return #Err(#Other("The sha256 of the uploaded llm file is " # filesha256 # ", which does not match the expected value of " # expectedSha256));
                    } else {
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - filesha256 matches expectedSha256 = " # debug_show (expectedSha256));
                    };
                };
            };

            // -----
            // Save the prompt cache for reuse with next submission using the same prompt
            try {
                let copyPromptCacheInputRecord : Types.CopyPromptCacheInputRecord = { 
                    from = promptCache; 
                    to =  promptSaveCache
                };
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): calling copy_prompt_cache to save the uploaded promptCache (" # promptCache # ") to promptSaveCache: " # promptSaveCache);
                let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.copy_prompt_cache(copyPromptCacheInputRecord);
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): returned from copy_prompt_cache with statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
                switch (statusCodeRecordResult) {
                    case (#Err(error)) {
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - ERROR - statusCodeRecordResult:" # debug_show (fileUploadRecordResult));
                        return #Err(error);
                    };
                    case (#Ok(_)) {
                        foundPromptSaveCache := true;
                    };
                };                
            } catch (error : Error) {
                // Handle errors, such as llm canister not responding
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): catch error when calling copy_prompt_cache : " # Error.message(error));
                return #Err(
                    #Other(
                        "Failed call to copy_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                        " with error: " # Error.message(error)
                    )
                );
            };
        };

        // ----------------------------------------------------------------------
        // Step 1
        // Call new_chat
        try {
            let args : [Text] = [
                "--prompt-cache",
                promptCache,
            ];
            let inputRecord : Types.InputRecord = { args = args };
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - calling new_chat...");
            // D.print(debug_show (args));
            num_update_calls += 1;
            let outputRecordResult : Types.OutputRecordResult = await llmCanister.new_chat(inputRecord);
            // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - returned from new_chat with outputRecordResult: ");
            // D.print(debug_show (outputRecordResult));

            switch (outputRecordResult) {
                case (#Err(error)) {
                    return #Err(error);
                };
                case (#Ok(outputRecord)) {
                    // the generated tokens
                    status_code := outputRecord.status_code;
                    output := outputRecord.output;
                    conversation := outputRecord.conversation;
                    error := outputRecord.error;
                    prompt_remaining := outputRecord.prompt_remaining;
                    generated_eog := outputRecord.generated_eog;
                    // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - status_code      : " # debug_show (status_code));
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - output           : " # debug_show (output));
                    // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - conversation     : " # debug_show (conversation));
                    // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - error            : " # debug_show (error));
                    // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - prompt_remaining : " # debug_show (prompt_remaining));
                    // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - generated_eog    : " # debug_show (generated_eog));
                };
            };
        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - catch error when calling new_chat : ");
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to new_chat of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };

        // ----------------------------------------------------------------------
        // Step 2
        // (A) Ingest the prompt into the prompt-cache, using multiple update calls
        //      (-) Repeat call with full prompt until `prompt_remaining` in the response is empty.
        //      (-) The first part of the challengeQueueInput will be generated too.
        // (B) Generate rest of challengeQueueInput, using multiple update calls
        //      (-) Repeat call with empty prompt until `generated_eog` in the response is `true`.
        //      (-) The rest of the challengeQueueInput will be generated.

        // Avoid endless loop by limiting the number of iterations
        var continueLoopCount : Nat = 0;
        label continueLoop while (continueLoopCount < maxContinueLoopCount) {
            try {
                let args = [
                    "--prompt-cache",
                    promptCache,
                    "--prompt-cache-all",
                    "--simple-io",
                    "--no-display-prompt", // only return generated text
                    "-n",
                    Nat64.toText(num_tokens),
                    "--seed",
                    Nat32.toText(seed),
                    "--temp",
                    Float.toText(temp),
                    "-p",
                    prompt,
                ];
                let inputRecord : Types.InputRecord = { args = args };
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - calling run_update...");
                // D.print(debug_show (args));
                num_update_calls += 1;
                if (num_update_calls > 30) {
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - too many calls run_update - Breaking out of loop...");
                    break continueLoop; // Protective break for endless loop.
                };
                let outputRecordResult : Types.OutputRecordResult = await llmCanister.run_update(inputRecord);
                // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - INGESTING PROMPT:returned from run_update with outputRecordResult: ");
                // D.print(debug_show (outputRecordResult));

                switch (outputRecordResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case (#Ok(outputRecord)) {
                        // the generated tokens
                        status_code := outputRecord.status_code;
                        output := outputRecord.output;
                        conversation := outputRecord.conversation;
                        error := outputRecord.error;
                        prompt_remaining := outputRecord.prompt_remaining;
                        generated_eog := outputRecord.generated_eog;
                        // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - status_code      : " # debug_show (status_code));
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - output           : " # debug_show (output));
                        // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - conversation     : " # debug_show (conversation));
                        // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - error            : " # debug_show (error));
                        // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - prompt_remaining : " # debug_show (prompt_remaining));
                        // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - generated_eog    : " # debug_show (generated_eog));

                        generationOutput := generationOutput # output;
                        // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - generationOutput : " # debug_show (generationOutput));

                        if (prompt_remaining == "") {
                            prompt := ""; // Send empty prompt - the prompt ingestion is done.
                            continueLoopCount += 1; // We count the actual generation steps
                            // NO LONGER NEEDED - WE leave it here for now in case want to restore the logic in future
                            // // -----
                            // // Prompt ingestion is finished. If it was not yet there, save the prompt cache for reuse with next submission
                            // if (not foundPromptSaveCache) {
                            //     try {
                            //         let copyPromptCacheInputRecord : Types.CopyPromptCacheInputRecord = { 
                            //             from = promptCache; 
                            //             to =  promptSaveCache
                            //         };
                            //         D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): calling copy_prompt_cache to save the promptCache to promptSaveCache: " # promptSaveCache);
                            //         num_update_calls += 1;
                            //         let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.copy_prompt_cache(copyPromptCacheInputRecord);
                            //         D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): returned from copy_prompt_cache with statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
                            //         // We do not care what the result is, as it is just a possible optimization operation
                            //     } catch (error : Error) {
                            //         // Handle errors, such as llm canister not responding
                            //         D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): catch error when calling copy_prompt_cache : ");
                            //         D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): error: " # Error.message(error));
                            //         return #Err(
                            //             #Other(
                            //                 "Failed call to copy_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                            //                 " with error: " # Error.message(error)
                            //             )
                            //         );
                            //     };
                            // };
                        };
                        if (generated_eog) {
                            break continueLoop; // Exit the loop - the mAIner response is generated.
                        };
                    };
                };
            } catch (error : Error) {
                // Handle errors, such as llm canister not responding
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - catch error when calling new_chat : ");
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - error: " # Error.message(error));
                return #Err(
                    #Other(
                        "Failed call to run_update of " # Principal.toText(Principal.fromActor(llmCanister)) #
                        " with error: " # Error.message(error)
                    )
                );
            };
        };

        // Delete the prompt cache in the LLM
        try {
            let args : [Text] = [
                "--prompt-cache",
                promptCache,
            ];
            let inputRecord : Types.InputRecord = { args = args };
            // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - calling remove_prompt_cache with args: ");
            // D.print(debug_show (args));
            num_update_calls += 1;
            let outputRecordResult : Types.OutputRecordResult = await llmCanister.remove_prompt_cache(inputRecord);
            // D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - returned from remove_prompt_cache with outputRecordResult: ");
            // D.print(debug_show (outputRecordResult));

        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - catch error when calling remove_prompt_cache : ");
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondToChallengeDoIt_ - error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to remove_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };

        // Return the generated response
        let responseOutput : Types.ChallengeResponse = {
            challengeId :Text = challengeQueueInput.challengeId;
            generationId : Text = generationId;
            generationSeed : Nat32 = seed;
            generatedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            generatedByLlmId : Text = Principal.toText(Principal.fromActor(llmCanister));
            generationPrompt : Text = generationPrompt;
            generatedResponseText : Text = generationOutput;
        };
        return #Ok(responseOutput);
    };

    // Downloads a chunk of the mAIner prompt cache file from the GameState canister
    private func retryGameStateMainerPromptCacheChunkDownloadWithDelay(gameStateCanisterActor : Types.GameStateCanister_Actor, downloadMainerPromptCacheBytesChunkInput : Types.DownloadMainerPromptCacheBytesChunkInput, attempts : Nat, delay : Nat) : async Types.DownloadMainerPromptCacheBytesChunkRecordResult {
        if (attempts > 0) {
            try {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): - retryGameStateMainerPromptCacheChunkDownloadWithDelay - calling gameStateCanisterActor.downloadMainerPromptCacheBytesChunk for mainerPromptId, chunkID = " # debug_show (downloadMainerPromptCacheBytesChunkInput.mainerPromptId) # ", " # debug_show (downloadMainerPromptCacheBytesChunkInput.chunkID));
                let downloadMainerPromptCacheBytesChunkRecordResult : Types.DownloadMainerPromptCacheBytesChunkRecordResult = await gameStateCanisterActor.downloadMainerPromptCacheBytesChunk(downloadMainerPromptCacheBytesChunkInput);
                return downloadMainerPromptCacheBytesChunkRecordResult;
                
            } catch (e) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): - retryGameStateMainerPromptCacheChunkDownloadWithDelay - gameStateCanisterActor.uploadMainerPromptCacheBytesChunk failed with catch error " # Error.message(e) # ", retrying in " # debug_show(delay) # " nanoseconds");
                // Just retry immediately with decremented attempts
                return await retryGameStateMainerPromptCacheChunkDownloadWithDelay(gameStateCanisterActor, downloadMainerPromptCacheBytesChunkInput, attempts - 1, delay);
            };
        } else {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): - retryGameStateMainerPromptCacheChunkDownloadWithDelay - Max retry attempts reached");
            return #Err(#Other("Max retry attempts reached"));
        };
    };

    // Uploads a chunk of the promptCache file to the LLM canister
    private func retryLlmPrompCacheChunkUploadWithDelay(llmCanisterActor : Types.LLMCanister, uploadChunk : Types.UploadPromptCacheInputRecord, attempts : Nat, delay : Nat) : async Types.FileUploadRecordResult {
        if (attempts > 0) {
            try {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): - retryLlmPrompCacheChunkUploadWithDelay - calling upload_prompt_cache_chunk for chunksize, offset = " # debug_show (uploadChunk.chunksize) # ", " # debug_show (uploadChunk.offset));
                let uploadModelFileResult : Types.FileUploadRecordResult = await llmCanisterActor.upload_prompt_cache_chunk(uploadChunk);
                return uploadModelFileResult;
                
            } catch (e) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): - retryLlmPrompCacheChunkUploadWithDelay - LLM upload_prompt_cache_chunk failed with catch error " # Error.message(e) # ", retrying in " # debug_show(delay) # " nanoseconds");
                // Just retry immediately with decremented attempts
                return await retryLlmPrompCacheChunkUploadWithDelay(llmCanisterActor, uploadChunk, attempts - 1, delay);
            };
        } else {
            D.print("Max retry attempts reached");
            return #Err(#Other("Max retry attempts reached"));
        };
    };

    // Triggered by timer 1: get next challenge and add it to the queue
    private func pullNextChallenge() : async () {
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - entered");
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - entry");

        if (MAINER_AGENT_CANISTER_TYPE == #ShareService) {
            // This should never happen, but still protect against it
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - Something is wrong. pullNextChallenge should not be called by a ShareService.");
            return;
        };

        // -----------------------------------------------------
        // Skip the GameState call entirely if we already paused ourselves due to
        // low cycles, or if the balance is below the safety floor. addCycles()
        // clears the flag once new cycles arrive, so the timer resumes naturally.
        if (PAUSED_DUE_TO_LOW_CYCLE_BALANCE) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - PAUSED_DUE_TO_LOW_CYCLE_BALANCE is set; skipping");
            return;
        };
        if (Cycles.balance() < CYCLE_BALANCE_MINIMUM) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - cycle balance below CYCLE_BALANCE_MINIMUM; skipping");
            PAUSED_DUE_TO_LOW_CYCLE_BALANCE := true;
            return;
        };

        // -----------------------------------------------------
        // Self-cleanup: drop stale or critically-long queues before deciding
        // whether to pull more work. Replaces the off-chain daily cleanup job.
        cleanupChallengeQueueIfNeeded();

        // -----------------------------------------------------
        // Check if the queue already has enough challenges
        if (List.size(challengeQueue) >= MAX_CHALLENGES_IN_QUEUE) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - Already have enough Challenges in the queue. Not adding more.");
            return;
        };

        // -----------------------------------------------------
        // Get the next challenge from GameState canister.
        // Inlined (no helper func) so the only `await` is the cross-canister
        // call to GameState. A helper `private func ... : async ...` would have
        // forced an extra Motoko self-call across the message queue, which
        // can fail silently with #call_error when balance is below the IC's
        // outgoing-call floor (the freezing reserve + per-call overhead).
        let gameStateCanisterActor = actor (GAME_STATE_CANISTER_ID) : Types.GameStateCanister_Actor;
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - calling getRandomOpenChallenge of gameStateCanisterActor = " # Principal.toText(Principal.fromActor(gameStateCanisterActor)));
        let challengeResult : Types.ChallengeResult = try {
            await gameStateCanisterActor.getRandomOpenChallenge();
        } catch (error) {
            // Most likely cause: low cycle balance triggered #call_error from the IC
            // (formerly the IC0406 "could not perform self call" trap).
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - getRandomOpenChallenge threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
            return;
        };
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - received challengeResult: " # debug_show (challengeResult));
        switch (challengeResult) {
            case (#Err(error)) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - challengeResult error : " # debug_show (error));
            };
            case (#Ok(challenge : Types.Challenge)) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - challenge = " # debug_show (challenge));

                if (not sufficientCyclesToProcessChallenge(challenge)) {
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - PAUSING RESPONSE GENERATION DUE TO LOW CYCLE BALANCE");
                    PAUSED_DUE_TO_LOW_CYCLE_BALANCE := true;
                    return;
                };
                // Ok,the canister has enough cycles
                PAUSED_DUE_TO_LOW_CYCLE_BALANCE := false;
                
                // Add the challenge to the queue
                let challengeQueuedId : Text = try {
                    await Utils.newRandomUniqueId();
                } catch (error) {
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - Utils.newRandomUniqueId threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
                    return;
                };
                let challengeQueuedBy : Principal = Principal.fromActor(this);
                let challengeQueuedTo : Principal = Principal.fromActor(shareServiceCanisterActor);

                var challengeQueueInput : Types.ChallengeQueueInput = {
                    challengeTopic : Text = challenge.challengeTopic;
                    challengeTopicId : Text = challenge.challengeTopicId;
                    challengeTopicCreationTimestamp : Nat64 = challenge.challengeTopicCreationTimestamp;
                    challengeTopicStatus : Types.ChallengeTopicStatus = challenge.challengeTopicStatus;
                    cyclesGenerateChallengeGsChctrl : Nat = challenge.cyclesGenerateChallengeGsChctrl;
                    cyclesGenerateChallengeChctrlChllm : Nat = challenge.cyclesGenerateChallengeChctrlChllm;
                    challengeQuestion : Text = challenge.challengeQuestion;
                    challengeQuestionSeed : Nat32 = challenge.challengeQuestionSeed;
                    mainerPromptId : Text = challenge.mainerPromptId;
                    mainerMaxContinueLoopCount : Nat = challenge.mainerMaxContinueLoopCount;
                    mainerNumTokens : Nat64 = challenge.mainerNumTokens;
                    mainerTemp : Float = challenge.mainerTemp;
                    judgePromptId : Text = challenge.judgePromptId;
                    challengeId : Text = challenge.challengeId;
                    challengeCreationTimestamp : Nat64 = challenge.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = challenge.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = challenge.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = challenge.challengeClosedTimestamp;
                    cyclesSubmitResponse : Nat = challenge.cyclesSubmitResponse;
                    protocolOperationFeesCut : Nat = challenge.protocolOperationFeesCut;
                    cyclesGenerateResponseSactrlSsctrl : Nat = challenge.cyclesGenerateResponseSactrlSsctrl;
                    cyclesGenerateResponseSsctrlGs : Nat = challenge.cyclesGenerateResponseSsctrlGs;
                    cyclesGenerateResponseSsctrlSsllm : Nat = challenge.cyclesGenerateResponseSsctrlSsllm;
                    cyclesGenerateResponseOwnctrlGs : Nat = challenge.cyclesGenerateResponseOwnctrlGs;
                    cyclesGenerateResponseOwnctrlOwnllmLOW : Nat = challenge.cyclesGenerateResponseOwnctrlOwnllmLOW;
                    cyclesGenerateResponseOwnctrlOwnllmMEDIUM : Nat = challenge.cyclesGenerateResponseOwnctrlOwnllmMEDIUM;
                    cyclesGenerateResponseOwnctrlOwnllmHIGH : Nat = challenge.cyclesGenerateResponseOwnctrlOwnllmHIGH;
                    challengeQueuedId : Text = challengeQueuedId;
                    challengeQueuedBy : Principal = challengeQueuedBy;
                    challengeQueuedTo : Principal = challengeQueuedTo;
                    challengeQueuedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                };
                
                // A ShareAgent canister first sends the challenge to the Shared mAIner Service to be put in that canisters queue
                if (MAINER_AGENT_CANISTER_TYPE == #ShareAgent) {
                    // Add the cycles required for the ShareService queue (We already checked there is enough)
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - calling Cycles.add for = " # debug_show(challenge.cyclesGenerateResponseSactrlSsctrl) # " Cycles");
                    logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - before Cycles.add for ShareService");
                    Cycles.add<system>(challenge.cyclesGenerateResponseSactrlSsctrl);
                    logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - after Cycles.add (note: Cycles.add does not change balance until the call goes out)");

                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - calling addChallengeToShareServiceQueue of shareServiceCanisterActor = " # Principal.toText(Principal.fromActor(shareServiceCanisterActor)));
                    let challegeQueueInputResult = try {
                        await shareServiceCanisterActor.addChallengeToShareServiceQueue(challengeQueueInput);
                    } catch (error) {
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - addChallengeToShareServiceQueue threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
                        return;
                    };
                    logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - after await addChallengeToShareServiceQueue (any refund visible here)");

                    switch (challegeQueueInputResult) {
                        case (#Err(error)) {
                            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - addChallengeToShareServiceQueue returned with error : " # debug_show (error));
                            // Do not store it in the queue
                            return;
                        };
                        case (#Ok(challengeQueueInput_)) {
                            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - addChallengeToShareServiceQueue returned successfully : ");
                            challengeQueueInput := challengeQueueInput_;
                        };
                    };
                };

                let _pushResult_ = pushChallengeQueue(challengeQueueInput);

                return;
            };
        };
    };

    // Function of ShareService canister to add new challenge to the ShareService canisters queue
    public shared (msg) func addChallengeToShareServiceQueue(challengeQueueInput : Types.ChallengeQueueInput) : async Types.ChallengeQueueInputResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addChallengeToShareServiceQueue - entry, available=" # Nat.toText(Cycles.available()) # " caller=" # Principal.toText(msg.caller));

        if (MAINER_AGENT_CANISTER_TYPE != #ShareService) {
            return #Err(#Unauthorized);
        };

        // Only registered ShareAgent canisters may call this
        switch (getShareAgentCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?_shareAgentEntry) {
                // Check that the record looks correct
                if (challengeQueueInput.challengeQueuedBy != msg.caller) {
                    return #Err(#Unauthorized);
                };
                // Accept required cycles for queue input
                let cyclesAcceptedForShareServiceQueue = Cycles.accept<system>(challengeQueueInput.cyclesGenerateResponseSactrlSsctrl);
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addChallengeToShareServiceQueue - cyclesAcceptedForShareServiceQueue = " # Nat.toText(cyclesAcceptedForShareServiceQueue) # " from caller " # Principal.toText(msg.caller));
                logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addChallengeToShareServiceQueue - after accept");

                // Store it in the queue
                let _pushResult_ = pushChallengeQueue(challengeQueueInput);
                return #Ok(challengeQueueInput);                        
            };
        };
    };    

    private func processNextChallenge() : async () {
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processNextChallenge - entered");
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processNextChallenge - entry");

        if (MAINER_AGENT_CANISTER_TYPE == #ShareAgent) {
            // This should never happen, but still protect against it
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processNextChallenge - Something is wrong. processNextChallenge should not be called by a ShareAgent.");
            return;
        };

        // Process the next challenge in the challengeQueue
        switch (popChallengeQueue()) {
            case (null) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processNextChallenge - Queue is empty. Nothing to do.");
                return;
            };
            case (?challengeQueueInput) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processNextChallenge - challengeQueueInput" # debug_show (challengeQueueInput));

                // Check if the canister has enough cycles for this particular Challenge
                if (not sufficientCyclesToProcessChallenge(challengeQueueInput)) {
                    // Note: do not set pause flag
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processNextChallenge - Not enough cycles to process challenge. Pushing it back on the queue to try later.");
                    // Push the challenge back to the queue to try again later
                    let _pushResult_ = pushChallengeQueue(challengeQueueInput);
                    return;
                };

                // Process the challenge
                // Sanity checks
                if (challengeQueueInput.challengeId == "" or challengeQueueInput.mainerPromptId == "") {
                    return;
                };
                switch (challengeQueueInput.challengeStatus) {
                    case (#Open) {
                        // continue
                    };
                    case (_) { return };
                };
                switch (challengeQueueInput.challengeClosedTimestamp) {
                    case (null) {
                        // continue
                    };
                    case (_) { return };
                };

                ignore processRespondingToChallenge(challengeQueueInput);
                return;
            };
        };
    };

    public shared query (msg) func getRoundRobinCanister() : async Types.CanisterIDRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (llmCanisters.size() == 0) {
            return #Err(#Other("No LLM canisters configured"));
        };
        let canisterIDRecord : Types.CanisterIDRecord = {
            canister_id = Principal.toText(Principal.fromActor(_getRoundRobinCanister()));
        };
        return #Ok(canisterIDRecord);
    };

    private func _getRoundRobinCanister() : Types.LLMCanister {
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): _getRoundRobinCanister: using roundRobinIndex " # Nat.toText(roundRobinIndex));
        
        // Protect against invalid roundRobinIndex
        if (roundRobinIndex >= llmCanisters.size()) {
            roundRobinIndex := 0;
        };

        let canister = llmCanisters.get(roundRobinIndex);
        roundRobinIndex += 1;

        var roundRobinIndexTurn = llmCanisters.size();
        if (roundRobinUseAll == false) {
            roundRobinIndexTurn := Utils.minNat(roundRobinIndexTurn, roundRobinLLMs);
        };

        if (roundRobinIndex >= roundRobinIndexTurn) {
            roundRobinIndex := 0;
        };

        return canister;
    };

    // Function for mAIner Agent Creator canister to add new mAIner ShareAgent canister to a mAIner ShareService canister
    public shared (msg) func addMainerShareAgentCanister(canisterEntryToAdd : Types.OfficialMainerAgentCanister) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (canisterEntryToAdd.canisterType) {
            case (#MainerAgent(_)) {
                // continue
            };
            case (_) { return #Err(#Other("Unsupported canisterType")); }
        };

        // This check does not apply because the mAIner Creator creates the ShareService canister
        // Just verifying that only a controller can call this is enough, and also all we can do.
        let canisterEntry : Types.OfficialMainerAgentCanister = {
            address : Text = canisterEntryToAdd.address;
            subnet : Text = canisterEntryToAdd.subnet;
            canisterType: Types.ProtocolCanisterType = canisterEntryToAdd.canisterType;
            creationTimestamp : Nat64 = canisterEntryToAdd.creationTimestamp;
            createdBy : Principal = canisterEntryToAdd.createdBy;
            ownedBy : Principal = canisterEntryToAdd.ownedBy;
            status : Types.CanisterStatus = canisterEntryToAdd.status;
            mainerConfig : Types.MainerConfigurationInput = canisterEntryToAdd.mainerConfig;
        };
        putShareAgentCanister(canisterEntryToAdd.address, canisterEntry);
    };

    // Testing: admin Function to add new mAIner ShareAgent for testing
    public shared (msg) func addMainerShareAgentCanisterAdmin(canisterEntryToAdd : Types.OfficialMainerAgentCanister) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (canisterEntryToAdd.canisterType) {
            case (#MainerAgent(_)) {
                // continue
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };
        let canisterEntry : Types.OfficialMainerAgentCanister = {
            address : Text = canisterEntryToAdd.address;
            subnet : Text = canisterEntryToAdd.subnet;
            canisterType: Types.ProtocolCanisterType = canisterEntryToAdd.canisterType;
            creationTimestamp : Nat64 = canisterEntryToAdd.creationTimestamp;
            createdBy : Principal = canisterEntryToAdd.createdBy;
            ownedBy : Principal = canisterEntryToAdd.ownedBy;
            status : Types.CanisterStatus = canisterEntryToAdd.status;
            mainerConfig : Types.MainerConfigurationInput = canisterEntryToAdd.mainerConfig;
        }; 
        putShareAgentCanister(canisterEntryToAdd.address, canisterEntry); 
    };

// Timers

    // This variable is just for reporting purposes, so an Admin can quickly check the currently used timer regularity
    // It is recalculated each time the timer is started
    var action1RegularityInSeconds = 0; // Timer is not yet set 

    // ----------------------------------------------------------
    // How often Own and ShareService mAIners wake up to process the next challenge from the queue
    // TODO: revisit for #Own mAiners...
    var action2RegularityInSeconds = 5; 

    var cyclesBurnRateFromGameState = CYCLES_BURN_RATE_DEFAULT; // Just set it to some default value. The actual value is retrieved from the GameState in startTimerExecution()
   
    public shared (msg) func setTimerAction2RegularityInSecondsAdmin(_action2RegularityInSeconds : Nat) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        action2RegularityInSeconds := _action2RegularityInSeconds;
        // Restart the timer with the new regularity
        let _ = try {
            await startTimerExecution(msg.caller, "setTimerAction2RegularityInSecondsAdmin");
        } catch (error) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): setTimerAction2RegularityInSecondsAdmin - startTimerExecution threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
            return #Err(#Other("startTimerExecution failed: " # Error.message(error)));
        };
        return #Ok({ status_code = 200 });
    };

    public shared query (msg) func getTimerActionRegularityInSecondsAdmin() : async Types.MainerTimersResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        return #Ok({
            action1RegularityInSeconds = action1RegularityInSeconds;
            action2RegularityInSeconds = action2RegularityInSeconds;
        });
    };
    // ----------------------------------------------------------

    private func triggerRecurringAction1() : async () {
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Recurring action 1 was triggered");
        let result = try {
            await pullNextChallenge();
        } catch (error) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): triggerRecurringAction1 - pullNextChallenge threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
            return;
        };
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Recurring action 1 result");
        D.print(debug_show (result));
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Recurring action 1 result");
    };

    private func triggerRecurringAction2() : async () {
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Recurring action 2 was triggered");
        let result = try {
            await processNextChallenge();
        } catch (error) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): triggerRecurringAction2 - processNextChallenge threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
            return;
        };
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Recurring action 2 result");
        D.print(debug_show (result));
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Recurring action 2 result");
    };

    
    private func startTimerExecution(callerPrincipal : Principal, calledFromEndpoint : Text) : async Types.AuthRecordResult {
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - entered" # ", calledFromEndpoint = " # calledFromEndpoint # ", callerPrincipal = " # Principal.toText(callerPrincipal));
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - entry");
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - initialTimerId1 = " # debug_show(initialTimerId1) # ", recurringTimerId1 = " # debug_show(recurringTimerId1) # ", bufferTimerId1 size = " # Nat.toText(bufferTimerId1.size()));
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - recurringTimerId2 = " # debug_show(recurringTimerId2) # ", bufferTimerId2 size = " # Nat.toText(bufferTimerId2.size()));

        var res = "You started the timers: ";
        let TIMER_REGULARITY_DEFAULT = 5;
        var timerRegularity = TIMER_REGULARITY_DEFAULT;

        // Calculate timer regularity based on cycles burn rate for user's mAIner
        if (MAINER_AGENT_CANISTER_TYPE == #Own or MAINER_AGENT_CANISTER_TYPE == #ShareAgent) {
            let gameStateCanisterActor = actor (GAME_STATE_CANISTER_ID) : Types.GameStateCanister_Actor;
            switch (getCurrentAgentSettings()) {
                case (null) {
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - No agentSettings found, using default cyclesBurnRateFromGameState = " # debug_show(cyclesBurnRateFromGameState));
                    // use default
                };
                case (?agentSettings) {
                    let cyclesBurnRateResult : Types.CyclesBurnRateResult = try {
                        await gameStateCanisterActor.getCyclesBurnRate(agentSettings.cyclesBurnRate);
                    } catch (error) {
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - getCyclesBurnRate threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
                        #Err(#Other("getCyclesBurnRate failed: " # Error.message(error)));
                    };
                    logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - after await getCyclesBurnRate");
                    switch (cyclesBurnRateResult) {
                        case (#Err(error)) {
                            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - gamestate.getCyclesBurnRate returned error: " # debug_show(error));
                            // we leave timer
                        };
                        case (#Ok(cyclesBurnRateFromGameState_)) {
                            cyclesBurnRateFromGameState := cyclesBurnRateFromGameState_;
                            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - cyclesBurnRate retrieved from gamestate.getCyclesBurnRate = " # debug_show(cyclesBurnRateFromGameState) );
                        };
                    };
                };
            };
            // Get the cycles used per response from GameState to calculate the timer regularity
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - calling getMainerCyclesUsedPerResponse of gameStateCanisterActor");
            let cyclesUsedResult : Types.NatResult = try {
                await gameStateCanisterActor.getMainerCyclesUsedPerResponse();
            } catch (error) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - getMainerCyclesUsedPerResponse threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
                #Err(#Other("getMainerCyclesUsedPerResponse failed: " # Error.message(error)));
            };
            logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - after await getMainerCyclesUsedPerResponse");
            switch (cyclesUsedResult) {
                case (#Err(error)) {
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - getMainerCyclesUsedPerResponse error: " # debug_show(error));
                    // we leave timer
                };
                case (#Ok(cyclesUsed)) {
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - cyclesBurnRateFromGameState = " # debug_show(cyclesBurnRateFromGameState));
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - cyclesUsed per response = " # debug_show(cyclesUsed));
                    timerRegularity := TimerRegularity.getTimerRegularityForCyclesBurnRate(cyclesBurnRateFromGameState, cyclesUsed);
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - timerRegularity = " # debug_show(timerRegularity) # ", cyclesBurnRateFromGameState = " # debug_show(cyclesBurnRateFromGameState) # ", cyclesUsed (per response) = " # debug_show(cyclesUsed)); 
                };
            };
        };

        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - timerRegularity = " # Nat.toText(timerRegularity) # " seconds");

        if (MAINER_AGENT_CANISTER_TYPE == #Own or MAINER_AGENT_CANISTER_TYPE == #ShareAgent) {
            res := res # " 1, ";
            var randomInitialTimer = 3000; // Default
            try {
                let random = Random.Finite(await Random.blob());
                let randomValueResult = random.range(6); // Uniformly distributes outcomes in the numeric range [0 .. 2^6 - 1] = [0 .. 63]
                switch (randomValueResult) {
                    case (?randomValue) {
                        randomInitialTimer := (randomValue + 1) * 2 * 60; // i.e. range for randomInitialTimer is between 120 and 7680 seconds (2 and 128 minutes)                
                    };
                    case (_) {
                        // Something went wrong with the random generation, use default
                    };
                };
            } catch (error : Error) {
                D.print("mAIner startTimerExecution error in generating randomInitialTimer: " # Error.message(error));
                // Some error occurred, use default
            };
            // First stop an existing timer if it exists
            logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - before await stopTimerExecution");
            try {
                let _ = await stopTimerExecution();
            } catch (error) {
                // Best-effort cleanup; log and continue with the start
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - stopTimerExecution threw (continuing): " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
            };
            logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - after await stopTimerExecution");

            // Now start the timer
            let initialTimerId = setTimer<system>(#seconds randomInitialTimer,
                func () : async () {
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - setTimer 1");
                    let id =  recurringTimer<system>(#seconds timerRegularity, triggerRecurringAction1);
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - Successfully start timer 1 with id = " # debug_show (id));
                    recurringTimerId1 := ?id;
                    addTimerToBuffer(bufferTimerId1, id);
                    // Clear initialTimerId1 since it has fired
                    initialTimerId1 := null;

                    // Record this timer creation (recurring timer 1)
                    let timersEntry : Types.MainerAgentTimers = {
                        action1RegularityInSeconds = action1RegularityInSeconds;
                        action2RegularityInSeconds = action2RegularityInSeconds;
                        initialTimerId1 = null;
                        randomInitialTimer1InSeconds = null;
                        recurringTimerId1 = ?id;
                        recurringTimerId2 = null;
                        creationTimestamp = Nat64.fromNat(Int.abs(Time.now()));
                        createdBy = callerPrincipal;
                        calledFromEndpoint = calledFromEndpoint;
                    };
                    ignore putAgentTimers(timersEntry);

                    logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - before await triggerRecurringAction1 (initial fire)");
                    try {
                        await triggerRecurringAction1();
                    } catch (error) {
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - triggerRecurringAction1 threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
                    };
                    logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - after await triggerRecurringAction1 (initial fire)");
            });
            // Store the initial timer ID for reporting and cancellation
            initialTimerId1 := ?initialTimerId;
            addTimerToBuffer(bufferTimerId1, initialTimerId);

            // Record this timer creation (initial timer 1)
            let initialTimersEntry : Types.MainerAgentTimers = {
                action1RegularityInSeconds = timerRegularity;
                action2RegularityInSeconds = action2RegularityInSeconds;
                initialTimerId1 = ?initialTimerId;
                randomInitialTimer1InSeconds = ?randomInitialTimer;
                recurringTimerId1 = null;
                recurringTimerId2 = null;
                creationTimestamp = Nat64.fromNat(Int.abs(Time.now()));
                createdBy = callerPrincipal;
                calledFromEndpoint = calledFromEndpoint;
            };
            ignore putAgentTimers(initialTimersEntry);

            // For reporting purposes
            action1RegularityInSeconds := timerRegularity;
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - setTimer 1 with regularity = " # Nat.toText(timerRegularity) # " seconds, randomInitialTimer = " # Nat.toText(randomInitialTimer));
        };

        if (MAINER_AGENT_CANISTER_TYPE == #Own or MAINER_AGENT_CANISTER_TYPE == #ShareService) {
            res := res # " 2";
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - setTimer 2");
            let id =  recurringTimer<system>(#seconds action2RegularityInSeconds, triggerRecurringAction2);
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - Successfully start timer 2 with id = " # debug_show (id) # ", regularity = " # Nat.toText(action2RegularityInSeconds) # " seconds");
            recurringTimerId2 := ?id;
            addTimerToBuffer(bufferTimerId2, id);

            // Record this timer creation (recurring timer 2)
            let timersEntry : Types.MainerAgentTimers = {
                action1RegularityInSeconds = action1RegularityInSeconds;
                action2RegularityInSeconds = action2RegularityInSeconds;
                initialTimerId1 = null;
                randomInitialTimer1InSeconds = null;
                recurringTimerId1 = null;
                recurringTimerId2 = ?id;
                creationTimestamp = Nat64.fromNat(Int.abs(Time.now()));
                createdBy = callerPrincipal;
                calledFromEndpoint = calledFromEndpoint;
            };
            ignore putAgentTimers(timersEntry);

            // Trigger it right away. Without this, the first action would be delayed by the recurring timer regularity
            logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - before await triggerRecurringAction2 (immediate)");
            try {
                await triggerRecurringAction2();
            } catch (error) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - triggerRecurringAction2 threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
            };
            logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - after await triggerRecurringAction2 (immediate)");
        };

        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - exit");
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - leaving...");
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - initialTimerId1   = " # debug_show(initialTimerId1)   # ", recurringTimerId1 = " # debug_show(recurringTimerId1) # ", bufferTimerId1 size = " # Nat.toText(bufferTimerId1.size()));
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - recurringTimerId2 = " # debug_show(recurringTimerId2) # ", bufferTimerId2 size = " # Nat.toText(bufferTimerId2.size()));

        let authRecord = { auth = res };
        return #Ok(authRecord);
    };

    private func stopTimerExecution() : async Types.AuthRecordResult {
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecution - entered");
        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecution - entry");
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecution - initialTimerId1 = " # debug_show(initialTimerId1) # ", recurringTimerId1 = " # debug_show(recurringTimerId1) # ", bufferTimerId1 size = " # Nat.toText(bufferTimerId1.size()));
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecution - recurringTimerId2 = " # debug_show(recurringTimerId2) # ", bufferTimerId2 size = " # Nat.toText(bufferTimerId2.size()));

        var res = "You stopped the timers: ";

        // Cancel all timers in buffer 1
        var hasActiveTimer1 = false;
        for (i in Iter.range(0, bufferTimerId1.size() - 1)) {
            let timerId = bufferTimerId1.get(i);
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecution - Cancelling timer 1 with id = " # debug_show(timerId));
            Timer.cancelTimer(timerId);
            // Only report if we're cancelling an active timer (either initial or recurring)
            if ((initialTimerId1 != null and initialTimerId1 == ?timerId) or
                (recurringTimerId1 != null and recurringTimerId1 == ?timerId)) {
                hasActiveTimer1 := true;
            };
        };
        if (hasActiveTimer1) {
            res := res # " 1, ";
        };
        // Clear the running timer IDs we track for reporting purposes, but do NOT clear the buffer for additional robustness
        // NOT clearing bufferTimerId1 on purpose, to handle the case if Timer.cancelTimer did not actually cancel the timer
        initialTimerId1 := null;
        recurringTimerId1 := null;

        // Cancel all timers in buffer 2
        var hasActiveTimer2 = false;
        for (i in Iter.range(0, bufferTimerId2.size() - 1)) {
            let timerId = bufferTimerId2.get(i);
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecution - Cancelling timer 2 with id = " # debug_show(timerId));
            Timer.cancelTimer(timerId);
            // Only report if we're cancelling an active timer (recurring only for timer 2)
            if (recurringTimerId2 != null and recurringTimerId2 == ?timerId) {
                hasActiveTimer2 := true;
            };
        };
        if (hasActiveTimer2) {
            res := res # " 2, ";
        };
        // Clear the running timer IDs we track for reporting purposes, but do NOT clear the buffer for additional robustness
        // NOT clearing bufferTimerId2 on purpose, to handle the case if Timer.cancelTimer did not actually cancel the timer
        recurringTimerId2 := null;

        if (res == "You stopped the timers: ") {
            res := "No timers were running";
        };

        logCycleState("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecution - exit");
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecution - leaving...");
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecution - initialTimerId1 = " # debug_show(initialTimerId1) # ", recurringTimerId1 = " # debug_show(recurringTimerId1) # ", bufferTimerId1 size = " # Nat.toText(bufferTimerId1.size()));
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecution - recurringTimerId2 = " # debug_show(recurringTimerId2) # ", bufferTimerId2 size = " # Nat.toText(bufferTimerId2.size()));

        return #Ok({ auth = res });
    };

    public shared (msg) func startTimerExecutionAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        try {
            await startTimerExecution(msg.caller, "startTimerExecutionAdmin");
        } catch (error) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecutionAdmin - startTimerExecution threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
            return #Err(#Other("startTimerExecution failed: " # Error.message(error)));
        };
    };

    public shared (msg) func stopTimerExecutionAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        try {
            await stopTimerExecution();
        } catch (error) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecutionAdmin - stopTimerExecution threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
            return #Err(#Other("stopTimerExecution failed: " # Error.message(error)));
        };
    };

    public shared query (msg) func getTimerBuffersAdmin() : async Types.MainerTimerBuffersResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Convert buffers to arrays
        let buffer1Array = Buffer.toArray(bufferTimerId1);
        let buffer2Array = Buffer.toArray(bufferTimerId2);

        let timerBuffers : Types.MainerTimerBuffers = {
            bufferTimerId1 = buffer1Array;
            bufferTimerId2 = buffer2Array;
        };

        return #Ok(timerBuffers);
    };

    public shared (msg) func setTimerBufferMaxSizeAdmin(maxSize: Nat) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        TIMER_BUFFER_MAX_SIZE := maxSize;

        return #Ok({ status_code = 200 });
    };

    public shared query (msg) func getTimerBufferMaxSizeAdmin() : async Types.NatResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        return #Ok(TIMER_BUFFER_MAX_SIZE);
    };

    // Testing function for admin for ShareService
    public shared (msg) func triggerChallengeResponseAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        /* if (MAINER_AGENT_CANISTER_TYPE != #ShareService) {
            // execute the timer 1 action
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): triggerChallengeResponseAdmin - (timer 1 action) calling pullNextChallenge");
            await pullNextChallenge();
        };
        if (MAINER_AGENT_CANISTER_TYPE != #ShareAgent) {
            // execute timer 2 action
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): triggerChallengeResponseAdmin - (timer 2 action) calling processNextChallenge");
            await processNextChallenge();
        }; */
        if (MAINER_AGENT_CANISTER_TYPE == #ShareService) {
            // execute timer 2 action
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): triggerChallengeResponseAdmin - (timer 2 action) calling processNextChallenge");
            try {
                await processNextChallenge();
            } catch (error) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): triggerChallengeResponseAdmin - processNextChallenge threw: " # Error.message(error) # " (Cycles.balance() = " # Nat.toText(Cycles.balance()) # ")");
                return #Err(#Other("processNextChallenge failed: " # Error.message(error)));
            };
            let authRecord = { auth = "You triggered the response generation." };
            return #Ok(authRecord);
        } else {
            return #Err(#Unauthorized);
        };
    };

    // Upgrade Hooks
    system func preupgrade() {
        mainerCreatorCanistersStorageStable := Iter.toArray(mainerCreatorCanistersStorage.entries());
        shareAgentCanistersStorageStable := Iter.toArray(shareAgentCanistersStorage.entries());
        userToShareAgentsStorageStable := Iter.toArray(userToShareAgentsStorage.entries());

        // Convert Buffer<LLMCanister> to [Text] for stable storage
        let llmCanisterIds = Buffer.Buffer<Text>(llmCanisters.size());
        for (llmCanister in llmCanisters.vals()) {
            llmCanisterIds.add(Principal.toText(Principal.fromActor(llmCanister)));
        };
        llmCanistersStable := Buffer.toArray(llmCanisterIds);

        adminRoleAssignmentsStable := Iter.toArray(adminRoleAssignmentsStorage.entries());
    };

    system func postupgrade() {
        mainerCreatorCanistersStorage := HashMap.fromIter(Iter.fromArray(mainerCreatorCanistersStorageStable), mainerCreatorCanistersStorageStable.size(), Text.equal, Text.hash);
        mainerCreatorCanistersStorageStable := [];
        shareAgentCanistersStorage := HashMap.fromIter(Iter.fromArray(shareAgentCanistersStorageStable), shareAgentCanistersStorageStable.size(), Text.equal, Text.hash);
        shareAgentCanistersStorageStable := [];
        userToShareAgentsStorage := HashMap.fromIter(Iter.fromArray(userToShareAgentsStorageStable), userToShareAgentsStorageStable.size(), Principal.equal, Principal.hash);
        userToShareAgentsStorageStable := [];

        // Reconstruct Buffer<LLMCanister> from [Text]
        llmCanisters := Buffer.Buffer<Types.LLMCanister>(llmCanistersStable.size());
        for (canisterId in llmCanistersStable.vals()) {
            let llmCanister = actor (canisterId) : Types.LLMCanister;
            llmCanisters.add(llmCanister);
        };
        llmCanistersStable := [];

        adminRoleAssignmentsStorage := HashMap.fromIter(Iter.fromArray(adminRoleAssignmentsStable), adminRoleAssignmentsStable.size(), Text.equal, Text.hash);
        adminRoleAssignmentsStable := [];

        // Reset reporting variable for timer
        action1RegularityInSeconds := 0; // Timer is not yet set (They don't persist across upgrades)

        // Treat the post-upgrade balance as official. Cycles delivered during the
        // upgrade (e.g. via `dfx wallet send`) bypass the addCycles() flow, so
        // without this reset the next challenge would trigger the unofficial-topup
        // penalty against those cycles.
        //
        // Same INSTALL_CODE_REFUND_BUFFER applied as in the field initializer:
        // postupgrade runs INSIDE install_code (mode=upgrade), so Cycles.balance()
        // here is also the pre-refund value, ~300 B lower than reality. The
        // buffer compensates so the first storeAndSubmitResponse after upgrade
        // doesn't fire the false unofficial-topup penalty.
        officialCyclesBalance := Cycles.balance() + INSTALL_CODE_REFUND_BUFFER;
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): postupgrade - officialCyclesBalance set to " # Nat.toText(officialCyclesBalance) # " (= Cycles.balance() " # Nat.toText(Cycles.balance()) # " + INSTALL_CODE_REFUND_BUFFER " # Nat.toText(INSTALL_CODE_REFUND_BUFFER) # ")");
    };
};
