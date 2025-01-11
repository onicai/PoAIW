//import D "mo:base/Debug";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Cycles "mo:base/ExperimentalCycles";
import HashMap "mo:base/HashMap";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat "mo:base/Nat";

import Types "./Types";
import Utils "Utils";

actor class GameStateCanister() = this {

    // Official Challenger canisters
    stable var challengerCanistersStorageStable : [(Text, Types.OfficialProtocolCanister)] = [];
    var challengerCanistersStorage : HashMap.HashMap<Text, Types.OfficialProtocolCanister> = HashMap.HashMap(0, Text.equal, Text.hash);
    
    private func putChallengerCanister(canisterAddress : Text, canisterEntry : Types.OfficialProtocolCanister) : Bool {
        challengerCanistersStorage.put(canisterAddress, canisterEntry);
        return true;
    };

    private func getChallengerCanister(canisterAddress : Text) : ?Types.OfficialProtocolCanister {
        switch (challengerCanistersStorage.get(canisterAddress)) {
            case (null) { return null; };
            case (?canisterEntry) { return ?canisterEntry; };
        };
    };

    private func removeChallengerCanister(canisterAddress : Text) : Bool {
        switch (challengerCanistersStorage.get(canisterAddress)) {
            case (null) { return false; };
            case (?canisterEntry) {
                let removeResult = challengerCanistersStorage.remove(canisterAddress);
                return true;
            };
        };
    };

    // Official Judge canisters
    stable var judgeCanistersStorageStable : [(Text, Types.OfficialProtocolCanister)] = [];
    var judgeCanistersStorage : HashMap.HashMap<Text, Types.OfficialProtocolCanister> = HashMap.HashMap(0, Text.equal, Text.hash);
    
    private func putJudgeCanister(canisterAddress : Text, canisterEntry : Types.OfficialProtocolCanister) : Bool {
        judgeCanistersStorage.put(canisterAddress, canisterEntry);
        return true;
    };

    private func getJudgeCanister(canisterAddress : Text) : ?Types.OfficialProtocolCanister {
        switch (judgeCanistersStorage.get(canisterAddress)) {
            case (null) { return null; };
            case (?canisterEntry) { return ?canisterEntry; };
        };
    };

    private func removeJudgeCanister(canisterAddress : Text) : Bool {
        switch (judgeCanistersStorage.get(canisterAddress)) {
            case (null) { return false; };
            case (?canisterEntry) {
                let removeResult = judgeCanistersStorage.remove(canisterAddress);
                return true;
            };
        };
    };

    private func getRandomJudgeCanister() : ?Types.OfficialProtocolCanister {
        // TODO: this function isn't random but always returns the first entry
        let canisterIds : Iter.Iter<Types.OfficialProtocolCanister> = judgeCanistersStorage.vals();
        switch (canisterIds.next()) {
            case (null) { return null; };
            case (?canisterEntry) { return ?canisterEntry; };
        };
    };

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

    // Official mAIner agent canisters (owned by users)
    stable var mainerAgentCanistersStorageStable : [(Text, Types.OfficialProtocolCanister)] = [];
    var mainerAgentCanistersStorage : HashMap.HashMap<Text, Types.OfficialProtocolCanister> = HashMap.HashMap(0, Text.equal, Text.hash);
    
    private func putMainerAgentCanister(canisterAddress : Text, canisterEntry : Types.OfficialProtocolCanister) : Bool {
        switch (getMainerAgentCanister(canisterAddress)) {
            case (null) {
                mainerAgentCanistersStorage.put(canisterAddress, canisterEntry);
                return true;
            };
            case (?canisterEntry) { return false; }; //existing entry
        };
    };

    private func getMainerAgentCanister(canisterAddress : Text) : ?Types.OfficialProtocolCanister {
        switch (mainerAgentCanistersStorage.get(canisterAddress)) {
            case (null) { return null; };
            case (?canisterEntry) { return ?canisterEntry; };
        };
    };

    private func removeMainerAgentCanister(canisterAddress : Text) : Bool {
        switch (mainerAgentCanistersStorage.get(canisterAddress)) {
            case (null) { return false; };
            case (?canisterEntry) {
                let removeResult = mainerAgentCanistersStorage.remove(canisterAddress);
                return true;
            };
        };
    };

    // Open challenges
    stable var openChallengesStorageStable : [(Text, Types.Challenge)] = [];
    var openChallengesStorage : HashMap.HashMap<Text, Types.Challenge> = HashMap.HashMap(0, Text.equal, Text.hash);

    private func putOpenChallenge(challengeId : Text, challengeEntry : Types.Challenge) : Bool {
        openChallengesStorage.put(challengeId, challengeEntry);
        return true;
    };

    private func getOpenChallenge(challengeId : Text) : ?Types.Challenge {
        switch (openChallengesStorage.get(challengeId)) {
            case (null) { return null; };
            case (?challengeEntry) { return ?challengeEntry; };
        };
    };

    private func getOpenChallenges() : [Types.Challenge] {
        return Iter.toArray(openChallengesStorage.vals());
    };

    private func removeOpenChallenge(challengeId : Text) : Bool {
        switch (openChallengesStorage.get(challengeId)) {
            case (null) { return false; };
            case (?challengeEntry) {
                let removeResult = openChallengesStorage.remove(challengeId);
                return true;
            };
        };
    };

    // Recently closed challenges
    stable var closedChallenges : List.List<Types.Challenge> = List.nil<Types.Challenge>();

    private func putClosedChallenge(challengeEntry : Types.Challenge) : Bool {
        let putResult = List.push<Types.Challenge>(challengeEntry, closedChallenges);
        return true;
    };

    private func getClosedChallenge(challengeId : Text) : ?Types.Challenge {
        return List.find<Types.Challenge>(closedChallenges, func(challengeEntry: Types.Challenge) : Bool { challengeEntry.challengeId == challengeId } ); 
    };

    private func getClosedChallenges() : [Types.Challenge] {
        return List.toArray<Types.Challenge>(closedChallenges);
    };

    private func removeClosedChallenge(challengeId : Text) : Bool {
        closedChallenges := List.filter(closedChallenges, func(challengeEntry: Types.Challenge) : Bool { challengeEntry.challengeId != challengeId });
        return true;
    };

    // Challenges archive
    stable var archivedChallenges : List.List<Types.Challenge> = List.nil<Types.Challenge>();

    private func putArchivedChallenge(challengeEntry : Types.Challenge) : Bool {
        let putResult = List.push<Types.Challenge>(challengeEntry, archivedChallenges);
        return true;
    };

    private func getArchivedChallenge(challengeId : Text) : ?Types.Challenge {
        return List.find<Types.Challenge>(archivedChallenges, func(challengeEntry: Types.Challenge) : Bool { challengeEntry.challengeId == challengeId } ); 
    };

    private func getArchivedChallenges() : [Types.Challenge] {
        return List.toArray<Types.Challenge>(archivedChallenges);
    };

    private func removeArchivedChallenge(challengeId : Text) : Bool {
        archivedChallenges := List.filter(archivedChallenges, func(challengeEntry: Types.Challenge) : Bool { challengeEntry.challengeId != challengeId });
        return true;
    };

    // Challenges helper functions
    private func getRandomChallenge(status : Types.ChallengeStatus) : async ?Types.Challenge {
        switch (status) {
            case (#Open) {
                let challengeIds : [Text] = Iter.toArray(challengerCanistersStorage.keys());
                let numberOfChallenges : Nat = challengeIds.size();

                let randomInt : ?Int = await Utils.nextRandomInt(0, numberOfChallenges);
                switch (randomInt) {
                    case (?intToUse) {
                        return getOpenChallenge(challengeIds[Int.abs(intToUse)]);
                    };
                    case (_) { return null; };
                };
            };
            case (_) { return null; };
        };
    };

    private func verifyChallenge(status : Types.ChallengeStatus, challengeId: Text) : Bool {
        switch (status) {
            case (#Open) {
                switch (getOpenChallenge(challengeId)) {
                    case (null) { return false; };
                    case (?challengeEntry) { return true; };
                };
            };
            case (#Closed) {
                switch (getClosedChallenge(challengeId)) {
                    case (null) { return false; };
                    case (?challengeEntry) { return true; };
                };
            };
            case (#Archived) {
                switch (getArchivedChallenge(challengeId)) {
                    case (null) { return false; };
                    case (?challengeEntry) { return true; };
                };
            };
            case (_) { return false; };
        };
    };

    private func getJudgeCanisterForChallenge(status : Types.ChallengeStatus, challengeId: Text) : ?Types.OfficialProtocolCanister {
        switch (status) {
            case (#Open) {
                switch (getOpenChallenge(challengeId)) {
                    case (null) { return null; };
                    case (?challengeEntry) {
                        return getJudgeCanister(challengeEntry.responsibleJudgeAddress);
                    };
                };
            };
            case (#Closed) {
                switch (getClosedChallenge(challengeId)) {
                    case (null) { return null; };
                    case (?challengeEntry) {
                        return getJudgeCanister(challengeEntry.responsibleJudgeAddress);
                    };
                };
            };
            case (#Archived) {
                switch (getArchivedChallenge(challengeId)) {
                    case (null) { return null; };
                    case (?challengeEntry) {
                        return getJudgeCanister(challengeEntry.responsibleJudgeAddress);
                    };
                };
            };
            case (_) { return null; };
        };
    };
    

    // TODO: settings
    

    // -------------------------------------------------------------------------------
    // Canister Endpoints

    /* public shared (msg) func whoami() : async Principal {
        return msg.caller;
    };

    public shared (msg) func amiController() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = { auth = "You are a controller of this canister." };
        return #Ok(authRecord);
    }; */

    // Admin function to add an official protocol canister
    public shared (msg) func addOfficialCanister(canisterEntryToAdd : Types.CanisterInput) : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (canisterEntryToAdd.canisterType) {
            case (#Challenger) {
                let canisterEntry : Types.OfficialProtocolCanister = {
                    address : Text = canisterEntryToAdd.address;
                    canisterType: Types.ProtocolCanisterType = canisterEntryToAdd.canisterType;
                    creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                    createdBy : Principal = msg.caller;
                    ownedBy : Principal = Principal.fromActor(this);
                };
                let putResponse = putChallengerCanister(canisterEntryToAdd.address, canisterEntry);
                if (not putResponse) {
                    return #Err(#Other("An error adding the canister occurred"));
                };
            };
            case (#Judge) {
                let canisterEntry : Types.OfficialProtocolCanister = {
                    address : Text = canisterEntryToAdd.address;
                    canisterType: Types.ProtocolCanisterType = canisterEntryToAdd.canisterType;
                    creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                    createdBy : Principal = msg.caller;
                    ownedBy : Principal = Principal.fromActor(this);
                };
                let putResponse = putJudgeCanister(canisterEntryToAdd.address, canisterEntry);
                if (not putResponse) {
                    return #Err(#Other("An error adding the canister occurred"));
                };
            };
            case (#MainerCreator) {
                let canisterEntry : Types.OfficialProtocolCanister = {
                    address : Text = canisterEntryToAdd.address;
                    canisterType: Types.ProtocolCanisterType = canisterEntryToAdd.canisterType;
                    creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                    createdBy : Principal = msg.caller;
                    ownedBy : Principal = Principal.fromActor(this);
                };
                let putResponse = putMainerCreatorCanister(canisterEntryToAdd.address, canisterEntry);
                if (not putResponse) {
                    return #Err(#Other("An error adding the canister occurred"));
                };
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };
        let authRecord = { auth = "You added the canister." };
        return #Ok(authRecord);
    };

    // Function for Challenger canister to retrieve current challenges
    public shared query (msg) func getCurrentChallenges() : async Types.ChallengesResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // Only official Challenger canisters may call this
        switch (getChallengerCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?challengerEntry) {
                let challenges : [Types.Challenge] = getOpenChallenges();
                return #Ok(challenges);                
            };
        };
    };

    // Function for Challenger canister to add new challenge
    public shared (msg) func addNewChallenge(newChallenge : Types.NewChallengeInput) : async Types.ChallengeAdditionResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // TODO: require cycles for adding new challenge

        // Only official Challenger canisters may call this
        switch (getChallengerCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?challengerEntry) {
                // Determine which Judge will be responsible for this challenge
                let judgeCanisterEntry : ?Types.OfficialProtocolCanister = getRandomJudgeCanister();
                switch (judgeCanisterEntry) {
                    case (null) {
                        return #Err(#FailedOperation);
                    };
                    case (?judgeCanister) {
                        let challengeId : Text = await Utils.newRandomUniqueId();

                        let challengeAdded : Types.Challenge = {
                            challengeId : Text = challengeId;
                            creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                            createdBy : Types.CanisterAddress = challengerEntry.address;
                            challengePrompt : Text = newChallenge.challengePrompt;
                            status : Types.ChallengeStatus = #Open;
                            closedTimestamp : ?Nat64 = null;
                            responsibleJudgeAddress : Types.CanisterAddress = judgeCanister.address;
                        };

                        let putResult = putOpenChallenge(challengeId, challengeAdded);
                        return #Ok(challengeAdded);                        
                    };
                };               
            };
        };
    };

    // Function for mAIner Agent Creator canister to add new mAIner agent for user
    public shared (msg) func addNewMainerAgentCanister(canisterEntryToAdd : Types.MainerAgentCanisterInput) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (canisterEntryToAdd.canisterType) {
            case (#MainerAgent) {
                // continue
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };
        // Only official mAIner Agent Creator canisters may call this
        switch (getMainerCreatorCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?mainerCreatorEntry) {
                let canisterEntry : Types.OfficialProtocolCanister = {
                    address : Text = canisterEntryToAdd.address;
                    canisterType: Types.ProtocolCanisterType = canisterEntryToAdd.canisterType;
                    creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                    createdBy : Principal = msg.caller;
                    ownedBy : Principal = canisterEntryToAdd.ownedBy;
                };
                let putResponse = putMainerAgentCanister(canisterEntryToAdd.address, canisterEntry);
                if (not putResponse) {
                    return #Err(#Other("An error adding the canister occurred"));
                };
                return #Ok(canisterEntry);             
            };
        };
    };

    // Function to retrieve info on a mAIner agent canister
    public shared query (msg) func getMainerAgentCanisterInfo(canisterEntryToRetrieve : Types.CanisterRetrieveInput) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // Only official Challenger canisters may call this
        switch (getMainerAgentCanister(canisterEntryToRetrieve.address)) {
            case (null) { return #Err(#Unauthorized); };
            case (?mainerAgentEntry) {
                if (Principal.isController(msg.caller)) {
                    return #Ok(mainerAgentEntry);
                } else if (msg.caller == mainerAgentEntry.ownedBy or msg.caller == mainerAgentEntry.createdBy) {
                    return #Ok(mainerAgentEntry);
                } else {
                    return #Err(#Unauthorized);
                };                               
            };
        };
    };

    // Function for mAIner agent canister to retrieve a random open challenge
    public shared (msg) func getRandomOpenChallenge() : async Types.ChallengeResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // Only official mAIner agent canisters may call this
        switch (getMainerAgentCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?mainerAgentEntry) {
                let challengeResult : ?Types.Challenge = await getRandomChallenge(#Open);
                switch (challengeResult) {
                    case (?challenge) {
                        return #Ok(challenge);                
                    };
                    case (_) { return #Err(#FailedOperation); };
                };             
            };
        };
    };

    // Function for mAIner agent canister to submit a response to an open challenge
    stable let CYCLES_MILLION = 1_000_000;
    stable let CYCLES_BILLION = 1_000_000_000;
    stable let CYCLES_TRILLION = 1_000_000_000_000;
    stable let SUBMISSION_CYCLES_REQUIRED : Nat = 100 * CYCLES_BILLION; // TODO: determine how many cycles are needed to process one submission (incl. judge)
    stable let FAILED_SUBMISSION_CYCLES_CUT : Nat = SUBMISSION_CYCLES_REQUIRED / 5;
    stable let JUDGE_CYCLES_PROVISION_PER_SUBMISSION : Nat = 80 * CYCLES_BILLION; // TODO: determine how many cycles should be forwarded to judge per submission

    public shared (msg) func submitChallengeResponse(challengeResponseSubmitted : Types.ChallengeResponseSubmissionInput) : async Types.ChallengeResponseSubmissionResult {
        if (Principal.isAnonymous(msg.caller)) {
            let cyclesKeptForFailedSubmission = Cycles.accept<system>(FAILED_SUBMISSION_CYCLES_CUT);
            return #Err(#Unauthorized);
        };
        // Verify that submission is charged with cycles
        if (Cycles.available() < SUBMISSION_CYCLES_REQUIRED) {
            let cyclesKeptForFailedSubmission = Cycles.accept<system>(FAILED_SUBMISSION_CYCLES_CUT);
            return #Err(#Unauthorized);                    
        };
        // Only official mAIner agent canisters may call this
        switch (getMainerAgentCanister(Principal.toText(msg.caller))) {
            case (null) {
                let cyclesKeptForFailedSubmission = Cycles.accept<system>(FAILED_SUBMISSION_CYCLES_CUT);
                return #Err(#Unauthorized);
            };
            case (?mainerAgentEntry) {
                // Check that submission record looks correct
                if (challengeResponseSubmitted.submittedBy != msg.caller) {
                    let cyclesKeptForFailedSubmission = Cycles.accept<system>(FAILED_SUBMISSION_CYCLES_CUT);
                    return #Err(#Unauthorized);
                };

                // Verify that challenge is open
                if (not verifyChallenge(#Open, challengeResponseSubmitted.challengeId)) {
                    let cyclesKeptForFailedSubmission = Cycles.accept<system>(FAILED_SUBMISSION_CYCLES_CUT);
                    return #Err(#InvalidId);
                };

                // Get Judge responsible for challenge
                let judgeCanisterEntry : ?Types.OfficialProtocolCanister = getJudgeCanisterForChallenge(#Open, challengeResponseSubmitted.challengeId);
                switch (judgeCanisterEntry) {
                    case (null) {
                        let cyclesKeptForFailedSubmission = Cycles.accept<system>(FAILED_SUBMISSION_CYCLES_CUT);
                        return #Err(#FailedOperation);
                    };
                    case (?judgeCanister) {
                        // Accept required cycles for submission
                        let cyclesAcceptedForSubmission = Cycles.accept<system>(SUBMISSION_CYCLES_REQUIRED);
                        if (cyclesAcceptedForSubmission != SUBMISSION_CYCLES_REQUIRED) {
                            // Sanity check: At this point, this should never fail
                            return #Err(#Unauthorized);                    
                        };

                        // TODO: store submission
                        let submissionId : Text = await Utils.newRandomUniqueId();
                        let submissionToForward : Types.ChallengeResponseSubmission = {
                            submissionId : Text = submissionId;
                            challengeId : Text = challengeResponseSubmitted.challengeId;
                            submittedBy : Principal = msg.caller;
                            response : Text = challengeResponseSubmitted.response;
                            submittedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                            status: Types.ChallengeResponseSubmissionStatus = #Received;
                        };

                        // Forward submission to responsible Judge
                        
                        let judgeAddress = judgeCanister.address;

                        let judgeCanisterActor = actor(judgeAddress): Types.Judge_Actor;
                        let result = await judgeCanisterActor.addSubmissionToJudge(submissionToForward);

                        switch (result) {
                            case (true) {
                                let submissionEntry : Types.ChallengeResponseSubmission = {
                                    submissionId : Text = submissionToForward.submissionId;
                                    challengeId : Text = submissionToForward.challengeId;
                                    submittedBy : Principal = submissionToForward.submittedBy;
                                    response : Text = submissionToForward.response;
                                    submittedTimestamp : Nat64 = submissionToForward.submittedTimestamp;
                                    status: Types.ChallengeResponseSubmissionStatus = #Submitted;
                                };
                                // TODO: store submission (update)
                                return #Ok(submissionEntry);
                            };
                            case (_) { return #Err(#FailedOperation); };
                        };                        
                    };
                }; 
            };
        };
    };

// Upgrade Hooks
    system func preupgrade() {
        challengerCanistersStorageStable := Iter.toArray(challengerCanistersStorage.entries());
        judgeCanistersStorageStable := Iter.toArray(judgeCanistersStorage.entries());
        mainerCreatorCanistersStorageStable := Iter.toArray(mainerCreatorCanistersStorage.entries());
        mainerAgentCanistersStorageStable := Iter.toArray(mainerAgentCanistersStorage.entries());
        openChallengesStorageStable := Iter.toArray(openChallengesStorage.entries());
    };

    system func postupgrade() {
        challengerCanistersStorage := HashMap.fromIter(Iter.fromArray(challengerCanistersStorageStable), challengerCanistersStorageStable.size(), Text.equal, Text.hash);
        challengerCanistersStorageStable := [];
        judgeCanistersStorage := HashMap.fromIter(Iter.fromArray(judgeCanistersStorageStable), judgeCanistersStorageStable.size(), Text.equal, Text.hash);
        judgeCanistersStorageStable := [];
        mainerCreatorCanistersStorage := HashMap.fromIter(Iter.fromArray(mainerCreatorCanistersStorageStable), mainerCreatorCanistersStorageStable.size(), Text.equal, Text.hash);
        mainerCreatorCanistersStorageStable := [];
        mainerAgentCanistersStorage := HashMap.fromIter(Iter.fromArray(mainerAgentCanistersStorageStable), mainerAgentCanistersStorageStable.size(), Text.equal, Text.hash);
        mainerAgentCanistersStorageStable := [];
        openChallengesStorage := HashMap.fromIter(Iter.fromArray(openChallengesStorageStable), openChallengesStorageStable.size(), Text.equal, Text.hash);
        openChallengesStorageStable := [];
    };
};
