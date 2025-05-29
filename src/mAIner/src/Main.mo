import Buffer "mo:base/Buffer";
import D "mo:base/Debug";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
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

import Types "../../common/Types";
import Utils "Utils";

actor class MainerAgentCtrlbCanister() = this {

    // -------------------------------
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
    stable var GAME_STATE_CANISTER_ID : Text = "bkyz2-fmaaa-aaaaa-qaaaq-cai"; // local dev: "bkyz2-fmaaa-aaaaa-qaaaq-cai";
    stable var gameStateCanisterActor = actor (GAME_STATE_CANISTER_ID) : Types.GameStateCanister_Actor;
    
    public shared (msg) func setGameStateCanisterId(_game_state_canister_id : Text) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        GAME_STATE_CANISTER_ID := _game_state_canister_id;
        gameStateCanisterActor := actor (GAME_STATE_CANISTER_ID);
        return #Ok({ status_code = 200 });
    };

    public query (msg) func getGameStateCanisterId() : async Text {
        if (not Principal.isController(msg.caller)) {
            return "#Err(#StatusCode(401))";
        };

        return GAME_STATE_CANISTER_ID;
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
    stable let _CYCLES_MILLION = 1_000_000;
    stable let CYCLES_BILLION = 1_000_000_000;
    stable let CYCLES_TRILLION = 1_000_000_000_000;
    // TODO - Implementation: Keep in sync with SUBMISSION_CYCLES_REQUIRED in GameState
    stable let SUBMISSION_CYCLES_REQUIRED : Nat = 100 * CYCLES_BILLION; // TODO - Design: determine how many cycles are needed to process one submission (incl. judge)

    stable let SHARE_SERVICE_QUEUE_CYCLES_REQUIRED : Nat = 100 * CYCLES_BILLION; // TODO - Design: determine how many cycles are needed to process a ShareService queue item

    // The minimum cycle balance we want to maintain
    stable let CYCLE_BALANCE_MINIMUM = 250 * CYCLES_BILLION;

    // A flag for the frontend to pick up and display a message to the user
    stable var PAUSED_DUE_TO_LOW_CYCLE_BALANCE : Bool = false;

    // Internal functions to check if the canister has enough cycles
    private func sufficientCyclesToProcessChallenge(submissionCyclesRequired : Nat) : Bool {
        // The ShareService canister does not Queue or Submit
        if (MAINER_AGENT_CANISTER_TYPE == #ShareService) {
            return true;
        };

        let availableCycles = Cycles.balance();
        var requiredCycles = submissionCyclesRequired + CYCLE_BALANCE_MINIMUM;
        if (MAINER_AGENT_CANISTER_TYPE == #ShareAgent) {
            requiredCycles := requiredCycles + SHARE_SERVICE_QUEUE_CYCLES_REQUIRED;
        };
        if (availableCycles < requiredCycles) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): CYCLE BALANCE TOO LOW TO PROCESS CHALLENGE:");
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): requiredCycles  = " # debug_show(requiredCycles));
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): availableCycles = " # debug_show(availableCycles));
            return false;
        };
        return true;
    };

    private func sufficientCyclesToSubmit(submissionCyclesRequired : Nat) : Bool {
        // The ShareService canister does not submit
        if (MAINER_AGENT_CANISTER_TYPE == #ShareService) {
            return true;
        };

        let availableCycles = Cycles.balance();
        let requiredCycles = submissionCyclesRequired + CYCLE_BALANCE_MINIMUM;
        if (availableCycles < requiredCycles) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): CYCLE BALANCE TOO LOW TO SUBMIT RESPONSE TO GAMESTATE:");
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): requiredCycles  = " # debug_show(requiredCycles));
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): availableCycles = " # debug_show(availableCycles));
            return false;
        };
        return true;
    };

    public query (msg) func getIssueFlagsAdmin() : async Types.IssueFlagsRetrievalResult {
        // TODO - Security: put access checks in place
        /* if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        }; */
        let response : Types.IssueFlagsRecord = {
            lowCycleBalance = PAUSED_DUE_TO_LOW_CYCLE_BALANCE;
        };
        return #Ok(response);
    };

    // Statistics
    stable var TOTAL_MAINER_CYCLES_BURNT : Nat = 100 * CYCLES_BILLION; // Initial value represents costs for creating this canister

    // TODO - Implementation: ensure all relevant events for cycle buring are captured and adjust cycle burning numbers below to actual values
    private func increaseTotalCyclesBurnt(cyclesBurntToAdd : Nat) : Bool {
        TOTAL_MAINER_CYCLES_BURNT := TOTAL_MAINER_CYCLES_BURNT + cyclesBurntToAdd;
        return true;
    };

    // TODO - Implementation: llama_cpp_canister must return this number
    stable let CYCLES_BURNT_RESPONSE_GENERATION : Nat = 200 * CYCLES_BILLION;
    let CYCLES_BURNT_LLM_CREATION : Nat = 1300 * CYCLES_BILLION;

    stable let CYCLES_BURN_RATE_DEFAULT : Types.CyclesBurnRate = Types.cyclesBurnRateDefaultLow;

    public query (msg) func getMainerStatisticsAdmin() : async Types.StatisticsRetrievalResult {
        // TODO - Security: put access checks in place
        /* if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        }; */
        var cyclesBurnRateToReturn : Types.CyclesBurnRate = CYCLES_BURN_RATE_DEFAULT;
        switch (getCurrentAgentSettings()) {
            case (null) {};
            case (?agentSettings) {
                cyclesBurnRateToReturn := Types.getCyclesBurnRate(agentSettings.cyclesBurnRate);
            };
        };
        let response : Types.StatisticsRecord = {
            totalCyclesBurnt = TOTAL_MAINER_CYCLES_BURNT;
            cycleBalance = Cycles.balance();
            cyclesBurnRate = cyclesBurnRateToReturn;
        };
        return #Ok(response);
    };

    // timer ID, so we can stop it after starting
    stable var recurringTimerId1 : ?Timer.TimerId = null;
    stable var recurringTimerId2 : ?Timer.TimerId = null;

    // Record of settings
    stable var agentSettings : List.List<Types.MainerAgentSettings> = List.nil<Types.MainerAgentSettings>();

    private func putAgentSettings(settingsEntry : Types.MainerAgentSettings) : Bool {
        agentSettings := List.push<Types.MainerAgentSettings>(settingsEntry, agentSettings);
        return true;
    };

    private func getCurrentAgentSettings() : ?Types.MainerAgentSettings {
        return List.get<Types.MainerAgentSettings>(agentSettings, 0);
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
        // TODO - Security: put access checks in place
        /* if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        }; */
        let submissions : [Types.ChallengeResponseSubmission] = getLastSubmittedResponses(5);
        return #Ok(submissions);
    };

    // Round-robin load balancer for LLM canisters to call
    private var roundRobinIndex : Nat = 0;
    private var roundRobinUseAll : Bool = true;
    private var roundRobinLLMs : Nat = 0; // Only used when roundRobinUseAll is false

    // -------------------------------------------------------------------------------
    // The C++ LLM canisters that can be called

    private var llmCanisters : Buffer.Buffer<Types.LLMCanister> = Buffer.fromArray([]);

    // Resets llmCanisters
    public shared (msg) func reset_llm_canisters() : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        llmCanisters.clear();
        return #Ok({ status_code = 200 });
    };

    // Adds an llmCanister
    public shared (msg) func add_llm_canister(llmCanisterIdRecord : Types.CanisterIDRecord) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        // TODO - Implementation: adapt cycles burnt stats
        ignore increaseTotalCyclesBurnt(CYCLES_BURNT_LLM_CREATION);
        _add_llm_canister_id(llmCanisterIdRecord);
    };
    private func _add_llm_canister_id(llmCanisterIdRecord : Types.CanisterIDRecord) : Types.StatusCodeRecordResult {
        let llmCanister = actor (llmCanisterIdRecord.canister_id) : Types.LLMCanister;
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Inside function _add_llm_canister_id. Adding llm: " # Principal.toText(Principal.fromActor(llmCanister)));
        llmCanisters.add(llmCanister);

        // Print content of the llmCanisters Buffer:
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Content of llmCanisters after addition: ");
        Buffer.iterate(
            llmCanisters,
            func(canister : Types.LLMCanister) : () {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Canister ID: " # Principal.toText(Principal.fromActor(canister)));
            },
        );
        return #Ok({ status_code = 200 });
    };

    public shared query (msg) func whoami() : async Principal {
        return msg.caller;
    };

    // Function to verify that canister is up & running
    public shared query func health() : async Types.StatusCodeRecordResult {
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

    // Admin function to set roundRobinLLMs
    public shared (msg) func setRoundRobinLLMs(_roundRobinLLMs : Nat) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        roundRobinUseAll := false;
        roundRobinLLMs := _roundRobinLLMs;
        roundRobinIndex := 0;

        return #Ok({ status_code = 200 });
    };

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
                return #Err(#StatusCode(401));
            };
            case (_) {
                return #Err(#StatusCode(400));
            };
        };
        let settingsEntry : Types.MainerAgentSettings = {
            cyclesBurnRate : Types.CyclesBurnRateDefault = settingsInput.cyclesBurnRate;
            creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            createdBy : Principal = msg.caller;
        };
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
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processRespondingToChallenge error");
                D.print(debug_show (error));
                // TODO - Error Handling
                // TODO - Design: in case of ShareService, do we refund the cycles to the ShareAgent?
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
                    challengeQuestion : Text = challengeQueueInput.challengeQuestion;
                    challengeQuestionSeed : Nat32 = challengeQueueInput.challengeQuestionSeed;
                    challengeId : Text = challengeQueueInput.challengeId;
                    challengeCreationTimestamp : Nat64 = challengeQueueInput.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = challengeQueueInput.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = challengeQueueInput.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = challengeQueueInput.challengeClosedTimestamp;
                    submissionCyclesRequired : Nat = challengeQueueInput.submissionCyclesRequired;
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
                if (not sufficientCyclesToSubmit(challengeResponseSubmissionInput.submissionCyclesRequired)) {
                    // Note: do not pause, to avoid blocking the canister in case of a single challenge with a really high cycle requirement
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - insufficientCyclesToSubmit");
                    return;
                };

                // Check if there were any unofficial cycle top ups and if so pay the appropriate fee for the Protocol's operational expenses
                var cyclesToSend = challengeResponseSubmissionInput.submissionCyclesRequired;
                if (officialCyclesBalance < Cycles.balance()) {
                    // Unofficial top ups were made, thus pay the fee for these top ups to Game State now as a share of the balances difference
                    try {
                        let cyclesForOperationalExpenses = (Cycles.balance() - officialCyclesBalance) * Types.PROTOCOL_OPERATION_FEES_CUT_PERCENT / 100;
                        cyclesToSend := cyclesToSend + cyclesForOperationalExpenses;
                    } catch (error : Error) {
                        // Continue nevertheless
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - catch error when calculating fee to pay for unofficial top ups : ");
                        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): storeAndSubmitResponse - error: " # Error.message(error));
                    };
                };

                // Add the required amount of cycles
                Cycles.add<system>(cyclesToSend);

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
                            challengeQuestion : Text = challengeResponseSubmissionInput.challengeQuestion;
                            challengeQuestionSeed : Nat32 = challengeResponseSubmissionInput.challengeQuestionSeed;
                            challengeId : Text = challengeResponseSubmissionInput.challengeId;
                            challengeCreationTimestamp : Nat64 = challengeResponseSubmissionInput.challengeCreationTimestamp;
                            challengeCreatedBy : Types.CanisterAddress = challengeResponseSubmissionInput.challengeCreatedBy;
                            challengeStatus : Types.ChallengeStatus = challengeResponseSubmissionInput.challengeStatus;
                            challengeClosedTimestamp : ?Nat64 = challengeResponseSubmissionInput.challengeClosedTimestamp;
                            submissionCyclesRequired : Nat = challengeResponseSubmissionInput.submissionCyclesRequired;
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
                                // TODO - Implementation: adapt cycles burnt stats
                                ignore increaseTotalCyclesBurnt(SUBMISSION_CYCLES_REQUIRED);
                            };
                        };
                    };
                };
            };
        };
    };

    private func respondToChallengeDoIt_(challengeQueueInput : Types.ChallengeQueueInput) : async Types.ChallengeResponseResult {
        // TODO - Implementation: probably need to improve the seed generation variability
        let maxContinueLoopCount : Nat = 6; // After this many calls to run_update, we stop.
        let num_tokens : Nat64 = 1024;
        let temp : Float = 0.8;

        var prompt : Text = "<|im_start|>user\n" #
        "This is a question about " # challengeQueueInput.challengeTopic # " " #
        "Give the answer as brief as possible. This is the question: " # challengeQueueInput.challengeQuestion # "\n" #
        "<|im_end|>\n<|im_start|>assistant\n" #
        "The answer is: ";

        let llmCanister = _getRoundRobinCanister();

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

        let generationId : Text = await Utils.newRandomUniqueId();

        // Use the generationId to create a highly variable seed or the LLM
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
        // Step 1
        // Call new_chat - this resets the prompt-cache for this conversation
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
                        };
                        if (generated_eog) {
                            break continueLoop; // Exit the loop - the challengeQueueInput is generated.
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

    // Triggered by timer 1: get next challenge and add it to the queue
    private func pullNextChallenge() : async () {
        D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - entered");

        if (MAINER_AGENT_CANISTER_TYPE == #ShareService) {
            // This should never happen, but still protect against it
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - Something is wrong. pullNextChallenge should not be called by a ShareService.");
            return;
        };

        // -----------------------------------------------------
        // Before doing anything, check if the canister has enough cycles
        if (not sufficientCyclesToProcessChallenge(SUBMISSION_CYCLES_REQUIRED)) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): pullNextChallenge - PAUSING RESPONSE GENERATION DUE TO LOW CYCLE BALANCE");
            PAUSED_DUE_TO_LOW_CYCLE_BALANCE := true;
            return;
        };
        
        // -----------------------------------------------------
        // Ok,the canister has enough cycles
        PAUSED_DUE_TO_LOW_CYCLE_BALANCE := false;

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

                // Add the challenge to the queue
                let challengeQueuedId : Text = await Utils.newRandomUniqueId();
                let challengeQueuedBy : Principal = Principal.fromActor(this);
                let challengeQueuedTo : Principal = Principal.fromActor(shareServiceCanisterActor);

                var challengeQueueInput : Types.ChallengeQueueInput = {
                    challengeTopic : Text = challenge.challengeTopic;
                    challengeTopicId : Text = challenge.challengeTopicId;
                    challengeTopicCreationTimestamp : Nat64 = challenge.challengeTopicCreationTimestamp;
                    challengeTopicStatus : Types.ChallengeTopicStatus = challenge.challengeTopicStatus;
                    challengeQuestion : Text = challenge.challengeQuestion;
                    challengeQuestionSeed : Nat32 = challenge.challengeQuestionSeed;
                    challengeId : Text = challenge.challengeId;
                    challengeCreationTimestamp : Nat64 = challenge.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = challenge.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = challenge.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = challenge.challengeClosedTimestamp;
                    submissionCyclesRequired : Nat = challenge.submissionCyclesRequired;
                    challengeQueuedId : Text = challengeQueuedId;
                    challengeQueuedBy : Principal = challengeQueuedBy;
                    challengeQueuedTo : Principal = challengeQueuedTo;
                    challengeQueuedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                };
                
                // A ShareAgent canister first sends the challenge to the Shared mAIner Service to be put in that canisters queue
                if (MAINER_AGENT_CANISTER_TYPE == #ShareAgent) {
                    // Add the cycles required for the ShareService queue (We already checked there is enough)
                    Cycles.add<system>(SHARE_SERVICE_QUEUE_CYCLES_REQUIRED);

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
                            // TODO - Implementation: adapt cycles burnt stats
                            ignore increaseTotalCyclesBurnt(SHARE_SERVICE_QUEUE_CYCLES_REQUIRED);
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

                // Accept required cycles for queue input
                let cyclesAcceptedForShareServiceQueue = Cycles.accept<system>(SHARE_SERVICE_QUEUE_CYCLES_REQUIRED);
                if (cyclesAcceptedForShareServiceQueue != SHARE_SERVICE_QUEUE_CYCLES_REQUIRED) {
                    return #Err(#Unauthorized);                    
                };

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

        // -----------------------------------------------------
        // Before doing anything, check if the canister has enough cycles
        if (not sufficientCyclesToProcessChallenge(SUBMISSION_CYCLES_REQUIRED)) {
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processNextChallenge - PAUSING RESPONSE GENERATION DUE TO LOW CYCLE BALANCE");
            PAUSED_DUE_TO_LOW_CYCLE_BALANCE := true;
            return;
        };

        // -----------------------------------------------------
        // Ok,the canister has enough cycles
        PAUSED_DUE_TO_LOW_CYCLE_BALANCE := false;

        // Process the next challenge in the challengeQueue
        switch (popChallengeQueue()) {
            case (null) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processNextChallenge - Queue is empty. Nothing to do.");
                return;
            };
            case (?challengeQueueInput) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): processNextChallenge - challengeQueueInput" # debug_show (challengeQueueInput));

                // Check if the canister has enough cycles for this particular Challenge
                if (not sufficientCyclesToProcessChallenge(challengeQueueInput.submissionCyclesRequired)) {
                    // Note: do not set pause flag
                    return;
                };

                // Process the challenge
                // Sanity checks
                if (challengeQueueInput.challengeId == "" or challengeQueueInput.challengeQuestion == "" or challengeQueueInput.challengeTopic == "") {
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
    stable var actionRegularityInSeconds = 60; // TODO - Implementation: set based on user setting for cycles burn rate

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
        var res = "You started the timers: ";
        let TIMER_REGULARITY_DEFAULT = 5; // TODO - Implementation: move to common file
        var timerRegularity = TIMER_REGULARITY_DEFAULT;

        // Calculate timer regularity based on cycles burn rate for user's mAIner
        if (MAINER_AGENT_CANISTER_TYPE == #Own or MAINER_AGENT_CANISTER_TYPE == #ShareAgent) {
            var cyclesBurnRate = CYCLES_BURN_RATE_DEFAULT;
            switch (getCurrentAgentSettings()) {
                case (null) {
                    // use default

                };
                case (?agentSettings) {
                    cyclesBurnRate := Types.getCyclesBurnRate(agentSettings.cyclesBurnRate);
                };
            };
            timerRegularity := Types.getTimerRegularityForCyclesBurnRate(cyclesBurnRate);
        };

        if (MAINER_AGENT_CANISTER_TYPE == #Own or MAINER_AGENT_CANISTER_TYPE == #ShareAgent) {
            res := res # " 1, ";
            ignore setTimer<system>(#seconds timerRegularity,
                func () : async () {
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): setTimer 1");
                    let id =  recurringTimer<system>(#seconds actionRegularityInSeconds, triggerRecurringAction1);
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Successfully start timer 1 with id = " # debug_show (id));
                    recurringTimerId1 := ?id;
                    await triggerRecurringAction1();
            });
        };

        if (MAINER_AGENT_CANISTER_TYPE == #Own or MAINER_AGENT_CANISTER_TYPE == #ShareService) {
            res := res # " 2";
            ignore setTimer<system>(#seconds timerRegularity,
                func () : async () {
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): setTimer 2");
                    let id =  recurringTimer<system>(#seconds actionRegularityInSeconds, triggerRecurringAction2);
                    D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Successfully start timer 2 with id = " # debug_show (id));
                    recurringTimerId2 := ?id;
                    await triggerRecurringAction2();
            });
        };

        let authRecord = { auth = res };
        return #Ok(authRecord);
    };

    private func stopTimerExecution() : async Types.AuthRecordResult {
        var res = "You stopped the timers: ";

        switch (recurringTimerId1) {
            case (?id) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Stopping timer 1 with id = " # debug_show (id));
                Timer.cancelTimer(id);
                recurringTimerId1 := null;
                res := res # " 1 (id = " # Nat.toText(id) # "), ";
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Timer 1 stopped successfully.");
            };
            case null {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): There is no active timer 1.");
            };
        };

        switch (recurringTimerId2) {
            case (?id) {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Stopping timer 2 with id = " # debug_show (id));
                Timer.cancelTimer(id);
                recurringTimerId2 := null;
                res := res # " 2 (id = " # Nat.toText(id) # ")";
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): Timer 2 stopped successfully.");
            };
            case null {
                D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): There is no active timer 2.");
            };
        };

        return #Ok({ auth = res });
    };

    public shared (msg) func startTimerExecutionAdmin() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        await startTimerExecution();
    };

    public shared (msg) func stopTimerExecutionAdmin() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        await stopTimerExecution();
    };

    // TODO - Testing: remove; testing function for admin
    public shared (msg) func triggerChallengeResponseAdmin() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        if (MAINER_AGENT_CANISTER_TYPE != #ShareService) {
            // execute the timer 1 action
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): triggerChallengeResponseAdmin - (timer 1 action) calling pullNextChallenge");
            await pullNextChallenge();
        };
        if (MAINER_AGENT_CANISTER_TYPE != #ShareAgent) {
            // execute timer 2 action
            D.print("mAIner (" # debug_show(MAINER_AGENT_CANISTER_TYPE) # "): triggerChallengeResponseAdmin - (timer 2 action) calling processNextChallenge");
            await processNextChallenge();
        };
        
        let authRecord = { auth = "You triggered the response generation." };
        return #Ok(authRecord);
    };

    // Upgrade Hooks
    system func preupgrade() {
        mainerCreatorCanistersStorageStable := Iter.toArray(mainerCreatorCanistersStorage.entries());
        shareAgentCanistersStorageStable := Iter.toArray(shareAgentCanistersStorage.entries());
        userToShareAgentsStorageStable := Iter.toArray(userToShareAgentsStorage.entries());
    };

    system func postupgrade() {
        mainerCreatorCanistersStorage := HashMap.fromIter(Iter.fromArray(mainerCreatorCanistersStorageStable), mainerCreatorCanistersStorageStable.size(), Text.equal, Text.hash);
        mainerCreatorCanistersStorageStable := [];
        shareAgentCanistersStorage := HashMap.fromIter(Iter.fromArray(shareAgentCanistersStorageStable), shareAgentCanistersStorageStable.size(), Text.equal, Text.hash);
        shareAgentCanistersStorageStable := [];
        userToShareAgentsStorage := HashMap.fromIter(Iter.fromArray(userToShareAgentsStorageStable), userToShareAgentsStorageStable.size(), Principal.equal, Principal.hash);
        userToShareAgentsStorageStable := [];
    };
};
