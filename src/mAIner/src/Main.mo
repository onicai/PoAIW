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

actor class MainerAgentCtrlbCanister() = this {

    let IC0 : ICManagementCanister.IC_Management = actor ("aaaaa-aa");

    stable var MAINER_AGENT_CANISTER_TYPE : Types.MainerAgentCanisterType = #Own;

    public shared (msg) func setMainerCanisterType(_mainer_agent_canister_type : Types.MainerAgentCanisterType) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        MAINER_AGENT_CANISTER_TYPE := _mainer_agent_canister_type;

        // Avoid wrong timers from running when changing mainer canister type
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): setMainerCanisterType - Stopping Timers");
        let result = await stopTimerExecution();
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): setMainerCanisterType - " # debug_show(result));

        return #Ok({ status_code = 200 });
    };

    public query (msg) func getMainerCanisterType() : async Types.MainerAgentCanisterTypeResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };

        return #Ok(MAINER_AGENT_CANISTER_TYPE);
    };

    // -------------------------------
    stable var GAME_STATE_CANISTER_ID : Text = "r5m5y-diaaa-aaaaa-qanaa-cai"; // prd
    
    public shared (msg) func setGameStateCanisterId(_game_state_canister_id : Text) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        GAME_STATE_CANISTER_ID := _game_state_canister_id;
        return #Ok({ status_code = 200 });
    };

    public query (msg) func getGameStateCanisterId() : async Text {
        if (not Principal.isController(msg.caller)) {
            return "#Err(#StatusCode(401))";
        };

        return GAME_STATE_CANISTER_ID;
    };

    // Flag to pause mAIner for maintenance
    stable var MAINTENANCE : Bool = true;

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

    // Official cycle balance
    stable var officialCyclesBalance : Nat = Cycles.balance(); // TODO - Implementation: ensure this picks up the cycles the mAIner receives during creation
    stable var officialCycleTopUpsStorage : List.List<Types.OfficialMainerCycleTopUp> = List.nil<Types.OfficialMainerCycleTopUp>();
    
    public shared (msg) func addCycles() : async Types.AddCyclesResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // Accept the cycles the call is charged with
        let cyclesAdded = Cycles.accept<system>(Cycles.available());
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addCycles - Accepted " # Nat.toText(cyclesAdded) # " Cycles from caller " # Principal.toText(msg.caller));

        // Unpause the mAIner if it was paused due to low cycle balance
        PAUSED_DUE_TO_LOW_CYCLE_BALANCE := false;

        // Add to official cycle balance and store all official top ups
        if (Principal.equal(msg.caller, Principal.fromText(GAME_STATE_CANISTER_ID))) {
            // Game State can make official top ups (via its top up flow)
            officialCyclesBalance := officialCyclesBalance + cyclesAdded;
            let topUpEntry : Types.OfficialMainerCycleTopUp = {
                amountAdded : Nat = cyclesAdded;
                newOfficialCycleBalance : Nat = officialCyclesBalance;
                creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                sentBy : Principal = msg.caller;
            };
            officialCycleTopUpsStorage := List.push<Types.OfficialMainerCycleTopUp>(topUpEntry, officialCycleTopUpsStorage);
        };
        
        return #Ok({
            added : Bool = true;
            amount : Nat = cyclesAdded;
        });
    };

    // -------------------------------
    stable var SHARE_SERVICE_CANISTER_ID : Text = "bkyz2-fmaaa-aaaaa-qaaaq-cai"; // Dummy value; Only used by ShareAgent
    stable var shareServiceCanisterActor = actor (SHARE_SERVICE_CANISTER_ID) : Types.MainerCanister_Actor;
    
    public shared (msg) func setShareServiceCanisterId(_share_service_canister_id : Text) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        SHARE_SERVICE_CANISTER_ID := _share_service_canister_id;
        shareServiceCanisterActor := actor (SHARE_SERVICE_CANISTER_ID);
        return #Ok({ status_code = 200 });
    };

    public query (msg) func getShareServiceCanisterId() : async Text {
        if (not Principal.isController(msg.caller)) {
            return "#Err(#StatusCode(401))";
        };

        return SHARE_SERVICE_CANISTER_ID;
    };

    // --------------------------------------------------------------------------
// Storage & functions used by SharedService mAiner canister to manage SharedAgent mAIner canisters

    // Official mAIner Creator canisters
    stable var mainerCreatorCanistersStorageStable : [(Text, Types.OfficialProtocolCanister)] = [];
    var mainerCreatorCanistersStorage : HashMap.HashMap<Text, Types.OfficialProtocolCanister> = HashMap.HashMap(0, Text.equal, Text.hash);
    
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
    stable var shareAgentCanistersStorageStable : [(Text, Types.OfficialMainerAgentCanister)] = [];
    var shareAgentCanistersStorage : HashMap.HashMap<Text, Types.OfficialMainerAgentCanister> = HashMap.HashMap(0, Text.equal, Text.hash);
    stable var userToShareAgentsStorageStable : [(Principal, List.List<Types.OfficialMainerAgentCanister>)] = [];
    var userToShareAgentsStorage : HashMap.HashMap<Principal, List.List<Types.OfficialMainerAgentCanister>> = HashMap.HashMap(0, Principal.equal, Principal.hash);

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

    // Caution: function that returns all ShareAgent canisters (TODO - Security: decide if needed)
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

    // --------------------------------------------------------------------------
    // Orthogonal Persisted Data storage

    
    // The minimum cycle balance we want to maintain
    stable let CYCLE_BALANCE_MINIMUM = 250 * Constants.CYCLES_BILLION;

    // A flag for the frontend to pick up and display a message to the user
    stable var PAUSED_DUE_TO_LOW_CYCLE_BALANCE : Bool = false;

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
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let response : Types.IssueFlagsRecord = {
            lowCycleBalance = PAUSED_DUE_TO_LOW_CYCLE_BALANCE;
        };
        return #Ok(response);
    };

    // Statistics
    // TODO - Implementation: set based on cycles flow data calculated in GameState
    stable var TOTAL_MAINER_CYCLES_BURNT : Nat = 100 * Constants.CYCLES_BILLION; // Initial value represents costs for creating this canister

    // TODO - Implementation: ensure all relevant events for cycle buring are captured and adjust cycle burning numbers below to actual values
    private func increaseTotalCyclesBurnt(cyclesBurntToAdd : Nat) : Bool {
        TOTAL_MAINER_CYCLES_BURNT := TOTAL_MAINER_CYCLES_BURNT + cyclesBurntToAdd;
        return true;
    };

    // TODO - Implementation: set based on cycles flow data calculated in GameState
    stable let CYCLES_BURNT_RESPONSE_GENERATION : Nat = 200 * Constants.CYCLES_BILLION;

    // This is just a placeholder to be used until the startTimerExecution is called.
    stable let CYCLES_BURN_RATE_DEFAULT : Types.CyclesBurnRate = {
        cycles : Nat = 1 * Constants.CYCLES_TRILLION;
        timeInterval : Types.TimeInterval = #Daily;
    };

    public query (msg) func getMainerStatisticsAdmin() : async Types.StatisticsRetrievalResult {
        if (not Principal.isController(msg.caller)) {
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

    // timer IDs for reporting purposes (actual stopping uses the buffers)
    // Note: they're stable for historical reasons; could be transient because timers do not survive upgrades
    //       is ok, because startTimer & stopTimer functions will reset them
    stable var initialTimerId1 : ?Timer.TimerId = null;  // For reporting only
    stable var recurringTimerId1 : ?Timer.TimerId = null;
    stable var recurringTimerId2 : ?Timer.TimerId = null;

    // Configurable buffer max size for timer IDs
    stable var TIMER_BUFFER_MAX_SIZE : Nat = 4;

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
    stable var agentSettings : List.List<Types.MainerAgentSettings> = List.nil<Types.MainerAgentSettings>();

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

    // FIFO queue of challenges: retrieved from GameState; to be processed
    stable var MAX_CHALLENGES_IN_QUEUE : Nat = 5;
    stable var challengeQueue : List.List<Types.ChallengeQueueInput> = List.nil<Types.ChallengeQueueInput>();

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

    public query (msg) func getChallengeQueueAdmin() : async Types.ChallengeQueueInputsResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let challengeQueueInputs : [Types.ChallengeQueueInput] = List.toArray<Types.ChallengeQueueInput>(challengeQueue);
        return #Ok(challengeQueueInputs);
    };

    public shared (msg) func resetChallengeQueueAdmin() : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        challengeQueue := List.nil<Types.ChallengeQueueInput>();
        return #Ok({ status_code = 200 });
    };

    // Record of generated responses
    stable var generatedResponses : List.List<Types.ChallengeResponseSubmissionInput> = List.nil<Types.ChallengeResponseSubmissionInput>();

    private func putGeneratedResponse(responseEntry : Types.ChallengeResponseSubmissionInput) : Bool {
        generatedResponses := List.push<Types.ChallengeResponseSubmissionInput>(responseEntry, generatedResponses);
        return true;
    };

    private func getGeneratedResponse(challengeId : Text) : ?Types.ChallengeResponseSubmissionInput {
        return List.find<Types.ChallengeResponseSubmissionInput>(generatedResponses, func(responseEntry : Types.ChallengeResponseSubmissionInput) : Bool { responseEntry.challengeId == challengeId });
    };

    private func getGeneratedResponses() : [Types.ChallengeResponseSubmissionInput] {
        return List.toArray<Types.ChallengeResponseSubmissionInput>(generatedResponses);
    };

    private func removeGeneratedResponse(challengeId : Text) : Bool {
        generatedResponses := List.filter(generatedResponses, func(responseEntry : Types.ChallengeResponseSubmissionInput) : Bool { responseEntry.challengeId != challengeId });
        return true;
    };

    // Record of submitted responses
    stable var submittedResponses : List.List<Types.ChallengeResponseSubmission> = List.nil<Types.ChallengeResponseSubmission>();

    private func putSubmittedResponse(responseEntry : Types.ChallengeResponseSubmission) : Bool {
        submittedResponses := List.push<Types.ChallengeResponseSubmission>(responseEntry, submittedResponses);
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
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let submissions : [Types.ChallengeResponseSubmission] = getSubmittedResponses();
        return #Ok(submissions);
    };

    public query (msg) func getRecentSubmittedResponsesAdmin() : async Types.ChallengeResponseSubmissionsResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let submissions : [Types.ChallengeResponseSubmission] = getLastSubmittedResponses(5);
        return #Ok(submissions);
    };

    // -------------------------------------------------------------------------------
    // The C++ LLM canisters that can be called

    stable var llmCanistersStable : [Text] = [];
    private var llmCanisters : Buffer.Buffer<Types.LLMCanister> = Buffer.fromArray([]);

    // Round-robin load balancer for LLM canisters to call
    private var roundRobinIndex : Nat = 0;
    private var roundRobinUseAll : Bool = true;
    private var roundRobinLLMs : Nat = 0; // Only used when roundRobinUseAll is false

    public shared query (msg) func get_llm_canisters() : async Types.LlmCanistersRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
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
            return #Err(#StatusCode(401));
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "):  reset_llm_canisters - Resetting all LLM canisters & round-robin state");
        llmCanisters.clear();
        resetRoundRobinLLMs_();
        return #Ok({ status_code = 200 });
    };

    public shared (msg) func add_llm_canister(llmCanisterIdRecord : Types.CanisterIDRecord) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "):  add_llm_canister - Adding llm: " # llmCanisterIdRecord.canister_id);
        let llmCanister = actor (llmCanisterIdRecord.canister_id) : Types.LLMCanister;
        llmCanisters.add(llmCanister);
        return #Ok({ status_code = 200 });
    };

    public shared (msg) func remove_llm_canister(llmCanisterIdRecord : Types.CanisterIDRecord) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
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
            return #Err(#StatusCode(401));
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
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
            return #Err(#StatusCode(401));
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
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
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
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
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        return #Ok({ status_code = 200 });
    };

    // Admin function to verify that mainer_ctrlb_canister is a controller of all the llm canisters
    public shared (msg) func checkAccessToLLMs() : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
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

    // TODO: deprecate this function - use get_llm_canisters instead
    public query (msg) func getLLMCanisterIds() : async Types.CanisterAddressesResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
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
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
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
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
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
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
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
        let stopResult = await stopTimerExecution();
        ignore startTimerExecution();

        return #Ok({ status_code = 200 });
    };

    // Respond to challenges

    private func getChallengeFromGameStateCanister() : async Types.ChallengeResult {
        let gameStateCanisterActor = actor (GAME_STATE_CANISTER_ID) : Types.GameStateCanister_Actor;
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): calling getRandomOpenChallenge of gameStateCanisterActor = " # Principal.toText(Principal.fromActor(gameStateCanisterActor)));
        let result : Types.ChallengeResult = await gameStateCanisterActor.getRandomOpenChallenge();
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): getRandomOpenChallenge returned.");
        return result;
    };

    private func processRespondingToChallenge(challengeQueueInput : Types.ChallengeQueueInput) : async () {
        // Generate the response for the challengeQueueInput and:
        // (-) 'Own' canister submits it to GameState
        // (-) 'ShareService' canister sends it back to the 'ShareAgent' canister which submits it to GameState

        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processRespondingToChallenge - calling respondToChallengeDoIt_");
        let respondingResult : Types.ChallengeResponseResult = await respondToChallengeDoIt_(challengeQueueInput);
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processRespondingToChallenge - returned from respondToChallengeDoIt_");
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondingResult = " # debug_show (respondingResult));

        switch (respondingResult) {
            case (#Err(error)) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processRespondingToChallenge error" # debug_show (error));
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): WARNING - ShareService is likely broken & admin must call resetChallengeQueueAdmin of the ShareAgent " # debug_show(challengeQueueInput.challengeQueuedBy) # " once the ShareService is fixed");
                // TODO - Error Handling
                // TODO - Design: in case of ShareService, do we refund the cycles to the ShareAgent?
                // NOTE:
                // - We are NOT sending anything back to the ShareAgent.
                // - This is the safest approach to avoid sucking all cycles out of the ShareAgent in case the ShareService is not working
                // - The ShareAgent's challengeQueue will simply fill up with challenges that cannot be processed
                //
                // -> Admin must run a script to reset the challengeQueue of all the ShareAgent caniseters once the ShareService is fixed
            };
            case (#Ok(respondingOutput : Types.ChallengeResponse)) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processRespondingToChallenge - calling putGeneratedResponse");
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): respondingOutput = " # debug_show (respondingOutput));
                // TODO - Implementation: adapt cycles burnt stats
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
        let shareAgentCanisterActor = actor (Principal.toText(challengeResponseSubmissionInput.challengeQueuedBy)) : Types.MainerCanister_Actor;
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): sendResponseToShareAgent- calling addChallengeResponseToShareAgent of shareAgentCanisterActor = " # Principal.toText(Principal.fromActor(shareAgentCanisterActor)));
        let result : Types.StatusCodeRecordResult = await shareAgentCanisterActor.addChallengeResponseToShareAgent(challengeResponseSubmissionInput);
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): sendResponseToShareAgent - returned from addChallengeResponseToShareAgent.challengeResponseSubmissionInput with result = " # debug_show(result));
    };

    // Callback function of ShareAgent canister to receive the challengeResponseSubmissionInput from the ShareService canister
    public shared (msg) func addChallengeResponseToShareAgent(challengeResponseSubmissionInput : Types.ChallengeResponseSubmissionInput) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

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
        // Store the generated response
        let storeResult : Bool = putGeneratedResponse(challengeResponseSubmissionInput);
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - returned from putGeneratedResponse");

        switch (storeResult) {
            case (false) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - storeResult error");
                // TODO - Error Handling
            };
            case (true) {
                // Check if the canister still has enough cycles to submit it
                // Check against the number sent by the GameState for this particular Challenge
                if (not sufficientCyclesToSubmit(challengeResponseSubmissionInput.cyclesSubmitResponse)) {
                    // Note: do not pause, to avoid blocking the canister in case of a single challenge with a really high cycle requirement
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - insufficientCyclesToSubmit");
                    return;
                };

                // Check if there were any unofficial cycle top ups and if so pay the appropriate fee for the Protocol's operational expenses
                var cyclesToSend = challengeResponseSubmissionInput.cyclesSubmitResponse;
                if (officialCyclesBalance < Cycles.balance()) {
                    // Unofficial top ups were made, thus pay the fee for these top ups to Game State now as a share of the balances difference
                    // Use protocolOperationFeesCut that was sent by the GameState canister with the Challenge
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - Unofficial top ups were made");
                    try {
                        let cyclesForOperationalExpenses = (Cycles.balance() - officialCyclesBalance) * challengeResponseSubmissionInput.protocolOperationFeesCut / 100;
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
                Cycles.add<system>(cyclesToSend);

                let gameStateCanisterActor = actor (GAME_STATE_CANISTER_ID) : Types.GameStateCanister_Actor;
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - calling submitChallengeResponse of gameStateCanisterActor = " # Principal.toText(Principal.fromActor(gameStateCanisterActor)));
                let submitMetadaResult : Types.ChallengeResponseSubmissionMetadataResult = await gameStateCanisterActor.submitChallengeResponse(challengeResponseSubmissionInput);
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse  - returned from gameStateCanisterActor.submitChallengeResponse");
                switch (submitMetadaResult) {
                    case (#Err(error)) {
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - submitMetada error");
                        D.print(debug_show (error));
                        // TODO - Error Handling
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
                        // Any outstanding top up fees were paid so reset official balance to reflect this
                        officialCyclesBalance := Cycles.balance();

                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - calling putSubmittedResponse");
                        let putResult = putSubmittedResponse(challengeResponseSubmission);
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - return from putSubmittedResponse");
                        switch (putResult) {
                            case (false) {
                                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - putResult error");
                                // TODO - Error Handling
                            };
                            case (true) {
                                // TODO - Implementation: adapt cycles burnt stats - also, check we're not counting double...
                                ignore increaseTotalCyclesBurnt(CYCLES_BURNT_RESPONSE_GENERATION);
                            };
                        };
                    };
                };
            };
        };
    };

    private func respondToChallengeDoIt_(challengeQueueInput : Types.ChallengeQueueInput) : async Types.ChallengeResponseResult {
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

        let generationId : Text = await Utils.newRandomUniqueId();

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
                let downloadMainerPromptCacheBytesChunkRecordResult: Types.DownloadMainerPromptCacheBytesChunkRecordResult = await retryGameStateMainerPromptCacheChunkDownloadWithDelay(gameStateCanisterActor, downloadMainerPromptCacheBytesChunkInput, maxAttempts, delay);
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
                fileUploadRecordResult := await retryLlmPrompCacheChunkUploadWithDelay(llmCanister, uploadChunk, maxAttempts, delay);
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
                
                // TODO - Implementation: introduce a delay using a timer...
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
                
                // TODO - Implementation: introduce a delay using a timer...
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

        if (MAINER_AGENT_CANISTER_TYPE == #ShareService) {
            // This should never happen, but still protect against it
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - Something is wrong. pullNextChallenge should not be called by a ShareService.");
            return;
        };

        // -----------------------------------------------------
        // Check if the queue already has enough challenges
        if (List.size(challengeQueue) >= MAX_CHALLENGES_IN_QUEUE) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - Already have enough Challenges in the queue. Not adding more.");
            return;
        };

        // -----------------------------------------------------
        // Get the next challenge from GameState canister
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - calling getChallengeFromGameStateCanister.");
        let challengeResult : Types.ChallengeResult = await getChallengeFromGameStateCanister();
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - received challengeResult from getChallengeFromGameStateCanister: " # debug_show (challengeResult));
        switch (challengeResult) {
            case (#Err(error)) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - challengeResult error : " # debug_show (error));
                // TODO - Error Handling
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
                let challengeQueuedId : Text = await Utils.newRandomUniqueId();
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
                    Cycles.add<system>(challenge.cyclesGenerateResponseSactrlSsctrl);

                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - calling addChallengeToShareServiceQueue of shareServiceCanisterActor = " # Principal.toText(Principal.fromActor(shareServiceCanisterActor)));
                    let challegeQueueInputResult = await shareServiceCanisterActor.addChallengeToShareServiceQueue(challengeQueueInput);
                    
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

                // TODO: make sure the cycles are sufficient
                // Accept required cycles for queue input
                let cyclesAcceptedForShareServiceQueue = Cycles.accept<system>(challengeQueueInput.cyclesGenerateResponseSactrlSsctrl);
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): addChallengeToShareServiceQueue - cyclesAcceptedForShareServiceQueue = " # Nat.toText(cyclesAcceptedForShareServiceQueue) # " from caller " # Principal.toText(msg.caller));

                // Store it in the queue
                let _pushResult_ = pushChallengeQueue(challengeQueueInput);
                return #Ok(challengeQueueInput);                        
            };
        };
    };    

    private func processNextChallenge() : async () {
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processNextChallenge - entered");

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
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
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

        // TODO - Security: Only official mAIner Creator canisters may call this
        // switch (getMainerCreatorCanister(Principal.toText(msg.caller))) {
        //     case (null) { return #Err(#Unauthorized); };
        //     case (?mainerCreatorEntry) {
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
            // };
        // };
    };

    // TODO - Testing: remove; admin Function to add new mAIner ShareAgent for testing
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
    stable var action1RegularityInSeconds = 0; // Timer is not yet set 

    // ----------------------------------------------------------
    // How often Own and ShareService mAIners wake up to process the next challenge from the queue
    // TODO: revisit for #Own mAiners...
    stable var action2RegularityInSeconds = 5; 

    stable var cyclesBurnRateFromGameState = CYCLES_BURN_RATE_DEFAULT; // Just set it to some default value. The actual value is retrieved from the GameState in startTimerExecution()
   
    public shared (msg) func setTimerAction2RegularityInSecondsAdmin(_action2RegularityInSeconds : Nat) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        action2RegularityInSeconds := _action2RegularityInSeconds;
        // Restart the timer with the new regularity
        let _ = await startTimerExecution();
        return #Ok({ status_code = 200 });
    };

    public shared query (msg) func getTimerActionRegularityInSecondsAdmin() : async Types.MainerTimersResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        return #Ok({
            action1RegularityInSeconds = action1RegularityInSeconds;
            action2RegularityInSeconds = action2RegularityInSeconds;
        });
    };
    // ----------------------------------------------------------

    private func triggerRecurringAction1() : async () {
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Recurring action 1 was triggered");
        let result = await pullNextChallenge();
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Recurring action 1 result");
        D.print(debug_show (result));
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Recurring action 1 result");
    };

    private func triggerRecurringAction2() : async () {
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Recurring action 2 was triggered");
        let result = await processNextChallenge();
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Recurring action 2 result");
        D.print(debug_show (result));
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Recurring action 2 result");
    };

    
    private func startTimerExecution() : async Types.AuthRecordResult {
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - entered");
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - initialTimerId1 = " # debug_show(initialTimerId1) # ", recurringTimerId1 = " # debug_show(recurringTimerId1) # ", bufferTimerId1 size = " # Nat.toText(bufferTimerId1.size()));
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - recurringTimerId2 = " # debug_show(recurringTimerId2) # ", bufferTimerId2 size = " # Nat.toText(bufferTimerId2.size()));

        var res = "You started the timers: ";
        let TIMER_REGULARITY_DEFAULT = 5; // TODO - Implementation: move to common file
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
                    let cyclesBurnRateResult : Types.CyclesBurnRateResult = await gameStateCanisterActor.getCyclesBurnRate(agentSettings.cyclesBurnRate);
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
            let cyclesUsedResult : Types.NatResult = await gameStateCanisterActor.getMainerCyclesUsedPerResponse();
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
            let _ = await stopTimerExecution();

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
                    await triggerRecurringAction1();
            });
            // Store the initial timer ID for reporting and cancellation
            initialTimerId1 := ?initialTimerId;
            addTimerToBuffer(bufferTimerId1, initialTimerId);

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
            // Trigger it right away. Without this, the first action would be delayed by the recurring timer regularity
            await triggerRecurringAction2();
        };

        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - leaving...");
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - initialTimerId1   = " # debug_show(initialTimerId1)   # ", recurringTimerId1 = " # debug_show(recurringTimerId1) # ", bufferTimerId1 size = " # Nat.toText(bufferTimerId1.size()));
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): startTimerExecution - recurringTimerId2 = " # debug_show(recurringTimerId2) # ", bufferTimerId2 size = " # Nat.toText(bufferTimerId2.size()));

        let authRecord = { auth = res };
        return #Ok(authRecord);
    };

    private func stopTimerExecution() : async Types.AuthRecordResult {
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecution - entered");
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

        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecution - leaving...");
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecution - initialTimerId1 = " # debug_show(initialTimerId1) # ", recurringTimerId1 = " # debug_show(recurringTimerId1) # ", bufferTimerId1 size = " # Nat.toText(bufferTimerId1.size()));
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): stopTimerExecution - recurringTimerId2 = " # debug_show(recurringTimerId2) # ", bufferTimerId2 size = " # Nat.toText(bufferTimerId2.size()));

        return #Ok({ auth = res });
    };

    public shared (msg) func startTimerExecutionAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        await startTimerExecution();
    };

    public shared (msg) func stopTimerExecutionAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        await stopTimerExecution();
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
            return #Err(#StatusCode(401));
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
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
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
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
            await processNextChallenge();
            let authRecord = { auth = "You triggered the response generation." };
            return #Ok(authRecord);
        } else {
            return #Err(#StatusCode(401));
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

        // Reset reporting variable for timer
        action1RegularityInSeconds := 0; // Timer is not yet set (They don't persist across upgrades)
    };
};
