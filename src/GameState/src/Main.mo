// import IcpLedger "canister:icp_ledger_canister"; https://github.com/dfinity/examples/blob/master/motoko/icp_transfer/src/icp_transfer_backend/main.mo
import D "mo:base/Debug";
// import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
// import Blob "mo:base/Blob";
// import Nat8 "mo:base/Nat8";
import Cycles "mo:base/ExperimentalCycles";
import HashMap "mo:base/HashMap";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Order "mo:base/Order";
import Error "mo:base/Error";
import Blob "mo:base/Blob";

import Types "../../common/Types";
import ICManagementCanister "../../common/ICManagementCanister";
import TokenLedger "../../common/icp-ledger-interface";
import Utils "Utils";

actor class GameStateCanister() = this {

    // Function to verify that canister is up & running
    public shared query func health() : async Types.StatusCodeRecordResult {
        return #Ok({ status_code = 200 });
    };

    // Token Ledger
    stable var TOKEN_LEDGER_CANISTER_ID : Text = "be2us-64aaa-aaaaa-qaabq-cai"; // TODO: update

    // TODO: remove this function before launching
    public shared (msg) func setTokenLedgerCanisterId(_token_ledger_canister_id : Text) : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        TOKEN_LEDGER_CANISTER_ID := _token_ledger_canister_id;
        let authRecord = { auth = "You set the token ledger canister id for this canister." };
        return #Ok(authRecord);
    };

    // TODO: remove this function before launching
    public shared (msg) func testTokenMintingAdmin() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let TokenLedger_Actor : TokenLedger.TOKEN_LEDGER = actor (TOKEN_LEDGER_CANISTER_ID);

        let args : TokenLedger.TransferArg = {
            from_subaccount = null;
            to = {
                owner = Principal.fromText("be2us-64aaa-aaaaa-qaabq-cai");
                subaccount = null;
            };
            amount = 100;
            fee = null;
            memo = null;
            created_at_time = null;
        };

        try {
            // Call the ledger's icrc1_transfer function
            let result = await TokenLedger_Actor.icrc1_transfer(args);

            switch (result) {
                case (#Ok(blockIndex)) {
                    let authRecord = { auth = "Your test was successful. Block index: "  # debug_show(blockIndex)};
                    return #Ok(authRecord);
                };
                case (#Err(err)) {
                    return #Err(#Other("Transfer error: " # debug_show(err)));
                };
            };
        } catch (e) {
            return #Err(#Other("Failed to call ledger: " # Error.message(e)));
        };
    };

    // ICP Ledger
    /* type Tokens = {
        e8s : Nat64;
    };

    type TransferArgs = {
        amount : Tokens;
        toPrincipal : Principal;
        toSubaccount : ?IcpLedger.SubAccount;
    };
    private func transfer(args : TransferArgs) : async Result.Result<IcpLedger.BlockIndex, Text> {
        Debug.print(
            "Transferring "
            # debug_show (args.amount)
            # " tokens to principal "
            # debug_show (args.toPrincipal)
            # " subaccount "
            # debug_show (args.toSubaccount)
        );

        let transferArgs : IcpLedger.TransferArgs = {
            // can be used to distinguish between transactions
            memo = 0;
            // the amount we want to transfer
            amount = args.amount;
            // the ICP ledger charges 10_000 e8s for a transfer
            fee = { e8s = 10_000 };
            // we are transferring from the canisters default subaccount, therefore we don't need to specify it
            from_subaccount = null;
            // we take the principal and subaccount from the arguments and convert them into an account identifier
            to = Principal.toLedgerAccount(args.toPrincipal, args.toSubaccount);
            // a timestamp indicating when the transaction was created by the caller; if it is not specified by the caller then this is set to the current ICP time
            created_at_time = null;
        };

        try {
            // initiate the transfer
            let transferResult = await IcpLedger.transfer(transferArgs);

            // check if the transfer was successfull
            switch (transferResult) {
                case (#Err(transferError)) {
                return #err("Couldn't transfer funds:\n" # debug_show (transferError));
                };
                case (#Ok(blockIndex)) { return #ok blockIndex };
            };
        } catch (error : Error) {
            // catch any errors that might occur during the transfer
            return #err("Reject message: " # Error.message(error));
        };
    };

    private func verify_payment(paymentBlockIndex : IcpLedger.BlockIndex) : async Result.Result<Text, Text> {
        // https://internetcomputer.org/docs/defi/token-ledgers/usage/icp_ledger_usage#receiving-icp
        let startIndex : Nat64 = paymentBlockIndex;
        let queryLength : Nat64 = 1;
        let queryResult = await IcpLedger.get_blocks({
            start = startIndex;
            length = queryLength;
        });
    }; */

    // Code Verification for all mAIner agents
        // Users should not be able to tamper with the mAIner code

    // mAIner agent wasm module hash that must match
        // TODO: implement way to manage this
        // -> For now, do not make it stable, so it can be updated via a canister upgrade
    let officialMainerAgentCanisterWasmHash : Blob = "\6C\10\45\A6\52\C3\62\D2\CE\8D\77\2A\A2\5E\59\89\5E\0C\B1\FB\30\27\84\8E\D3\8F\A3\AA\2B\B0\08\9A";
    
    public shared (msg) func testMainerCodeIntegrityAdmin() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let IC_Management_Actor : ICManagementCanister.IC_Management = actor ("aaaaa-aa");

        let allMainerAgents : [Types.OfficialMainerAgentCanister] = getMainerAgents();
        let mainerAgentsIter : Iter.Iter<Types.OfficialMainerAgentCanister> = Iter.fromArray(allMainerAgents);
        
        try {
            // Retrieve each mAIner agent canister's info
            for (agentEntry in mainerAgentsIter) {
                try {
                    let agentCanisterInfo = await IC_Management_Actor.canister_info({
                        canister_id = Principal.fromText(agentEntry.address);
                        num_requested_changes = ?0;
                    });   
                    // Verify agent canister's wasm module hash
                    switch (agentCanisterInfo.module_hash) {
                        case (null) {
                            D.print("GameState: testMainerCodeIntegrityAdmin - agentEntry has null as module hash: " # debug_show(agentEntry));  
                            D.print("GameState: testMainerCodeIntegrityAdmin - agentCanisterInfo with null as module hash: " # debug_show(agentCanisterInfo)); 
                        };
                        case (?agentModuleHash) {
                            if (Blob.equal(agentModuleHash, officialMainerAgentCanisterWasmHash)) {
                                D.print("GameState: testMainerCodeIntegrityAdmin - agentEntry has official module hash: " # debug_show(agentEntry));  
                                D.print("GameState: testMainerCodeIntegrityAdmin - agentCanisterInfo with official module hash: " # debug_show(agentCanisterInfo));
                            } else {
                                D.print("GameState: testMainerCodeIntegrityAdmin - agentEntry didn't pass verification: " # debug_show(agentEntry));  
                                D.print("GameState: testMainerCodeIntegrityAdmin - agentCanisterInfo didn't pass verification: " # debug_show(agentCanisterInfo));
                            };
                        };
                    };
                } catch (e) {
                    D.print("GameState: testMainerCodeIntegrityAdmin - Failed to retrieve info for mAIner: " # debug_show(agentEntry) # Error.message(e));      
                    return #Err(#Other("GameState: testMainerCodeIntegrityAdmin - Failed to retrieve info for mAIner: " # debug_show(agentEntry) # Error.message(e)));
                };
            };
            let authRecord = { auth = "Your test was successful."};
            return #Ok(authRecord);
        } catch (e) {
            D.print("GameState: testMainerCodeIntegrityAdmin - Failed to loop over mAIners: " # Error.message(e));      
            return #Err(#Other("GameState: testMainerCodeIntegrityAdmin - Failed to loop over mAIners: " # Error.message(e)));
        };
    };

    // Game Settings
    // TODO - Design: determine settings to use
    stable var THRESHOLD_ARCHIVE_CLOSED_CHALLENGES : Nat = 30;
    stable var THRESHOLD_MAX_OPEN_CHALLENGES : Nat = 2; // When above, Challengers will not be given a topic able to generate new challenges
    stable var THRESHOLD_MAX_OPEN_SUBMISSIONS : Nat = 5; // When above, mAIner agents will not be given a challenge to generate new responses
    stable var THRESHOLD_SCORED_RESPONSES_PER_CHALLENGE : Nat = 3; // When reached, ranking and winner declaration; challenge is closed
    
    public shared (msg) func setGameStateThresholdsAdmin(thresholds : Types.GameStateTresholds) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        THRESHOLD_ARCHIVE_CLOSED_CHALLENGES := thresholds.thresholdArchiveClosedChallenges;
        THRESHOLD_MAX_OPEN_CHALLENGES := thresholds.thresholdMaxOpenChallenges;
        THRESHOLD_MAX_OPEN_SUBMISSIONS := thresholds.thresholdMaxOpenSubmissions;
        THRESHOLD_SCORED_RESPONSES_PER_CHALLENGE := thresholds.thresholdScoredResponsesPerChallenge;
        return #Ok({ status_code = 200 });
    };

    public shared query (msg) func getGameStateThresholdsAdmin() : async Types.GameStateTresholdsResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let thresholds : Types.GameStateTresholds = {
            thresholdArchiveClosedChallenges = THRESHOLD_ARCHIVE_CLOSED_CHALLENGES;
            thresholdMaxOpenChallenges = THRESHOLD_MAX_OPEN_CHALLENGES;
            thresholdMaxOpenSubmissions = THRESHOLD_MAX_OPEN_SUBMISSIONS;
            thresholdScoredResponsesPerChallenge = THRESHOLD_SCORED_RESPONSES_PER_CHALLENGE;
        };
        return #Ok(thresholds);
    };  


    // Statistics
    stable var TOTAL_PROTOCOL_CYCLES_BURNT : Nat = 0;

    private func increaseTotalProtocolCyclesBurnt(cyclesBurntToAdd : Nat) : Bool {
        TOTAL_PROTOCOL_CYCLES_BURNT := TOTAL_PROTOCOL_CYCLES_BURNT + cyclesBurntToAdd;
        return true;
    };

    // TODO: Cycles burnt per operation    
    stable let _CYCLES_MILLION = 1_000_000;
    stable let CYCLES_BILLION = 1_000_000_000;
    stable let CYCLES_TRILLION = 1_000_000_000_000;


    // TODO: Keep in sync with SUBMISSION_CYCLES_REQUIRED in mAInerCreator
    let MAINER_AGENT_CTRLB_CREATION_CYCLES_REQUIRED = 5 * CYCLES_TRILLION; // TODO: Update to actual values
    let MAINER_AGENT_LLM_CREATION_CYCLES_REQUIRED = 5 * CYCLES_TRILLION; // TODO: Update to actual values

    // TODO: Keep in sync with SUBMISSION_CYCLES_REQUIRED in mAIner
    let SUBMISSION_CYCLES_REQUIRED : Nat = 100 * CYCLES_BILLION; // TODO: determine how many cycles are needed to process one submission (incl. judge)
    
    let FAILED_SUBMISSION_CYCLES_CUT : Nat = SUBMISSION_CYCLES_REQUIRED / 5;
    let _JUDGE_CYCLES_PROVISION_PER_SUBMISSION : Nat = 80 * CYCLES_BILLION; // TODO: determine how many cycles should be forwarded to judge per submission

    // TODO: Update to actual values
    let CYCLES_BURNT_CHALLENGE_CREATION : Nat = 110 * CYCLES_BILLION;
    let CYCLES_BURNT_RESPONSE_GENERATION : Nat = 200 * CYCLES_BILLION;
    let CYCLES_BURNT_JUDGE_SCORING : Nat = 300 * CYCLES_BILLION;

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
        D.print("GameState: getMainerCreatorCanister - canisterAddress: " # debug_show(canisterAddress));
        // TODO - Testing: remove (as just for debugging) 
        let mainerCreatorCanistersEntries = Iter.toArray(mainerCreatorCanistersStorage.entries());
        D.print("GameState: getMainerCreatorCanister - mainerCreatorCanistersStorage: " # debug_show(mainerCreatorCanistersEntries));
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
        // TODO - Implementation: if this should be used for load balancing, then a different implementation is needed (likely by keeping an index of last used canister)
        return mainerCreatorCanistersStorage.vals().next();
    };

    // Official Shared mAIning Service canisters
    stable var sharedServiceCanistersStorageStable : [(Text, Types.OfficialProtocolCanister)] = [];
    var sharedServiceCanistersStorage : HashMap.HashMap<Text, Types.OfficialProtocolCanister> = HashMap.HashMap(0, Text.equal, Text.hash);
    
    private func putSharedServiceCanister(canisterAddress : Text, canisterEntry : Types.OfficialProtocolCanister) : Bool {
        sharedServiceCanistersStorage.put(canisterAddress, canisterEntry);
        return true;
    };

    private func getSharedServiceCanister(canisterAddress : Text) : ?Types.OfficialProtocolCanister {
        D.print("GameState: getSharedServiceCanister - canisterAddress: " # debug_show(canisterAddress));
        // TODO - Testing: remove (as just for debugging) 
        let canistersEntries = Iter.toArray(sharedServiceCanistersStorage.entries());
        D.print("GameState: getSharedServiceCanister - canistersEntries: " # debug_show(canistersEntries));
        switch (sharedServiceCanistersStorage.get(canisterAddress)) {
            case (null) { return null; };
            case (?canisterEntry) { return ?canisterEntry; };
        };
    };

    private func removeSharedServiceCanister(canisterAddress : Text) : Bool {
        switch (sharedServiceCanistersStorage.get(canisterAddress)) {
            case (null) { return false; };
            case (?canisterEntry) {
                let removeResult = sharedServiceCanistersStorage.remove(canisterAddress);
                return true;
            };
        };
    };

    private func getNextSharedServiceCanisterEntry() : ?Types.OfficialProtocolCanister {
        // TODO - Implementation: if this should be used for load balancing, then a different implementation is needed (likely by keeping an index of last used canister)
        return sharedServiceCanistersStorage.vals().next();
    };

    // mAIner Registry: Official mAIner agent canisters (owned by users)
    stable var mainerAgentCanistersStorageStable : [(Text, Types.OfficialMainerAgentCanister)] = [];
    var mainerAgentCanistersStorage : HashMap.HashMap<Text, Types.OfficialMainerAgentCanister> = HashMap.HashMap(0, Text.equal, Text.hash);
    stable var userToMainerAgentsStorageStable : [(Principal, List.List<Types.OfficialMainerAgentCanister>)] = [];
    var userToMainerAgentsStorage : HashMap.HashMap<Principal, List.List<Types.OfficialMainerAgentCanister>> = HashMap.HashMap(0, Principal.equal, Principal.hash);

    private func putMainerAgentCanister(canisterAddress : Text, canisterEntry : Types.OfficialMainerAgentCanister) : Types.MainerAgentCanisterResult {
        mainerAgentCanistersStorage.put(canisterAddress, canisterEntry);
        return #Ok(canisterEntry);
    };

    private func getMainerAgentCanister(canisterAddress : Text) : ?Types.OfficialMainerAgentCanister {
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
                // TODO: remove from userToMainerAgentsStorage
                return true;
            };
        };
    };

    private func putUserMainerAgent(canisterEntry : Types.OfficialMainerAgentCanister) : Bool {
        switch (getUserMainerAgents(canisterEntry.ownedBy)) {
            case (null) {
                // first entry
                let userCanistersList : List.List<Types.OfficialMainerAgentCanister> = List.make<Types.OfficialMainerAgentCanister>(canisterEntry);
                userToMainerAgentsStorage.put(canisterEntry.ownedBy, userCanistersList);
                return true;
            };
            case (?userCanistersList) { 
                //existing list, add entry to it
                // Deduplicate (based on creationTimestamp)
                let filteredUserCanistersList : List.List<Types.OfficialMainerAgentCanister> = List.filter(userCanistersList, func(listEntry: Types.OfficialMainerAgentCanister) : Bool { listEntry.creationTimestamp != canisterEntry.creationTimestamp });
                let updatedUserCanistersList : List.List<Types.OfficialMainerAgentCanister> = List.push<Types.OfficialMainerAgentCanister>(canisterEntry, filteredUserCanistersList);
                userToMainerAgentsStorage.put(canisterEntry.ownedBy, updatedUserCanistersList);
                return true;
            }; 
        };
    };

    private func getUserMainerAgents(userId : Principal) : ?List.List<Types.OfficialMainerAgentCanister> {
        switch (userToMainerAgentsStorage.get(userId)) {
            case (null) { return null; };
            case (?userCanistersList) { return ?userCanistersList; };
        };
    };

    // Caution: function that returns all mAIner agents (TODO: decide if needed)
    private func getMainerAgents() : [Types.OfficialMainerAgentCanister] {
        var mainerAgents : List.List<Types.OfficialMainerAgentCanister> = List.nil<Types.OfficialMainerAgentCanister>();
        for (userMainerAgentsList in userToMainerAgentsStorage.vals()) {
            mainerAgents := List.append<Types.OfficialMainerAgentCanister>(userMainerAgentsList, mainerAgents);    
        };
        return List.toArray(mainerAgents);
    };

    private func removeUserMainerAgent(canisterEntry : Types.OfficialMainerAgentCanister) : Bool {
        switch (getUserMainerAgents(canisterEntry.ownedBy)) {
            case (null) { return false; };
            case (?userCanistersList) { 
                //existing list, remove entry from it
                let updatedUserCanistersList : List.List<Types.OfficialMainerAgentCanister> = List.filter(userCanistersList, func(listEntry: Types.OfficialProtocolCanister) : Bool { listEntry.address != canisterEntry.address });
                userToMainerAgentsStorage.put(canisterEntry.ownedBy, updatedUserCanistersList);
                return true;
            }; 
        };
    };

    // Open topics for Challenges to be generated
    stable var openChallengeTopicsStorageStable : [(Text, Types.ChallengeTopic)] = [];
    var openChallengeTopicsStorage : HashMap.HashMap<Text, Types.ChallengeTopic> = HashMap.HashMap(0, Text.equal, Text.hash);

    private func putOpenChallengeTopic(challengeTopicId : Text, challengeTopicEntry : Types.ChallengeTopic) : Bool {
        openChallengeTopicsStorage.put(challengeTopicId, challengeTopicEntry);
        return true;
    };

    private func getOpenChallengeTopic(challengeTopicId : Text) : ?Types.ChallengeTopic {
        switch (openChallengeTopicsStorage.get(challengeTopicId)) {
            case (null) { return null; };
            case (?challengeTopicEntry) { return ?challengeTopicEntry; };
        };
    };

    private func getOpenChallengeTopics() : [Types.ChallengeTopic] {
        return Iter.toArray(openChallengeTopicsStorage.vals());
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

    private func closeChallenge(challengeId : Text) : Bool {
        switch (openChallengesStorage.get(challengeId)) {
            case (null) { return false; };
            case (?challengeEntry) {
                switch (putClosedChallenge(challengeEntry)) {
                    case (false) { return false; };
                    case (true) {
                        let removeResult = removeOpenChallenge(challengeId);
                        return removeResult;
                    };
                };
            };
        };
    };

    // Recently closed challenges
    stable var closedChallenges : List.List<Types.Challenge> = List.nil<Types.Challenge>();

    private func putClosedChallenge(challengeEntry : Types.Challenge) : Bool {
        closedChallenges := List.push<Types.Challenge>(challengeEntry, closedChallenges);
        let maintenanceResult = archiveClosedChallenges();
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

    private func setClosedChallenges(newClosedChallenges : List.List<Types.Challenge>) : Bool {
        closedChallenges := newClosedChallenges;
        return true;
    };

    private func archiveClosedChallenges() : Bool {
        let numberOfClosedChallenges = List.size<Types.Challenge>(closedChallenges);
        if (numberOfClosedChallenges >= THRESHOLD_ARCHIVE_CLOSED_CHALLENGES) {
            let numberOfChallengesToArchive : Nat = THRESHOLD_ARCHIVE_CLOSED_CHALLENGES / 2;
            let (newClosedChallenges, challengesToArchive) = List.split<Types.Challenge>(numberOfChallengesToArchive, closedChallenges);
            // Archive challenges
            switch (addArchivedChallenges(challengesToArchive)) {
                case (false) {
                    return false;
                };
                case (true) {
                    // then update closed challenges with remaining ones
                    switch (setClosedChallenges(newClosedChallenges)) {
                        case (true) { return true; };
                        case (false) {
                            // set again
                            closedChallenges := newClosedChallenges;
                            return true;
                        };
                    };
                };
            };
        };
        return true;
    };

    // Challenges archive
    stable var archivedChallenges : List.List<Types.Challenge> = List.nil<Types.Challenge>();

    private func putArchivedChallenge(challengeEntry : Types.Challenge) : Bool {
        archivedChallenges := List.push<Types.Challenge>(challengeEntry, archivedChallenges);
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

    private func addArchivedChallenges(challengesToAdd : List.List<Types.Challenge>) : Bool {
        archivedChallenges := List.append<Types.Challenge>(challengesToAdd, archivedChallenges);
        return true;
    };

    // Challenges helper functions
    private func getRandomChallengeTopic(challengeTopicStatus : Types.ChallengeTopicStatus) : async ?Types.ChallengeTopic {
        D.print("GameState: getRandomChallengeTopic - challengeTopicStatus: " # debug_show(challengeTopicStatus));
        switch (challengeTopicStatus) {
            case (#Open) {
                let topicIds : [Text] = Iter.toArray(openChallengeTopicsStorage.keys());
                
                let numberOfTopics : Nat = topicIds.size();

                let randomInt : ?Int = await Utils.nextRandomInt(0, numberOfTopics-1);
                D.print("GameState: getRandomChallengeTopic - topicIds: " # debug_show(topicIds));
                D.print("GameState: getRandomChallengeTopic - numberOfTopics: " # debug_show(numberOfTopics));
                D.print("GameState: getRandomChallengeTopic - randomInt: " # debug_show(randomInt));
                switch (randomInt) {
                    case (?intToUse) {
                        D.print("GameState: getRandomChallengeTopic - intToUse: " # debug_show(intToUse));
                        return getOpenChallengeTopic(topicIds[Int.abs(intToUse)]);
                    };
                    case (_) { return null; };
                };
            };
            case (_) { return null; };
        };
    };

    private func getRandomChallenge(challengeStatus : Types.ChallengeStatus) : async ?Types.Challenge {
        D.print("GameState: getRandomChallenge - challengeStatus: " # debug_show(challengeStatus));
        switch (challengeStatus) {
            case (#Open) {
                let challengeIds : [Text] = Iter.toArray(openChallengesStorage.keys());
                
                let numberOfChallenges : Nat = challengeIds.size();

                let randomInt : ?Int = await Utils.nextRandomInt(0, numberOfChallenges-1);
                D.print("GameState: getRandomChallenge - challengeIds: " # debug_show(challengeIds));
                D.print("GameState: getRandomChallenge - numberOfChallenges: " # debug_show(numberOfChallenges));
                D.print("GameState: getRandomChallenge - randomInt: " # debug_show(randomInt));
                switch (randomInt) {
                    case (?intToUse) {
                        D.print("GameState: getRandomChallenge - intToUse: " # debug_show(intToUse));
                        return getOpenChallenge(challengeIds[Int.abs(intToUse)]);
                    };
                    case (_) { return null; };
                };
            };
            case (_) { return null; };
        };
    };

    private func verifyChallenge(challengeStatus : Types.ChallengeStatus, challengeId: Text) : Bool {
        switch (challengeStatus) {
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

    // Submissions to challenges
    stable var submissionsStorageStable : [(Text, Types.ChallengeResponseSubmission)] = [];
    var submissionsStorage : HashMap.HashMap<Text, Types.ChallengeResponseSubmission> = HashMap.HashMap(0, Text.equal, Text.hash);

    private func putSubmission(submissionId : Text, submissionEntry : Types.ChallengeResponseSubmission) : Bool {
        if (submissionEntry.submissionId != submissionId) {
            D.print("GameState: putSubmission - ERROR: submissionId does not match submissionEntry.submissionId"); 
            return false;
        };
        submissionsStorage.put(submissionId, submissionEntry);
        return true;
    };

    private func getSubmission(submissionId : Text) : ?Types.ChallengeResponseSubmission {
        switch (submissionsStorage.get(submissionId)) {
            case (null) { return null; };
            case (?submissionEntry) { return ?submissionEntry; };
        };
    };

    private func getSubmissions() : [Types.ChallengeResponseSubmission] {
        return Iter.toArray(submissionsStorage.vals());
    };

    private func getOpenSubmissions() : [Types.ChallengeResponseSubmission] {
        return Iter.toArray(Iter.filter(submissionsStorage.vals(), func(submission: Types.ChallengeResponseSubmission) : Bool {
            switch (submission.submissionStatus) {
            case (#Submitted) { true };
            case (_) { false };
            }
        }));
    };

    private func removeSubmission(submissionId : Text) : Bool {
        switch (submissionsStorage.get(submissionId)) {
            case (null) { return false; };
            case (?submissionEntry) {
                let removeResult = submissionsStorage.remove(submissionId);
                return true;
            };
        };
    };

    // Admin functions to get all open submissions
    public shared query (msg) func getOpenSubmissionsAdmin() : async Types.ChallengeResponseSubmissionsResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let openSubmissions : [Types.ChallengeResponseSubmission] = getOpenSubmissions();
        return #Ok(openSubmissions);
    };

    public shared query (msg) func getNumOpenSubmissionsAdmin() : async Types.NatResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let openSubmissions : [Types.ChallengeResponseSubmission] = getOpenSubmissions();
        return #Ok(openSubmissions.size());
    };

    // Winner declaration per challenge id
    stable var winnerDeclarationForChallengeStable : [(Text, Types.ChallengeWinnerDeclaration)] = [];
    var winnerDeclarationForChallenge : HashMap.HashMap<Text, Types.ChallengeWinnerDeclaration> = HashMap.HashMap(0, Text.equal, Text.hash);
  
    private func putWinnerDeclarationForChallenge(challengeId : Text, challengeWinnerDeclaration : Types.ChallengeWinnerDeclaration) : Bool {
        winnerDeclarationForChallenge.put(challengeId, challengeWinnerDeclaration);
        return true;
    };

    private func getWinnerDeclarationForChallenge(challengeId : Text) : ?Types.ChallengeWinnerDeclaration {
        switch (winnerDeclarationForChallenge.get(challengeId)) {
            case (null) { return null; };
            case (?challengeEntry) { return ?challengeEntry; };
        };
    };

    private func getWinnersForRecentChallenges() : [Types.ChallengeWinnerDeclaration] {
        let recentChallenges : [Types.Challenge] = getClosedChallenges();
        let recentChallengesIter : Iter.Iter<Types.Challenge> = Iter.fromArray(recentChallenges);
        var returnList : List.List<Types.ChallengeWinnerDeclaration> = List.nil<Types.ChallengeWinnerDeclaration>();
        for (challenge in recentChallengesIter) {
            switch (getWinnerDeclarationForChallenge(challenge.challengeId)) {
                case (null) { };
                case (?challengeEntry) { returnList := List.push<Types.ChallengeWinnerDeclaration>(challengeEntry, returnList); };
            };
        };
        return List.toArray<Types.ChallengeWinnerDeclaration>(returnList);
    };

    // Scored responses mapped to challenge id
    stable var scoredResponsesPerChallengeStable : [(Text, List.List<Types.ScoredResponse>)] = [];
    var scoredResponsesPerChallenge : HashMap.HashMap<Text, List.List<Types.ScoredResponse>> = HashMap.HashMap(0, Text.equal, Text.hash);
  
    private func putScoredResponseForChallenge(scoredResponseEntry : Types.ScoredResponse) : Nat {
        let currentScoredResponses : List.List<Types.ScoredResponse> = getScoredResponsesForChallenge(scoredResponseEntry.challengeId);
        let updatedScoredResponses = List.push<Types.ScoredResponse>(scoredResponseEntry, currentScoredResponses);
        scoredResponsesPerChallenge.put(scoredResponseEntry.challengeId, updatedScoredResponses);
        // return number of scored responses for this challenge
        return List.size<Types.ScoredResponse>(updatedScoredResponses);
    };

    private func getScoredResponse(challengeId : Text, submissionId : Text) : ?Types.ScoredResponse {
        let currentScoredResponses : List.List<Types.ScoredResponse> = getScoredResponsesForChallenge(challengeId);
        return List.find(currentScoredResponses, func(scoredResponseEntry: Types.ScoredResponse) : Bool { scoredResponseEntry.submissionId == submissionId });
    };

    private func getScoredResponsesForChallenge(challengeId : Text) : List.List<Types.ScoredResponse> {
        let scoredResponsesForChallenge : ?List.List<Types.ScoredResponse> = scoredResponsesPerChallenge.get(challengeId);
        switch (scoredResponsesForChallenge) {
            case (null) { return List.nil<Types.ScoredResponse>(); };
            case (?scoredResponsesForChallenge) { return scoredResponsesForChallenge; };
        };
    };

    private func deleteScoredResponsesForChallenge(challengeId : Text, submissionId : Text) : Text {
        let currentScoredResponses : List.List<Types.ScoredResponse> = getScoredResponsesForChallenge(challengeId);
        let updatedScoredResponses = List.filter(currentScoredResponses, func(scoredResponseEntry: Types.ScoredResponse) : Bool { scoredResponseEntry.submissionId != submissionId });
        scoredResponsesPerChallenge.put(challengeId, updatedScoredResponses);
        return challengeId;
    };

    // Admin functions to get all scored responses
    public shared query (msg) func getScoredChallengesAdmin() : async Types.ScoredChallengesResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let scoredChallengesArray : [(Text, List.List<Types.ScoredResponse>)] = Iter.toArray(scoredResponsesPerChallenge.entries());

        return #Ok(scoredChallengesArray);
    };

    public shared query (msg) func getNumScoredChallengesAdmin() : async Types.NatResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let scoredChallengesArray : [(Text, List.List<Types.ScoredResponse>)] = Iter.toArray(scoredResponsesPerChallenge.entries());

        return #Ok(scoredChallengesArray.size());
    };

    // TODO - Design: determine exact reward
        // TODO - Design: define details of sponsored challenges and then add reward per challenge
    stable var DEFAULT_REWARD_PER_CHALLENGE = {
        rewardType : Types.RewardType = #MainerToken;
        totalAmount : Nat = 100;
        winnerAmount : Nat = 35;
        secondPlaceAmount : Nat = 15;
        thirdPlaceAmount : Nat = 5;
        amountForAllParticipants : Nat = 45;
    };

    private func getRewardAmountForResult(achievedResult : Types.ChallengeParticipationResult, totalNumberParticipants : Nat) : Nat { 
        // TODO - Implementation: is this safe? i.e. what could happen with rounding errors?
        let participationReward = DEFAULT_REWARD_PER_CHALLENGE.amountForAllParticipants / totalNumberParticipants; 
        switch (achievedResult) {
            case (#Winner) { return DEFAULT_REWARD_PER_CHALLENGE.winnerAmount + participationReward; };
            case (#SecondPlace) { return DEFAULT_REWARD_PER_CHALLENGE.secondPlaceAmount + participationReward; };
            case (#ThirdPlace) { return DEFAULT_REWARD_PER_CHALLENGE.thirdPlaceAmount + participationReward; };
            case (#Participated) { return participationReward; };
            case (_) { return 0; };
        };
    };

    private func getRewardForChallengeParticipant(challengeId : Text, achievedResult : Types.ChallengeParticipationResult, totalNumberParticipants : Nat) : Types.ChallengeWinnerReward { 
        var rewardAmount : Nat = getRewardAmountForResult(achievedResult, totalNumberParticipants);
        
        let participantReward : Types.ChallengeWinnerReward = {
            rewardType : Types.RewardType = DEFAULT_REWARD_PER_CHALLENGE.rewardType;
            amount : Nat = rewardAmount;
            rewardDetails : Text = "";
            distributed : Bool = false;
            distributedTimestamp : ?Nat64 = null;
        };

        return participantReward;
    };

    private func getParticipantEntryFromScoredResponse(scoredResponse : Types.ScoredResponse, achievedResult : Types.ChallengeParticipationResult, totalNumberParticipants : Nat) : ?Types.ChallengeParticipantEntry {
        switch (getMainerAgentCanister(Principal.toText(scoredResponse.submittedBy))) {
            case (null) { return null; };
            case (?mainerAgentEntry) {
                let participantReward : Types.ChallengeWinnerReward = getRewardForChallengeParticipant(scoredResponse.challengeId, achievedResult, totalNumberParticipants);

                let participantEntry : Types.ChallengeParticipantEntry = {
                    submissionId : Text = scoredResponse.submissionId;
                    submittedBy : Principal = scoredResponse.submittedBy;
                    ownedBy: Principal = mainerAgentEntry.ownedBy;
                    result : Types.ChallengeParticipationResult = achievedResult;
                    reward : Types.ChallengeWinnerReward = participantReward;
                };

                return ?participantEntry;                                            
            };
        };
    };

    private func compareScoredResponses(resA : Types.ScoredResponse, resB : Types.ScoredResponse) : Order.Order {
        // Note: the sort logic is in increasing order, i.e. if we want the highest scoring entries first we need to reverse the logic
        if (resA.score > resB.score) {
            // response A scored higher and should be listed first
            return #less;
        } else if (resA.score == resB.score) {
            // responses A and B scored equally
            return #equal;
        } else {
            // response B scored higher and response AI should be listed after
            return #greater;
        };
    };

    private func rankScoredResponsesForChallenge(challengeId : Text) : ?Types.ChallengeWinnerDeclaration {
        // Get all scored responses for this challenge
        let currentScoredResponses : List.List<Types.ScoredResponse> = getScoredResponsesForChallenge(challengeId);
        let numberOfParticipants : Nat = List.size<Types.ScoredResponse>(currentScoredResponses);
        let currentScoredResponsesIter : Iter.Iter<Types.ScoredResponse> = Iter.fromList(currentScoredResponses);
        // Sort
        let sortedScoredResponsesIter : Iter.Iter<Types.ScoredResponse> = Iter.sort<Types.ScoredResponse>(currentScoredResponsesIter, compareScoredResponses);

        var participantsList : List.List<Types.ChallengeParticipantEntry> = List.nil<Types.ChallengeParticipantEntry>();

        // 1st Place (winner)
        let winnerScoredResponseEntry : ?Types.ScoredResponse = sortedScoredResponsesIter.next();
        switch (winnerScoredResponseEntry) {
            case (null) { return null };
            case (?winnerScoredResponse) {
                let winnerParticipantEntry : ?Types.ChallengeParticipantEntry = getParticipantEntryFromScoredResponse(winnerScoredResponse, #Winner, numberOfParticipants);
                switch (winnerParticipantEntry) {
                    case (null) { return null };
                    case (?winnerParticipant) {
                        participantsList := List.push<Types.ChallengeParticipantEntry>(winnerParticipant, participantsList);
                        // 2nd Place
                        let secondPlaceScoredResponseEntry : ?Types.ScoredResponse = sortedScoredResponsesIter.next();
                        switch (secondPlaceScoredResponseEntry) {
                            case (null) { return null };
                            case (?secondPlaceScoredResponse) {
                                let secondPlaceParticipantEntry : ?Types.ChallengeParticipantEntry = getParticipantEntryFromScoredResponse(secondPlaceScoredResponse, #SecondPlace, numberOfParticipants);
                                switch (secondPlaceParticipantEntry) {
                                    case (null) { return null };
                                    case (?secondPlaceParticipant) {
                                        participantsList := List.push<Types.ChallengeParticipantEntry>(secondPlaceParticipant, participantsList);
                                        // 3rd Place
                                        let thirdPlaceScoredResponseEntry : ?Types.ScoredResponse = sortedScoredResponsesIter.next();
                                        switch (thirdPlaceScoredResponseEntry) {
                                            case (null) { return null };
                                            case (?thirdPlaceScoredResponse) {
                                                let thirdPlaceParticipantEntry : ?Types.ChallengeParticipantEntry = getParticipantEntryFromScoredResponse(thirdPlaceScoredResponse, #ThirdPlace, numberOfParticipants);
                                                switch (thirdPlaceParticipantEntry) {
                                                    case (null) { return null };
                                                    case (?thirdPlaceParticipant) {
                                                        participantsList := List.push<Types.ChallengeParticipantEntry>(thirdPlaceParticipant, participantsList);
                                                        // Remaining participants
                                                        for (nextScoredResponse in sortedScoredResponsesIter) {
                                                            var nextParticipantEntry : ?Types.ChallengeParticipantEntry = getParticipantEntryFromScoredResponse(nextScoredResponse, #Participated, numberOfParticipants);
                                                            switch (nextParticipantEntry) {
                                                                case (null) { };
                                                                case (?nextParticipant) { participantsList := List.push<Types.ChallengeParticipantEntry>(nextParticipant, participantsList); };
                                                            };
                                                        };

                                                        let challengeWinnerDeclaration : Types.ChallengeWinnerDeclaration = {
                                                            challengeId : Text = challengeId;
                                                            finalizedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                                                            winner : Types.ChallengeParticipantEntry = winnerParticipant;
                                                            secondPlace : Types.ChallengeParticipantEntry = secondPlaceParticipant;
                                                            thirdPlace : Types.ChallengeParticipantEntry = thirdPlaceParticipant;
                                                            participants : List.List<Types.ChallengeParticipantEntry> = participantsList;
                                                        };
                                                        // Store the winner declaration
                                                        let putResult = putWinnerDeclarationForChallenge(challengeId, challengeWinnerDeclaration);

                                                        return ?challengeWinnerDeclaration;
                                                    };
                                                };
                                            };
                                        };
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };

    };
    

    // TODO - Implementation: settings
    

    // -------------------------------------------------------------------------------
    // Canister Endpoints

    public shared (msg) func setInitialChallengeTopics() : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        D.print("GameState: setInitialChallengeTopics - entered");
        // Start with some initial topics
        let initialTopics : [Text] = [
            "crypto",     "nature",      "space", "history", "science", 
            "technology", "engineering", "math",  "art",     "music"
        ];
        for (initialTopic in Iter.fromArray(initialTopics)) {
            let challengeTopicId : Text = await Utils.newRandomUniqueId();

            let challengeTopic : Types.ChallengeTopic = {
                challengeTopic : Text = initialTopic;
                challengeTopicId : Text = challengeTopicId;
                challengeTopicCreationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                challengeTopicStatus : Types.ChallengeTopicStatus = #Open;
            };

            D.print("GameState: init - Adding challengeTopic: " # debug_show(challengeTopic));
            let _ = putOpenChallengeTopic(challengeTopicId, challengeTopic);
        };
        return #Ok({ status_code = 200 });
    };
    
    // Function for Admin to add new challengeTopics
    public shared (msg) func addChallengeTopic(challengeTopicInput : Types.ChallengeTopicInput) : async Types.ChallengeTopicResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let challengeTopicId : Text = await Utils.newRandomUniqueId();

        let challengeTopic : Types.ChallengeTopic = {
            challengeTopic : Text = challengeTopicInput.challengeTopic;
            challengeTopicId : Text = challengeTopicId;
            challengeTopicCreationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            challengeTopicStatus : Types.ChallengeTopicStatus = #Open;
        };

        let _ = putOpenChallengeTopic(challengeTopicId, challengeTopic);
        return #Ok(challengeTopic);
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

    // Functions for Admin to retrieve current challenges
    public shared query (msg) func getCurrentChallengesAdmin() : async Types.ChallengesResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let challenges : [Types.Challenge] = getOpenChallenges();
        return #Ok(challenges);
    };

    public shared query (msg) func getNumCurrentChallengesAdmin() : async Types.NatResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let challenges : [Types.Challenge] = getOpenChallenges();
        return #Ok(challenges.size());
    };

    // Function for Challenger agent canister to retrieve a random challenge topic
    public shared (msg) func getRandomOpenChallengeTopic() : async Types.ChallengeTopicResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // Only official Challenger canisters may call this
        switch (getChallengerCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?_challengerEntry) {
                // Do we already have enough open challenges?
                let openChallenges : [Types.Challenge] = getOpenChallenges();
                if (openChallenges.size() >= THRESHOLD_MAX_OPEN_CHALLENGES) {
                    return #Err(#Other("We already have sufficient open challenges."));
                };
                let challengeTopicResult : ?Types.ChallengeTopic = await getRandomChallengeTopic(#Open);
                switch (challengeTopicResult) {
                    case (?challengeTopic) {
                        return #Ok(challengeTopic);                
                    };
                    case (_) { return #Err(#FailedOperation); };
                };             
            };
        };
    };

    // Function for Challenger canister to add new challenge
    public shared (msg) func addChallenge(newChallenge : Types.NewChallengeInput) : async Types.ChallengeAdditionResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // TODO - Implementation: require cycles for adding new challenge

        ignore increaseTotalProtocolCyclesBurnt(CYCLES_BURNT_CHALLENGE_CREATION);

        // Only official Challenger canisters may call this
        switch (getChallengerCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?challengerEntry) {
                // Verify consistency of the caller
                if (challengerEntry.address != Principal.toText(msg.caller)) {
                    return #Err(#Unauthorized);
                };

                let challengeId : Text = await Utils.newRandomUniqueId();

                let challengeAdded : Types.Challenge = {
                    challengeTopic : Text = newChallenge.challengeTopic;
                    challengeTopicId : Text = newChallenge.challengeTopicId;
                    challengeTopicCreationTimestamp : Nat64 = newChallenge.challengeTopicCreationTimestamp;
                    challengeTopicStatus : Types.ChallengeTopicStatus = newChallenge.challengeTopicStatus;
                    challengeId : Text = challengeId;
                    challengeQuestion : Text = newChallenge.challengeQuestion;
                    challengeQuestionSeed : Nat32 = newChallenge.challengeQuestionSeed;
                    challengeCreationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                    challengeCreatedBy : Types.CanisterAddress = challengerEntry.address;
                    challengeStatus : Types.ChallengeStatus = #Open;
                    challengeClosedTimestamp : ?Nat64 = null;
                    submissionCyclesRequired : Nat = SUBMISSION_CYCLES_REQUIRED;
                };

                let putResult = putOpenChallenge(challengeId, challengeAdded);
                return #Ok(challengeAdded);                        
            };             
        };
    };

    // Admin functions to get the official protocol canisters
    public shared (msg) func getOfficialChallengerCanisters() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let challengerCanister : ?Types.OfficialProtocolCanister = getChallengerCanister("br5f7-7uaaa-aaaaa-qaaca-cai");
        switch (challengerCanister) {
            case (null) { return #Err(#InvalidId); };
            case (?canisterEntry) { return #Ok({ auth = canisterEntry.address }); };
        }; 
    };

    public shared (msg) func getOfficialSharedServiceCanisters() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let sharedServiceCanister : ?Types.OfficialProtocolCanister = getNextSharedServiceCanisterEntry();
        switch (sharedServiceCanister) {
            case (null) { return #Err(#InvalidId); };
            case (?canisterEntry) { return #Ok({ auth = canisterEntry.address }); };
        }; 
    };

    public shared (msg) func removeOfficialSharedServiceCanisters(canisterId : Text) : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (removeSharedServiceCanister(canisterId)) {
            case (false) { return #Err(#InvalidId); };
            case (true) { return #Ok({ auth = "Success" }); };
        };
    };

    // Admin function to add an official protocol canister
    public shared (msg) func addOfficialCanister(canisterEntryToAdd : Types.CanisterInput) : async Types.StatusCodeRecordResult {
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
                    status : Types.CanisterStatus = #Running;
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
                    status : Types.CanisterStatus = #Running;
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
                    status : Types.CanisterStatus = #Running;
                };
                let putResponse = putMainerCreatorCanister(canisterEntryToAdd.address, canisterEntry);
                if (not putResponse) {
                    return #Err(#Other("An error adding the canister occurred"));
                };
            };
            case (#MainerAgent(#ShareService)) {
                let canisterEntry : Types.OfficialProtocolCanister = {
                    address : Text = canisterEntryToAdd.address;
                    canisterType: Types.ProtocolCanisterType = canisterEntryToAdd.canisterType;
                    creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                    createdBy : Principal = msg.caller;
                    ownedBy : Principal = Principal.fromActor(this);
                    status : Types.CanisterStatus = #Running;
                };
                let putResponse = putSharedServiceCanister(canisterEntryToAdd.address, canisterEntry);
                if (not putResponse) {
                    return #Err(#Other("An error adding the canister occurred"));
                };
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };
        return #Ok({ status_code = 200 });
    };

    // TODO - Implementation:: Function to unlock a mAIner (and thus gain the right to create one and follow the creation flow below)
    // (called by backend e.g. when lottery is won, later on by users directly too)
    public shared (msg) func unlockUserMainerAgent(mainerCreationInput : Types.MainerCreationInput) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized); 
        };
        // TODO - Security: scope permission correctly
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Sanity checks on configuration of mAIner agent
        let mainerConfig : Types.MainerConfigurationInput = mainerCreationInput.mainerConfig;
        switch (mainerConfig.selectedLLM) {
            case (null) {
                // use default model
            };
            case (?#Qwen2_5_500M) {
                // continue
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };
        switch (mainerConfig.mainerAgentCanisterType) {
            case (#Own) {
                // continue
            };
            case (#ShareAgent) {
                // continue
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };

        var ownedBy : Principal = msg.caller; // User
        if (Principal.isController(msg.caller)) {
            switch (mainerCreationInput.owner) {
                case (null) {
                    return #Err(#Other("Unsupported"));
                };
                case (?ownerPrincipal) {
                    ownedBy := ownerPrincipal; // User specified by Controller
                };
            };            
        };
        
        let canisterEntry : Types.OfficialMainerAgentCanister = {
            address : Text = ""; // To be assigned (when Controller canister was created)
            canisterType: Types.ProtocolCanisterType = #MainerAgent(mainerConfig.mainerAgentCanisterType);
            creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            createdBy : Principal = msg.caller; // Controller (e.g. backend) or User
            ownedBy : Principal = ownedBy;
            status : Types.CanisterStatus = #Unlocked;
            mainerConfig : Types.MainerConfigurationInput = mainerConfig;
        };
        switch (putUserMainerAgent(canisterEntry)) {
            case (true) {
                return #Ok(canisterEntry);
            };
            case (false) { return #Err(#FailedOperation); }
        };
    };

    // Function for user to create a new mAIner agent
    public shared (msg) func createUserMainerAgent(mainerCreationInput : Types.MainerCreationInput) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized); 
        };
        // Sanity checks on configuration of mAIner agent
        let mainerConfig : Types.MainerConfigurationInput = mainerCreationInput.mainerConfig;
        switch (mainerConfig.selectedLLM) {
            case (null) {
                // use default model
            };
            case (?#Qwen2_5_500M) {
                // continue
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };
        switch (mainerConfig.mainerAgentCanisterType) {
            case (#Own) {
                // continue
            };
            case (#ShareAgent) {
                // continue
            };
            case (#ShareService) {
                // Only a controller is allowed to create a shared service canister
                if (not Principal.isController(msg.caller)) {
                    return #Err(#Unauthorized);
                };
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };

        // TODO - Implementation: verify that the user has an unlocked mAIner entry of the mainerAgentCanisterType type (thus is allowed to create the new mAIner)
        /* switch (getUserMainerAgents(msg.caller)) {
            case (null) {
                return #Err(#Unauthorized);
            };
            case (?userMainerEntries) {
                // Find entry by creationTimestamp as no Controller address exists yet
                switch (List.find<Types.OfficialMainerAgentCanister>(userMainerEntries, func(mainerEntry: Types.OfficialProtocolCanister) : Bool { mainerEntry.creationTimestamp == mainerInfo.creationTimestamp } )) {
                    case (null) {
                        return #Err(#InvalidId);
                    };
                    case (?userMainerEntry) {
                        // Sanity checks on userMainerEntry (i.e. info provided is correct and matches entry info)
                        if (userMainerEntry.address != "") {
                            // At this point, no canister should have been created, i.e. no canister address
                            return #Err(#InvalidId);
                        };
                        switch (userMainerEntry.canisterType) {
                            case (#MainerAgent(mainerType)) {
                                if (mainerConfig.mainerAgentCanisterType != mainerType) {
                                    // wrong mAIner type (Own vs Shared)
                                    return #Err(#InvalidId);
                                };
                                // continue
                            };
                            case (_) { return #Err(#Other("Unsupported")); }
                        };
                        switch (userMainerEntry.status) {
                            case (#Unlocked) {
                                // continue
                            };
                            case (#Paid) {
                                return #Err(#Other("Continue with next call in flow"));
                            };
                            case (_) { return #Err(#Other("Unsupported")); }
                        };
                    };
                };
            };
        }; */

        // TODO - Implementation: verify user's payment for this agent via mainerCreationInput.paymentTransactionBlockId https://github.com/bob-robert-ai/bob/blob/3c1d19c4f8ce7de5c74654855e7be44117973d19/minter-v2/src/main.rs#L134
        //        Skip payment verification in case of ShareService, which is created by an Admin (Controller)
        let transactionToVerify = mainerCreationInput.paymentTransactionBlockId;

        let canisterEntry : Types.OfficialMainerAgentCanister = {
            address : Text = ""; // To be assigned (when Controller canister was created)
            canisterType: Types.ProtocolCanisterType = #MainerAgent(mainerConfig.mainerAgentCanisterType);
            creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            createdBy : Principal = msg.caller; // User (Admin (controller) in case of ShareService)
            ownedBy : Principal = msg.caller; // User (Admin (controller) in case of ShareService)
            status : Types.CanisterStatus = #Paid;
            mainerConfig : Types.MainerConfigurationInput = mainerConfig;
        };
        switch (putUserMainerAgent(canisterEntry)) {
            case (true) {
                return #Ok(canisterEntry);
            };
            case (false) { return #Err(#FailedOperation); }
        };
    };

    // Function for user to create a new mAIner agent Controller canister
    public shared (msg) func spinUpMainerControllerCanister(mainerInfo : Types.OfficialMainerAgentCanister) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Sanity checks on mAIner info
        if (not Principal.equal(mainerInfo.ownedBy, msg.caller)) {
            // Only the same user may continue with the creation flow
            return #Err(#Unauthorized);
        };
        if (mainerInfo.address != "") {
            // At this point, no canister should have been created, i.e. no canister address
            return #Err(#InvalidId);
        };
        switch (mainerInfo.canisterType) {
            case (#MainerAgent(_)) {
                // continue
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };
        switch (mainerInfo.status) {
            case (#Paid) {
                // continue
            };
            case (#ControllerCreationInProgress) {
                // indicates a retry
                // continue
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };

        // Verify existing mAIner entry
        switch (getUserMainerAgents(msg.caller)) {
            case (null) {
                return #Err(#Unauthorized);
            };
            case (?userMainerEntries) {
                // Find entry by creationTimestamp as no Controller address exists yet
                switch (List.find<Types.OfficialMainerAgentCanister>(userMainerEntries, func(mainerEntry: Types.OfficialProtocolCanister) : Bool { mainerEntry.creationTimestamp == mainerInfo.creationTimestamp } )) {
                    case (null) {
                        return #Err(#InvalidId);
                    };
                    case (?userMainerEntry) {
                        // Sanity checks on userMainerEntry (i.e. info provided is correct and matches entry info)
                        if (userMainerEntry.address != "") {
                            // At this point, no canister should have been created, i.e. no canister address
                            return #Err(#InvalidId);
                        };
                        switch (userMainerEntry.canisterType) {
                            case (#MainerAgent(_)) {
                                // continue
                            };
                            case (_) { return #Err(#Other("Unsupported")); }
                        };
                        switch (userMainerEntry.status) {
                            case (#Paid) {
                                // continue
                            };
                            case (#ControllerCreationInProgress) {
                                // indicates a retry
                                // continue
                            };
                            case (_) { return #Err(#Other("Unsupported")); }
                        };
                        let temporaryEntry : Types.OfficialMainerAgentCanister = {
                            address : Text = userMainerEntry.address;
                            canisterType: Types.ProtocolCanisterType = userMainerEntry.canisterType;
                            creationTimestamp : Nat64 = userMainerEntry.creationTimestamp;
                            createdBy : Principal = userMainerEntry.createdBy;
                            ownedBy : Principal = userMainerEntry.ownedBy;
                            status : Types.CanisterStatus = #ControllerCreationInProgress; // only field updated
                            mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                        };
                        switch (putUserMainerAgent(temporaryEntry)) {
                            case (true) {
                                // continue
                            };
                            case (false) { return #Err(#FailedOperation); }
                        };
                        // Forward creation request to mAIner Creator canister
                        switch (getNextMainerCreatorCanisterEntry()) {
                            case (null) {
                                // This should never happen as it indicates there isn't any mAIner Creator canister registered here
                                return #Err(#Unauthorized);
                            };
                            case (?mainerCreatorEntry) {
                                let creatorCanisterActor = actor(mainerCreatorEntry.address): Types.MainerCreator_Actor;

                                var associatedCanisterAddress : ?Types.CanisterAddress = null;
                                switch (userMainerEntry.canisterType) {
                                    case (#MainerAgent(#Own)) {
                                        // continue
                                    };
                                    case (#MainerAgent(#ShareService)) {
                                        // continue
                                    };
                                    case (#MainerAgent(#ShareAgent)) {
                                        // if of type ShareAgent, the shareServiceCanisterAddress is provided from the Game State info and added here as associatedCanisterAddress
                                        switch (getNextSharedServiceCanisterEntry()) {
                                            case (null) {
                                                // This should never happen as it indicates there isn't any Shared mAIning Service canister registered here
                                                return #Err(#Unauthorized);
                                            };
                                            case (?sharedServiceEntry) {
                                                associatedCanisterAddress := ?sharedServiceEntry.address;
                                            };
                                        };
                                    };
                                    case (_) { return #Err(#Other("Unsupported")); }
                                };
                                
                                let canisterCreationInput : Types.CanisterCreationConfiguration = {
                                    canisterType : Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                    owner: Principal = userMainerEntry.ownedBy; // User
                                    associatedCanisterAddress : ?Types.CanisterAddress = associatedCanisterAddress; // null for #Own, shareServiceCanisterAddress for ShareAgent
                                    mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                    userMainerEntryCreationTimestamp : Nat64 = userMainerEntry.creationTimestamp;
                                    userMainerEntryCanisterType : Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                };
                                
                                // TODO - outcomment checks on cycles used during canister creation
                                let IC_Management_Actor : ICManagementCanister.IC_Management = actor ("aaaaa-aa");
                                D.print("GameState: spinUpMainerControllerCanister - Get cycles balance of mAInerCreator ("# debug_show(mainerCreatorEntry.address) #  ") before calling createCanister.");
                                var cyclesBefore : Nat = 0;
                                try {
                                    let canisterStatus = await IC_Management_Actor.canister_status({canister_id = Principal.fromText(mainerCreatorEntry.address);});
                                    cyclesBefore := canisterStatus.cycles;
                                } catch (e) {
                                    D.print("GameState: spinUpMainerControllerCanister - Failed to retrieve info for mAInerCreator: " # debug_show(mainerCreatorEntry.address)  # Error.message(e) );
                                    return #Err(#Other("GameState: spinUpMainerControllerCanister - Failed to retrieve info for mAInerCreator: " # debug_show(mainerCreatorEntry.address) # Error.message(e)));
                                };
                                D.print("GameState: spinUpMainerControllerCanister - cycles balance of mAInerCreator ("# debug_show(mainerCreatorEntry.address) #  ") before calling createCanister = " # debug_show(cyclesBefore) );

                                // TODO - Implementation: charge with cycles (the user paid for)
                                let cyclesAdded = MAINER_AGENT_CTRLB_CREATION_CYCLES_REQUIRED; // (TODO - adjust & sync with amount used by mAInerCreator)
                                Cycles.add<system>(cyclesAdded);

                                // This only creates the canister and returns:
                                // -> Use await, so we can return the controller's address to frontend
                                let result : Types.CanisterCreationResult = await creatorCanisterActor.createCanister(canisterCreationInput);

                                D.print("GameState: spinUpMainerControllerCanister - Get cycles balance of mAInerCreator ("# debug_show(mainerCreatorEntry.address) #  ") after calling createCanister.");
                                var cyclesAfter : Nat = 0;
                                try {
                                    let canisterStatus = await IC_Management_Actor.canister_status({canister_id = Principal.fromText(mainerCreatorEntry.address);});
                                    cyclesAfter := canisterStatus.cycles;
                                } catch (e) {
                                    D.print("GameState: spinUpMainerControllerCanister - Failed to retrieve info for mAInerCreator: " # debug_show(mainerCreatorEntry.address)  # Error.message(e) );
                                    return #Err(#Other("GameState: spinUpMainerControllerCanister - Failed to retrieve info for mAInerCreator: " # debug_show(mainerCreatorEntry.address) # Error.message(e)));
                                };
                                let cyclesUsed : Nat = cyclesBefore + cyclesAdded - cyclesAfter;
                                D.print("GameState: spinUpMainerControllerCanister - cycles balance of mAInerCreator (" # debug_show(mainerCreatorEntry.address) #  ") after calling createCanister = " # debug_show(cyclesAfter) );
                                D.print("GameState: spinUpMainerControllerCanister - cycles added   to mAInerCreator (" # debug_show(mainerCreatorEntry.address) #  ")                              = " # debug_show(cyclesAdded) );
                                D.print("GameState: spinUpMainerControllerCanister - cycles used    by mAInerCreator (" # debug_show(mainerCreatorEntry.address) #  ")                              = " # debug_show(cyclesUsed) );

                                switch (result) {
                                    case (#Ok(canisterCreationRecord)) {
                                        // Setup the controller canister (install code & configurations)
                                        ignore creatorCanisterActor.setupCanister(canisterCreationRecord.newCanisterId, canisterCreationInput);

                                        // TODO: replace it with an actual call to addMainerAgentCanister
                                        let canisterEntry : Types.OfficialMainerAgentCanister = {
                                            address : Text = canisterCreationRecord.newCanisterId; // New mAIner Controller canister's id
                                            canisterType: Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                            creationTimestamp : Nat64 = userMainerEntry.creationTimestamp;
                                            createdBy : Principal = Principal.fromText(mainerCreatorEntry.address); // mAIner Creator
                                            ownedBy : Principal = userMainerEntry.ownedBy; // User
                                            status : Types.CanisterStatus = #ControllerCreationInProgress;
                                            mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                        };
                                        let _ = putUserMainerAgent(canisterEntry);
                                        let _ = putMainerAgentCanister(canisterEntry.address, canisterEntry);
                                        D.print("GameState: spinUpMainerControllerCanister - returning canisterEntry: " # debug_show(canisterEntry) );
                                        return #Ok(canisterEntry);
                                    };
                                    case (_) { return #Err(#FailedOperation); };
                                };            
                            };
                        };
                    };
                };
            };
        };
    };

    // Function for user to set up an LLM for a mAIner agent
    public shared (msg) func setUpMainerLlmCanister(mainerInfo : Types.OfficialMainerAgentCanister) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Sanity checks on mAIner info
        if (not Principal.equal(mainerInfo.ownedBy, msg.caller)) {
            // Only the same user may continue with the creation flow
            return #Err(#Unauthorized);
        };
        if (mainerInfo.address == "") {
            // At this point, the mAIner Controller canister should have been created
            return #Err(#InvalidId);
        };
        switch (mainerInfo.canisterType) {
            case (#MainerAgent(#Own)) {
                // mAIners of type Own may have dedicated LLMs attached
                // continue
            };
            case (#MainerAgent(#ShareService)) {
                // mAIners of type ShareService may have dedicated LLMs attached
                // continue
            };
            case (_) { 
                D.print("GameState: setUpMainerLlmCanister - Unsupported mainerInfo.canisterType: " # debug_show(mainerInfo.canisterType) );
                return #Err(#Other("Unsupported")); 
            }
        };
        switch (mainerInfo.status) {
            case (#ControllerCreated) {
                // continue
            };
            case (#LlmSetupInProgress) {
                // indicates a retry
                // continue
            };
            case (_) { 
                D.print("GameState: setUpMainerLlmCanister - Unsupported mainerInfo.status: " # debug_show(mainerInfo.status) );
                return #Err(#Other("Unsupported")); }
        };

        // Verify existing mAIner entry
        switch (getUserMainerAgents(msg.caller)) {
            case (null) {
                return #Err(#Unauthorized);
            };
            case (?userMainerEntries) {
                switch (List.find<Types.OfficialMainerAgentCanister>(userMainerEntries, func(mainerEntry: Types.OfficialMainerAgentCanister) : Bool { mainerEntry.address == mainerInfo.address } )) {
                    case (null) {
                        return #Err(#InvalidId);
                    };
                    case (?userMainerEntry) {
                        // Sanity checks on userMainerEntry (i.e. address provided is correct and matches entry info)
                        switch (userMainerEntry.canisterType) {
                            case (#MainerAgent(#Own)) {
                                // mAIners of type Own may have dedicated LLMs attached
                                // continue
                            };
                            case (#MainerAgent(#ShareService)) {
                                // mAIners of type ShareService may have dedicated LLMs attached
                                // continue
                            };
                            case (_) { 
                                D.print("GameState: setUpMainerLlmCanister - Unsupported userMainerEntry.canisterType: " # debug_show(userMainerEntry.canisterType) );
                                return #Err(#Other("Unsupported")); 
                            }
                        };
                        switch (userMainerEntry.status) {
                            case (#ControllerCreated) {
                                // continue
                            };
                            case (#LlmSetupInProgress) {
                                // indicates a retry
                                // continue
                            };
                            case (_) { 
                                D.print("GameState: setUpMainerLlmCanister - Unsupported userMainerEntry.status: " # debug_show(userMainerEntry.status) );
                                return #Err(#Other("Unsupported")); 
                            }
                        };

                        // ------------------------------------------------------
                        // Update status of the controller (usermAInerEntry) to LlmSetupInProgress
                        let temporaryEntry : Types.OfficialMainerAgentCanister = {
                            address : Text = userMainerEntry.address;
                            canisterType: Types.ProtocolCanisterType = userMainerEntry.canisterType;
                            creationTimestamp : Nat64 = userMainerEntry.creationTimestamp; // for deduplication by putUserMainerAgent
                            createdBy : Principal = userMainerEntry.createdBy;
                            ownedBy : Principal = userMainerEntry.ownedBy;
                            status : Types.CanisterStatus = #LlmSetupInProgress; // only field updated
                            mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                        };
                        switch (putUserMainerAgent(temporaryEntry)) {
                            case (true) {
                                // continue
                            };
                            case (false) { return #Err(#FailedOperation); }
                        };
                        let _ = putMainerAgentCanister(userMainerEntry.address, temporaryEntry);
                        // ------------------------------------------------------
                        
                        // Forward creation request to mAIner Creator canister
                        switch (getNextMainerCreatorCanisterEntry()) {
                            case (null) {
                                // This should never happen as it indicates there isn't any mAIner Creator canister registered here
                                return #Err(#Unauthorized);
                            };
                            case (?mainerCreatorEntry) {
                                let creatorCanisterActor = actor(mainerCreatorEntry.address): Types.MainerCreator_Actor;
                                let canisterCreationInput : Types.CanisterCreationConfiguration = {
                                    canisterType : Types.ProtocolCanisterType = #MainerLlm;
                                    owner: Principal = userMainerEntry.ownedBy; // User
                                    associatedCanisterAddress : ?Types.CanisterAddress = ?userMainerEntry.address; // Controller address
                                    mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                    userMainerEntryCreationTimestamp : Nat64 = userMainerEntry.creationTimestamp; // Controller
                                    userMainerEntryCanisterType : Types.ProtocolCanisterType = userMainerEntry.canisterType; // Controller
                                };

                                // TODO - outcomment checks on cycles used during canister creation
                                let IC_Management_Actor : ICManagementCanister.IC_Management = actor ("aaaaa-aa");
                                D.print("GameState: setUpMainerLlmCanister - Get cycles balance of mAInerCreator " # debug_show(mainerCreatorEntry.address) # "before calling createCanister.");
                                var cyclesBefore : Nat = 0;
                                try {
                                    let canisterStatus = await IC_Management_Actor.canister_status({canister_id = Principal.fromText(mainerCreatorEntry.address);});
                                    cyclesBefore := canisterStatus.cycles;
                                } catch (e) {
                                    D.print("GameState: setUpMainerLlmCanister - Failed to retrieve info for mAInerCreator: " # debug_show(mainerCreatorEntry.address)  # Error.message(e) );
                                    return #Err(#Other("GameState: setUpMainerLlmCanister - Failed to retrieve info for mAInerCreator: " # debug_show(mainerCreatorEntry.address) # Error.message(e)));
                                };
                                D.print("GameState: setUpMainerLlmCanister - cycles balance of mAInerCreator " # debug_show(mainerCreatorEntry.address) # "before calling createCanister = " # debug_show(cyclesBefore) );  

                                // TODO - Implementation: charge with cycles (the user paid for)
                                let cyclesAdded = MAINER_AGENT_LLM_CREATION_CYCLES_REQUIRED; // (TODO - adjust & sync with amount used by mAInerCreator)
                                Cycles.add<system>(cyclesAdded);

                                // This only creates the LLM canister and returns
                                let result : Types.CanisterCreationResult = await creatorCanisterActor.createCanister(canisterCreationInput);

                                D.print("GameState: setUpMainerLlmCanister - Get cycles balance of mAInerCreator ()"# debug_show(mainerCreatorEntry.address) #  ") after calling createCanister.");
                                var cyclesAfter : Nat = 0;
                                try {
                                    let canisterStatus = await IC_Management_Actor.canister_status({canister_id = Principal.fromText(mainerCreatorEntry.address);});
                                    cyclesAfter := canisterStatus.cycles;
                                } catch (e) {
                                    D.print("GameState: setUpMainerLlmCanister - Failed to retrieve info for mAInerCreator: " # debug_show(mainerCreatorEntry.address)  # Error.message(e) );
                                    return #Err(#Other("GameState: setUpMainerLlmCanister - Failed to retrieve info for mAInerCreator: " # debug_show(mainerCreatorEntry.address) # Error.message(e)));
                                };
                                let cyclesUsed : Nat = cyclesBefore + cyclesAdded - cyclesAfter;
                                D.print("GameState: setUpMainerLlmCanister - cycles balance of mAInerCreator " # debug_show(mainerCreatorEntry.address) # "after calling createCanister = " # debug_show(cyclesAfter) );  
                                D.print("GameState: setUpMainerLlmCanister - cyclesUsed by mAInerCreator: " # debug_show(cyclesUsed) );


                                switch (result) {
                                    case (#Ok(canisterCreationRecord)) {
                                        // Setup the LLM canister (install code & configurations)
                                        ignore creatorCanisterActor.setupCanister(canisterCreationRecord.newCanisterId, canisterCreationInput);

                                        // TODO: replace it with an actual call to addMainerAgentCanister
                                        let canisterEntry : Types.OfficialMainerAgentCanister = {
                                            address : Text = userMainerEntry.address; // Controller 
                                            canisterType: Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                            creationTimestamp : Nat64 = userMainerEntry.creationTimestamp;
                                            createdBy : Principal = Principal.fromText(mainerCreatorEntry.address); // mAIner Creator
                                            ownedBy : Principal = userMainerEntry.ownedBy; // User
                                            status : Types.CanisterStatus = #LlmSetupInProgress;
                                            mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                        };
                                        let _ = putUserMainerAgent(canisterEntry);
                                        let _ = putMainerAgentCanister(canisterEntry.address, canisterEntry);
                                        D.print("GameState: setUpMainerLlmCanister - returning canisterEntry: " # debug_show(canisterEntry) );                                        
                                        return #Ok(canisterEntry);
                                    };
                                    case (_) { return #Err(#FailedOperation); };
                                };            
                            };
                        };
                    };
                };
            };
        };
    };

    // Function for user to add an LLM to an existing mAIner agent
    public shared (msg) func addLlmCanisterToMainer(mainerInfo : Types.OfficialMainerAgentCanister) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // For now, only Controller canisters are allowed to add LLMs to mAIners
        // This is temporary solution to ensure we scale the system appropriately
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // TODO - Implementation: add payment info to params and verify user payment (for new LLM canister)

        // Sanity checks on mAIner info
        if (not Principal.equal(mainerInfo.ownedBy, msg.caller)) {
            // Only the mAIner owner may call this
            return #Err(#Unauthorized);
        };
        if (mainerInfo.address == "") {
            // The mAIner Controller canister address is needed
            return #Err(#InvalidId);
        };
        switch (mainerInfo.canisterType) {
            case (#MainerAgent(#Own)) {
                // mAIners of type Own may have dedicated LLMs attached
                // continue
            };
            case (#MainerAgent(#ShareService)) {
                // mAIners of type ShareService may have dedicated LLMs attached
                // continue
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };
        switch (mainerInfo.status) {
            // mAIner already has been created and is not currently setting up an LLM
            case (#ControllerCreated) {
                // continue
            };
            case (#LlmSetupFinished) {
                // continue
            };
            case (#Running) {
                // continue
            };
            case (#Paused) {
                // continue
            };
            case (_) { D.print("GameState: addLlmCanisterToMainer - Unsupported mainerInfo.status: " # debug_show(mainerInfo.status) );
                return #Err(#Other("Unsupported")); }
        };

        // Verify existing mAIner entry
        switch (getUserMainerAgents(msg.caller)) {
            case (null) {
                return #Err(#Unauthorized);
            };
            case (?userMainerEntries) {
                switch (List.find<Types.OfficialMainerAgentCanister>(userMainerEntries, func(mainerEntry: Types.OfficialMainerAgentCanister) : Bool { mainerEntry.address == mainerInfo.address } )) {
                    case (null) {
                        return #Err(#InvalidId);
                    };
                    case (?userMainerEntry) {
                        // Sanity checks on userMainerEntry (i.e. address provided is correct and matches entry info)
                        switch (userMainerEntry.canisterType) {
                            case (#MainerAgent(#Own)) {
                                // mAIners of type Own may have dedicated LLMs attached
                                // continue
                            };
                            case (#MainerAgent(#ShareService)) {
                                // mAIners of type ShareService may have dedicated LLMs attached
                                // continue
                            };
                            case (_) { 
                                D.print("GameState: addLlmCanisterToMainer - Unsupported mAIner type: " # debug_show(userMainerEntry.canisterType) );   
                                return #Err(#Other("Unsupported")); }
                        };
                        switch (userMainerEntry.status) {
                            // mAIner already has been created and is not currently setting up an LLM
                            case (#ControllerCreated) {
                                // continue
                            };
                            case (#LlmSetupFinished) {
                                // continue
                            };
                            case (#Running) {
                                // continue
                            };
                            case (#Paused) {
                                // continue
                            };
                            case (_) { 
                                D.print("GameState: addLlmCanisterToMainer - Unsupported userMainerEntry.status: " # debug_show(userMainerEntry.status) );
                                return #Err(#Other("Unsupported")); }
                        };

                        let temporaryEntry : Types.OfficialMainerAgentCanister = {
                            address : Text = userMainerEntry.address;
                            canisterType: Types.ProtocolCanisterType = userMainerEntry.canisterType;
                            creationTimestamp : Nat64 = userMainerEntry.creationTimestamp; // for deduplication by putUserMainerAgent
                            createdBy : Principal = userMainerEntry.createdBy;
                            ownedBy : Principal = userMainerEntry.ownedBy;
                            status : Types.CanisterStatus = #LlmSetupInProgress; // only field updated
                            mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                        };
                        switch (putUserMainerAgent(temporaryEntry)) {
                            case (true) {
                                // continue
                            };
                            case (false) { return #Err(#FailedOperation); }
                        };
                        
                        // Forward creation request to mAIner Creator canister
                        switch (getNextMainerCreatorCanisterEntry()) {
                            case (null) {
                                // This should never happen as it indicates there isn't any mAIner Creator canister registered here
                                return #Err(#Unauthorized);
                            };
                            case (?mainerCreatorEntry) {
                                let creatorCanisterActor = actor(mainerCreatorEntry.address): Types.MainerCreator_Actor;
                                let canisterCreationInput : Types.CanisterCreationConfiguration = {
                                    canisterType : Types.ProtocolCanisterType = #MainerLlm;
                                    owner: Principal = userMainerEntry.ownedBy; // User
                                    associatedCanisterAddress : ?Types.CanisterAddress = ?userMainerEntry.address; // Controller address
                                    mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                    userMainerEntryCreationTimestamp : Nat64 = userMainerEntry.creationTimestamp; // for deduplication by putUserMainerAgent
                                    userMainerEntryCanisterType : Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                };
                                // TODO - outcomment checks on cycles used during canister creation
                                let IC_Management_Actor : ICManagementCanister.IC_Management = actor ("aaaaa-aa");
                                D.print("GameState: addLlmCanisterToMainer - Get cycles balance of mAInerCreator ()"# debug_show(mainerCreatorEntry.address) #  ") before calling createCanister.");
                                var cyclesBefore : Nat = 0;
                                try {
                                    let canisterStatus = await IC_Management_Actor.canister_status({canister_id = Principal.fromText(mainerCreatorEntry.address);});
                                    cyclesBefore := canisterStatus.cycles;
                                } catch (e) {
                                    D.print("GameState: addLlmCanisterToMainer - Failed to retrieve info for mAInerCreator: " # debug_show(mainerCreatorEntry.address)  # Error.message(e) );
                                    return #Err(#Other("GameState: addLlmCanisterToMainer - Failed to retrieve info for mAInerCreator: " # debug_show(mainerCreatorEntry.address) # Error.message(e)));
                                };
                                D.print("GameState: addLlmCanisterToMainer - cycles balance of mAInerCreator ()"# debug_show(mainerCreatorEntry.address) #  ") before calling createCanister = " # debug_show(cyclesBefore) );

                                // TODO - Implementation: charge with cycles (the user paid for)
                                let cyclesAdded = MAINER_AGENT_LLM_CREATION_CYCLES_REQUIRED; // (TODO - adjust & sync with amount used by mAInerCreator)
                                Cycles.add<system>(cyclesAdded);

                                // createCanister will make callback to addMainerAgentCanister with updated status
                                ignore creatorCanisterActor.createCanister(canisterCreationInput);
                                return #Ok(temporaryEntry);

                                // TODO - REMOVE THIS ONCE CALLBACK IS IMPLEMENTED
                                // D.print("GameState: addLlmCanisterToMainer - Get cycles balance of mAInerCreator ()"# debug_show(mainerCreatorEntry.address) #  ") after calling createCanister.");
                                // var cyclesAfter : Nat = 0;
                                // try {
                                //     let canisterStatus = await IC_Management_Actor.canister_status({canister_id = Principal.fromText(mainerCreatorEntry.address);});
                                //     cyclesAfter := canisterStatus.cycles;
                                // } catch (e) {
                                //     D.print("GameState: addLlmCanisterToMainer - Failed to retrieve info for mAInerCreator: " # debug_show(mainerCreatorEntry.address)  # Error.message(e) );
                                //     return #Err(#Other("GameState: addLlmCanisterToMainer - Failed to retrieve info for mAInerCreator: " # debug_show(mainerCreatorEntry.address) # Error.message(e)));
                                // };
                                // let cyclesUsed : Nat = cyclesBefore + cyclesAdded - cyclesAfter;
                                // D.print("GameState: addLlmCanisterToMainer - cycles balance of mAInerCreator ()"# debug_show(mainerCreatorEntry.address) #  ") after calling createCanister = " # debug_show(cyclesAfter) );
                                // D.print("GameState: addLlmCanisterToMainer - cyclesUsed by mAInerCreator: " # debug_show(cyclesUsed) );

                                // switch (result) {
                                //     case (#Ok(canisterCreationRecord)) {
                                //         //TODO - Design: decide what to do with canisterCreationRecord.newCanisterId; of new LLM canister, e.g. attach to OfficialMainerAgentCanister type and entry
                                //         /* let canisterEntry : Types.OfficialMainerAgentCanister = {
                                //             address : Text = userMainerEntry.address; // Controller 
                                //             canisterType: Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                //             creationTimestamp : Nat64 = userMainerEntry.creationTimestamp;
                                //             createdBy : Principal = Principal.fromText(mainerCreatorEntry.address); // mAIner Creator
                                //             ownedBy : Principal = userMainerEntry.ownedBy; // User
                                //             status : Types.CanisterStatus = #LlmSetupFinished;
                                //             mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                //         };
                                //         let result = putMainerAgentCanister(canisterEntry.address, canisterEntry); */
                                //         return #Ok(userMainerEntry);
                                //     };
                                //     case (_) { return #Err(#FailedOperation); };
                                // };            
                            };
                        };
                    };
                };
            };
        };
    };

    // Function for mAIner Agent Creator canister to add new mAIner agent for user
    public shared (msg) func addMainerAgentCanister(canisterEntryToAdd : Types.OfficialMainerAgentCanister) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (canisterEntryToAdd.canisterType) {
            case (#MainerAgent(_)) {
                // continue
            };
            case (_) { 
                D.print("GameState: addMainerAgentCanister - Unsupported canisterEntryToAdd.canisterType: " # debug_show(canisterEntryToAdd.canisterType) );
                return #Err(#Other("Unsupported")); 
            }
        };

        // Only official mAIner Agent Creator canisters may call this
        D.print("GameState: addMainerAgentCanister - calling getMAinerCreatorCanister for caller: " # debug_show(Principal.toText(msg.caller)));
        switch (getMainerCreatorCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?mainerCreatorEntry) {
                let canisterEntry : Types.OfficialMainerAgentCanister = {
                    address : Text = canisterEntryToAdd.address;
                    canisterType: Types.ProtocolCanisterType = canisterEntryToAdd.canisterType;
                    creationTimestamp : Nat64 = canisterEntryToAdd.creationTimestamp;
                    createdBy : Principal = msg.caller;
                    ownedBy : Principal = canisterEntryToAdd.ownedBy;
                    status : Types.CanisterStatus = canisterEntryToAdd.status;
                    mainerConfig : Types.MainerConfigurationInput = canisterEntryToAdd.mainerConfig;
                };
                let _ = putUserMainerAgent(canisterEntry);
                let _ = putMainerAgentCanister(canisterEntryToAdd.address, canisterEntry);
                D.print("GameState: addMainerAgentCanister - putMainerAgentCanister for canisterEntry: " # debug_show(canisterEntry) ); 
                return #Ok(canisterEntry);
            };
        };
    };

    // TODO - Testing: remove; admin Function to add new mAIner agent for testing
    public shared (msg) func addMainerAgentCanisterAdmin(canisterEntryToAdd : Types.OfficialMainerAgentCanister) : async Types.MainerAgentCanisterResult {
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
            creationTimestamp :  Nat64 = canisterEntryToAdd.creationTimestamp;
            createdBy : Principal = canisterEntryToAdd.createdBy;
            ownedBy : Principal = canisterEntryToAdd.ownedBy;
            status : Types.CanisterStatus = canisterEntryToAdd.status;
            mainerConfig : Types.MainerConfigurationInput = canisterEntryToAdd.mainerConfig;
        }; 
        putMainerAgentCanister(canisterEntryToAdd.address, canisterEntry); 
    };

    // Function for user to top up cycles of an existing mAIner agent
    public shared (msg) func topUpCyclesForMainerAgent(mainerTopUpInfo : Types.MainerAgentTopUpInput) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Sanity checks on provided mAIner info
        let mainerInfo : Types.OfficialMainerAgentCanister = mainerTopUpInfo.mainerAgent;
        if (not Principal.equal(mainerInfo.ownedBy, msg.caller)) {
            // Only the mAIner owner may call this
            return #Err(#Unauthorized);
        };
        if (mainerInfo.address == "") {
            // The mAIner Controller canister address is needed
            return #Err(#InvalidId);
        };
        switch (mainerInfo.canisterType) {
            case (#MainerAgent(_)) {
                // continue
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };
        switch (mainerInfo.status) {
            // mAIner already has been created
            case (#ControllerCreated) {
                // continue
            };
            case (#LlmSetupInProgress) {
                // continue
            };
            case (#LlmSetupFinished) {
                // continue
            };
            case (#Running) {
                // continue
            };
            case (#Paused) {
                // continue
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };

        // Verify existing mAIner entry
        switch (getUserMainerAgents(msg.caller)) {
            case (null) {
                return #Err(#Unauthorized);
            };
            case (?userMainerEntries) {
                switch (List.find<Types.OfficialMainerAgentCanister>(userMainerEntries, func(mainerEntry: Types.OfficialMainerAgentCanister) : Bool { mainerEntry.address == mainerInfo.address } )) {
                    case (null) {
                        return #Err(#InvalidId);
                    };
                    case (?userMainerEntry) {
                        // Sanity checks on userMainerEntry (i.e. address provided is correct and matches entry info)
                        switch (userMainerEntry.canisterType) {
                            case (#MainerAgent(_)) {
                                // continue
                            };
                            case (_) { return #Err(#Other("Unsupported")); }
                        };
                        switch (userMainerEntry.status) {
                            // mAIner already has been created
                            case (#Running) {
                                // continue
                            };
                            case (#Paused) {
                                // continue
                            };
                            case (_) { return #Err(#Other("Unsupported")); }
                        };

                        // TODO - Implementation: verify user's payment for this agent via paymentTransactionBlockId https://github.com/bob-robert-ai/bob/blob/3c1d19c4f8ce7de5c74654855e7be44117973d19/minter-v2/src/main.rs#L134
                        let transactionToVerify = mainerTopUpInfo.paymentTransactionBlockId;
                        
                        // TODO - Implementation: credit mAIner agent with cycles (the user paid for)
                        // ALternative: credit via the CMC service
                        let IC_Management_Actor : ICManagementCanister.IC_Management = actor ("aaaaa-aa");
                        // Retrieve mAIner agent canister's info
                        D.print("GameState: topUpCyclesForMainerAgent - Verify agent canister's wasm module hash#####################################################################################################################################################################################");
                        try {
                            let deposit_cycles_args = { canister_id : Principal = Principal.fromText(userMainerEntry.address); };
                            // TODO - Implementation: charge call with cycles
                            let result = await IC_Management_Actor.deposit_cycles(deposit_cycles_args);
                            //TODO - Design: decide whether a top up history should be kept
                            return #Ok(userMainerEntry);
                        } catch (e) {
                            D.print("GameState: topUpCyclesForMainerAgent - Failed to credit cycles to mAIner: " # debug_show(mainerTopUpInfo) # Error.message(e));      
                            return #Err(#Other("GameState: topUpCyclesForMainerAgent - Failed to credit cycles to mAIner: " # debug_show(mainerTopUpInfo) # Error.message(e)));
                        };                        
                    };
                };
            };
        };
    };

    // Function for user to get their mAIner agent canisters
    public shared query (msg) func getMainerAgentCanistersForUser() : async Types.MainerAgentCanistersResult {
        // TODO - Testing: only for demo: allow open access
        return #Ok(getMainerAgents()); 
        
        // TODO - Testing: put access checks into place again 
        /* if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        switch (getUserMainerAgents(msg.caller)) {
            case (null) { return #Err(#Other("No canisters for this caller")); };
            case (?userCanistersList) {
                return #Ok(List.toArray<Types.OfficialProtocolCanister>(userCanistersList));                              
            };
        }; */
    };

    // Function to retrieve info on a mAIner agent canister
    public shared query (msg) func getMainerAgentCanisterInfo(canisterEntryToRetrieve : Types.CanisterRetrieveInput) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

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
                // Do we already have enough open responses?
                let openSubmissions : [Types.ChallengeResponseSubmission] = getOpenSubmissions();
                if (openSubmissions.size() >= THRESHOLD_MAX_OPEN_SUBMISSIONS) {
                    return #Err(#Other("We have a judging backlog & currently do not distribute open challenges to mAIners."));
                };
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
    public shared (msg) func submitChallengeResponse(challengeResponseSubmissionInput : Types.ChallengeResponseSubmissionInput) : async Types.ChallengeResponseSubmissionMetadataResult {
        D.print("GameState: submitChallengeResponse - entered");
        if (Principal.isAnonymous(msg.caller)) {
            let _cyclesKeptForFailedSubmission = Cycles.accept<system>(FAILED_SUBMISSION_CYCLES_CUT);
            D.print("GameState: submitChallengeResponse - 01");
            return #Err(#Unauthorized);
        };
        // Verify that submission is charged with cycles
        if (Cycles.available() < SUBMISSION_CYCLES_REQUIRED) {
            let _cyclesKeptForFailedSubmission = Cycles.accept<system>(FAILED_SUBMISSION_CYCLES_CUT);
            D.print("GameState: submitChallengeResponse - 02");
            D.print("GameState: submitChallengeResponse - cycles available: " # debug_show(Cycles.available()));
            D.print("GameState: submitChallengeResponse - cycles required : " # debug_show(SUBMISSION_CYCLES_REQUIRED));
            return #Err(#InsuffientCycles(SUBMISSION_CYCLES_REQUIRED));                    
        };
        // TODO - Implementation: adapt cycles burnt stats
        ignore increaseTotalProtocolCyclesBurnt(CYCLES_BURNT_RESPONSE_GENERATION);
        // Only official mAIner agent canisters may call this
        switch (getMainerAgentCanister(Principal.toText(msg.caller))) {
            case (null) {
                let _cyclesKeptForFailedSubmission = Cycles.accept<system>(FAILED_SUBMISSION_CYCLES_CUT);
                D.print("GameState: submitChallengeResponse - 03");
                return #Err(#Unauthorized);
            };
            case (?_mainerAgentEntry) {
                // Check that submission record looks correct
                if (challengeResponseSubmissionInput.submittedBy != msg.caller) {
                    let _cyclesKeptForFailedSubmission = Cycles.accept<system>(FAILED_SUBMISSION_CYCLES_CUT);
                    D.print("GameState: submitChallengeResponse - 04");
                    return #Err(#Unauthorized);
                };

                // Verify that challenge is open
                if (not verifyChallenge(#Open, challengeResponseSubmissionInput.challengeId)) {
                    let _cyclesKeptForFailedSubmission = Cycles.accept<system>(FAILED_SUBMISSION_CYCLES_CUT);
                    D.print("GameState: submitChallengeResponse - 05");
                    return #Err(#InvalidId);
                };

                // Verify that the mAIner is running the official wasm code (untampered)
                let IC_Management_Actor : ICManagementCanister.IC_Management = actor ("aaaaa-aa");
                // Retrieve mAIner agent canister's info
                D.print("GameState: submitChallengeResponse - Verify agent canister's wasm module hash#####################################################################################################################################################################################");
                try {
                    let agentCanisterInfo = await IC_Management_Actor.canister_info({
                        canister_id = challengeResponseSubmissionInput.submittedBy;
                        num_requested_changes = ?0;
                    });   
                    // Verify agent canister's wasm module hash
                    switch (agentCanisterInfo.module_hash) {
                        case (null) {
                            let _cyclesKeptForFailedSubmission = Cycles.accept<system>(FAILED_SUBMISSION_CYCLES_CUT);
                            D.print("GameState: submitChallengeResponse - agentCanisterInfo with null as module hash: " # debug_show(agentCanisterInfo)); 
                            // TODO - Design: further measurements?
                            return #Err(#Unauthorized);
                        };
                        case (?agentModuleHash) {
                            if (Blob.equal(agentModuleHash, officialMainerAgentCanisterWasmHash)) {
                                D.print("GameState: testMainerCodeIntegrityAdmin - agentCanisterInfo with official module hash: " # debug_show(agentCanisterInfo));
                                // continue as check passed
                            } else {
                                let _cyclesKeptForFailedSubmission = Cycles.accept<system>(FAILED_SUBMISSION_CYCLES_CUT);
                                D.print("GameState: submitChallengeResponse - agentCanisterInfo didn't pass verification: " # debug_show(agentCanisterInfo) # " - expected wasm hash = " # debug_show(officialMainerAgentCanisterWasmHash));
                                 
                                // TODO - Design: further measurements?
                                return #Err(#Unauthorized);
                            };
                        };
                    };
                } catch (e) {
                    let _cyclesKeptForFailedSubmission = Cycles.accept<system>(FAILED_SUBMISSION_CYCLES_CUT);
                    D.print("GameState: submitChallengeResponse - Failed to retrieve info for mAIner: " # debug_show(challengeResponseSubmissionInput) # Error.message(e));      
                    return #Err(#Other("GameState: testMainerCodeIntegrityAdmin - Failed to retrieve info for mAIner: " # debug_show(challengeResponseSubmissionInput) # Error.message(e)));
                };

                // Accept required cycles for submission
                let cyclesAcceptedForSubmission = Cycles.accept<system>(SUBMISSION_CYCLES_REQUIRED);
                if (cyclesAcceptedForSubmission != SUBMISSION_CYCLES_REQUIRED) {
                    // Sanity check: At this point, this should never fail
                    D.print("GameState: submitChallengeResponse - 07");
                    return #Err(#Unauthorized);                    
                };

                // Store the submission
                let submissionId : Text = await Utils.newRandomUniqueId();
                let submissionAdded : Types.ChallengeResponseSubmission = {
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
                    submissionId : Text = submissionId;
                    submittedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                    submissionStatus: Types.ChallengeResponseSubmissionStatus = #Submitted;
                };

                let putResult = putSubmission(submissionId, submissionAdded);
                let submissionMetada : Types.ChallengeResponseSubmissionMetadata = {
                    submissionId : Text = submissionId;
                    submittedTimestamp : Nat64 = submissionAdded.submittedTimestamp;
                    submissionStatus: Types.ChallengeResponseSubmissionStatus = submissionAdded.submissionStatus;
                };
                D.print("GameState: submitChallengeResponse - submitted!");
                return #Ok(submissionMetada);           
            };
        };
    };

    // Functions for Admin to retrieve submissions
    public shared query (msg) func getSubmissionsAdmin() : async Types.ChallengeResponseSubmissionsResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let submissions : [Types.ChallengeResponseSubmission] = getSubmissions();
        return #Ok(submissions);
    };

    public shared query (msg) func getNumSubmissionsAdmin() : async Types.NatResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let submissions : [Types.ChallengeResponseSubmission] = getSubmissions();
        return #Ok(submissions.size());
    };

    // Function for Judge canister to retrieve the next submission to score
    public shared (msg) func getNextSubmissionToJudge() : async Types.ChallengeResponseSubmissionResult {
        D.print("GameState: getNextSubmissionToJudge - entered");
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // Only official Judge canisters may call this
        switch (getJudgeCanister(Principal.toText(msg.caller))) {
            case (null) { 
                D.print("GameState: getNextSubmissionToJudge - 01");
                return #Err(#Unauthorized); 
            };
            case (?_judgeEntry) {
                var foundKey : ?Text = null;
                var foundSubmission : ?Types.ChallengeResponseSubmission = null;

                D.print("GameState: getNextSubmissionToJudge - searching for a submission to judge");
                for ((key, submission) in submissionsStorage.entries()) {
                    switch (submission.submissionStatus) {
                        case (#Submitted) {
                            D.print("GameState: getNextSubmissionToJudge - found a submission to judge");
                            foundKey := ?key;
                            foundSubmission := ?submission;

                            switch (foundKey, foundSubmission) {
                                case (?key, ?submission) {
                                    // (-) Found a submission with submissionStatus #Submitted
                                    // (-) Change submissionStatus to #Judging
                                    // (-) Return it to the Judge
                                    let updatedSubmission : Types.ChallengeResponseSubmission = {
                                        challengeTopic : Text = submission.challengeTopic;
                                        challengeTopicId : Text = submission.challengeTopicId;
                                        challengeTopicCreationTimestamp : Nat64 = submission.challengeTopicCreationTimestamp;
                                        challengeTopicStatus : Types.ChallengeTopicStatus = submission.challengeTopicStatus;
                                        challengeQuestion : Text = submission.challengeQuestion;
                                        challengeQuestionSeed : Nat32 = submission.challengeQuestionSeed;
                                        challengeId : Text = submission.challengeId;
                                        challengeCreationTimestamp : Nat64 = submission.challengeCreationTimestamp;
                                        challengeCreatedBy : Types.CanisterAddress = submission.challengeCreatedBy;
                                        challengeStatus : Types.ChallengeStatus = submission.challengeStatus;
                                        challengeClosedTimestamp : ?Nat64 = submission.challengeClosedTimestamp;
                                        submissionCyclesRequired : Nat = submission.submissionCyclesRequired;
                                        challengeQueuedId : Text = submission.challengeQueuedId;
                                        challengeQueuedBy : Principal = submission.challengeQueuedBy;
                                        challengeQueuedTo : Principal = submission.challengeQueuedTo;
                                        challengeQueuedTimestamp : Nat64 = submission.challengeQueuedTimestamp;
                                        challengeAnswer : Text = submission.challengeAnswer;
                                        challengeAnswerSeed : Nat32 = submission.challengeAnswerSeed;
                                        submittedBy : Principal = submission.submittedBy;
                                        submissionId : Text = submission.submissionId;
                                        submittedTimestamp : Nat64 = submission.submittedTimestamp;
                                        submissionStatus: Types.ChallengeResponseSubmissionStatus = #Judging;
                                    };
                                    D.print("GameState: getNextSubmissionToJudge - updatedSubmission = " # debug_show(updatedSubmission));
                                    submissionsStorage.put(key, updatedSubmission);
                                    return #Ok(updatedSubmission);
                                };
                                case (_, _) {
                                    return #Err(#Other("Unexpected Error"));
                                };
                            };
                        };
                        case (_) {}; // Skip other statuses
                    };
                };
                D.print("GameState: getNextSubmissionToJudge - no submissions to judge");
                return #Err(#Other("There are no submissions to judge"));
            };
        };
    };

    // Helper function to mint a reward on the token ledger
    private func mintRewardOnTokenLedger(participantEntryToReward : Types.ChallengeParticipantEntry) : async Bool {
        let TokenLedger_Actor : TokenLedger.TOKEN_LEDGER = actor (TOKEN_LEDGER_CANISTER_ID);

        let args : TokenLedger.TransferArg = {
            from_subaccount = null;
            to = {
                owner = participantEntryToReward.submittedBy;
                subaccount = null;
            };
            amount = participantEntryToReward.reward.amount;
            fee = null;
            memo = null;
            created_at_time = null;
        };

        try {
            // Call the ledger's icrc1_transfer function
            let result = await TokenLedger_Actor.icrc1_transfer(args);

            switch (result) {
                case (#Ok(blockIndex)) {
                    D.print("GameState: finalizeOpenChallenge - sending tokens successful: " # debug_show(blockIndex));
                    return true;
                };
                case (#Err(err)) {
                    D.print("GameState: finalizeOpenChallenge - Transfer error: " # debug_show(err));
                    // TODO - Error Handling (e.g. put into queue and try again later)
                    return false;
                };
            };
        } catch (e) {
            D.print("GameState: finalizeOpenChallenge - Failed to call ledger: " # Error.message(e));
            // TTODO - Error Handling (e.g. put into queue and try again later)
            return false;
        };
    };

    // Helper function to distribute rewards to the winners and participants of a challenge
    private func distributeRewardForChallenge(challengeWinnerDeclaration : Types.ChallengeWinnerDeclaration) : async Bool {
        /* challengeWinnerDeclaration looks like:
            public type ChallengeWinnerDeclaration = {
                challengeId : Text;
                finalizedTimestamp : Nat64;
                winner : ChallengeParticipantEntry;
                secondPlace : ChallengeParticipantEntry;
                thirdPlace : ChallengeParticipantEntry;
                participants : List.List<ChallengeParticipantEntry>;
            };
            public type ChallengeParticipantEntry = {
                submissionId : Text;
                submittedBy : Principal;
                ownedBy : Principal;
                result : ChallengeParticipationResult;
                reward : ChallengeWinnerReward;
            };
        */
        // Send rewards to mAIners
        // Reward winner
        ignore mintRewardOnTokenLedger(challengeWinnerDeclaration.winner);

        // Reward second place
        ignore mintRewardOnTokenLedger(challengeWinnerDeclaration.secondPlace);

        // Reward third place
        ignore mintRewardOnTokenLedger(challengeWinnerDeclaration.thirdPlace);

        // Rewards participants
        let participantsIter : Iter.Iter<Types.ChallengeParticipantEntry> = Iter.fromList(challengeWinnerDeclaration.participants);
        for (participantEntry in participantsIter) {
            ignore mintRewardOnTokenLedger(participantEntry);            
        };

        return true;
    };

    // Helper function to finalize an open challenge (close, declare winner, distribute reward)
    private func finalizeOpenChallenge(challengeId : Text) : async Bool {
        // Close the challenge
        switch (closeChallenge(challengeId)) {
            case (false) {
                // TODO - Error Handling (e.g. put into queue and try ranking again later)
                return false;
            };
            case (true) {
                // Rank scored responses and declare winner
                let rankResult : ?Types.ChallengeWinnerDeclaration = rankScoredResponsesForChallenge(challengeId);
                switch (rankResult) {
                    case (null) {
                        // TODO - Error Handling (e.g. put into queue and try ranking again later)
                        return false;
                    };
                    case (?challengeWinnerDeclaration) {
                        D.print("GameState: finalizeOpenChallenge - ranked and declared winner: " # debug_show(challengeWinnerDeclaration));
                        // Distribute reward to winners and participants
                        switch (await distributeRewardForChallenge(challengeWinnerDeclaration)) {
                            case (false) {
                                // TODO - Error Handling (e.g. put into queue and try ranking again later)
                                return false;
                            };
                            case (true) {
                                return true;
                            };
                        };
                    };
                };
            };
        };
    };

    // Function for Judge canister to add a new scored response
    public shared (msg) func addScoredResponse(scoredResponseInput : Types.ScoredResponseInput) : async Types.ScoredResponseResult {
        D.print("GameState: addScoredResponse - entered");
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // TODO - Implementation: adapt cycles burnt stats
        ignore increaseTotalProtocolCyclesBurnt(CYCLES_BURNT_JUDGE_SCORING);
        // Only official Judge canisters may call this
        switch (getJudgeCanister(Principal.toText(msg.caller))) {
            case (null) { 
                D.print("GameState: addScoredResponse - 01");
                return #Err(#Unauthorized); 
                };
            case (?_judgeEntry) {
                // Sanity checks on scored response
                if (scoredResponseInput.judgedBy != msg.caller) {
                    D.print("GameState: addScoredResponse - 02");
                    return #Err(#Unauthorized);
                };
                // TODO - Design: likely we want to store the submissions from the mAIners and check here that it was an actual submission and that the data matches up

                // Verify that challenge is open
                if (not verifyChallenge(#Open, scoredResponseInput.challengeId)) {
                    // TODO - Design: likely we want to store the scored response nevertheless for the closed challenge
                    D.print("GameState: addScoredResponse - 03");
                    return #Err(#InvalidId);
                };

                // TODO - Design: do we really need a separate storage for submissions & scored submissions?
                // Change submissionStatus of the submission in submissionsStorage to #Judged
                let submissionId : Text = scoredResponseInput.submissionId;
                let submission : Types.ChallengeResponseSubmission = {
                    challengeTopic : Text = scoredResponseInput.challengeTopic;
                    challengeTopicId : Text = scoredResponseInput.challengeTopicId;
                    challengeTopicCreationTimestamp : Nat64 = scoredResponseInput.challengeTopicCreationTimestamp;
                    challengeTopicStatus : Types.ChallengeTopicStatus = scoredResponseInput.challengeTopicStatus;
                    challengeQuestion : Text = scoredResponseInput.challengeQuestion;
                    challengeQuestionSeed : Nat32 = scoredResponseInput.challengeQuestionSeed;
                    challengeId : Text = scoredResponseInput.challengeId;
                    challengeCreationTimestamp : Nat64 = scoredResponseInput.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = scoredResponseInput.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = scoredResponseInput.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = scoredResponseInput.challengeClosedTimestamp;
                    submissionCyclesRequired : Nat = scoredResponseInput.submissionCyclesRequired;
                    challengeQueuedId : Text = scoredResponseInput.challengeQueuedId;
                    challengeQueuedBy : Principal = scoredResponseInput.challengeQueuedBy;
                    challengeQueuedTo : Principal = scoredResponseInput.challengeQueuedTo;
                    challengeQueuedTimestamp : Nat64 = scoredResponseInput.challengeQueuedTimestamp;
                    challengeAnswer : Text = scoredResponseInput.challengeAnswer;
                    challengeAnswerSeed : Nat32 = scoredResponseInput.challengeAnswerSeed;
                    submittedBy : Principal = scoredResponseInput.submittedBy;
                    submissionId : Text = scoredResponseInput.submissionId;
                    submittedTimestamp : Nat64 = scoredResponseInput.submittedTimestamp;
                    submissionStatus: Types.ChallengeResponseSubmissionStatus = #Judged;
                };
                D.print("GameState: addScoredResponse - calling putSubmission (change submissionStatus to #Judged)");
                D.print("GameState: addScoredResponse - submission = " # debug_show(submission));
                if (putSubmission(submissionId, submission) == false) {
                    D.print("GameState: addScoredResponse - 04");
                    return #Err(#Other("An error updating the submission occurred"));
                };
                
                // Store scored response for challenge in scoredResponsesPerChallenge
                let scoredResponseEntry : Types.ScoredResponse = {
                    challengeTopic : Text = scoredResponseInput.challengeTopic;
                    challengeTopicId : Text = scoredResponseInput.challengeTopicId;
                    challengeTopicCreationTimestamp : Nat64 = scoredResponseInput.challengeTopicCreationTimestamp;
                    challengeTopicStatus : Types.ChallengeTopicStatus = scoredResponseInput.challengeTopicStatus;
                    challengeQuestion : Text = scoredResponseInput.challengeQuestion;
                    challengeQuestionSeed : Nat32 = scoredResponseInput.challengeQuestionSeed;
                    challengeId : Text = scoredResponseInput.challengeId;
                    challengeCreationTimestamp : Nat64 = scoredResponseInput.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = scoredResponseInput.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = scoredResponseInput.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = scoredResponseInput.challengeClosedTimestamp;
                    submissionCyclesRequired : Nat = scoredResponseInput.submissionCyclesRequired;
                    challengeQueuedId : Text = scoredResponseInput.challengeQueuedId;
                    challengeQueuedBy : Principal = scoredResponseInput.challengeQueuedBy;
                    challengeQueuedTo : Principal = scoredResponseInput.challengeQueuedTo;
                    challengeQueuedTimestamp : Nat64 = scoredResponseInput.challengeQueuedTimestamp;
                    challengeAnswer : Text = scoredResponseInput.challengeAnswer;
                    challengeAnswerSeed : Nat32 = scoredResponseInput.challengeAnswerSeed;
                    submittedBy : Principal = scoredResponseInput.submittedBy;
                    submissionId : Text = scoredResponseInput.submissionId;
                    submittedTimestamp : Nat64 = scoredResponseInput.submittedTimestamp;
                    submissionStatus: Types.ChallengeResponseSubmissionStatus = #Judged;
                    judgedBy: Principal = scoredResponseInput.judgedBy;
                    score: Nat = scoredResponseInput.score;
                    scoreSeed: Nat32 = scoredResponseInput.scoreSeed;
                    judgedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                };
                D.print("GameState: addScoredResponse - All Good - calling putScoredResponseForChallenge");
                D.print("GameState: addScoredResponse - scoredResponseEntry = " # debug_show(scoredResponseEntry));
                let numberOfScoredResponsesForChallenge : Nat = putScoredResponseForChallenge(scoredResponseEntry);
                D.print("GameState: addScoredResponse - numberOfScoredResponsesForChallenge = " # debug_show(numberOfScoredResponsesForChallenge));
                D.print("GameState: addScoredResponse - THRESHOLD_SCORED_RESPONSES_PER_CHALLENGE = " # debug_show(THRESHOLD_SCORED_RESPONSES_PER_CHALLENGE));

                // Determine if ranking of scored responses can be triggered
                if (numberOfScoredResponsesForChallenge >= THRESHOLD_SCORED_RESPONSES_PER_CHALLENGE) {
                    // TODO - Design: we should close the challenge for handing out to mAIners, but we need to:
                    //       (-) accept mAIner submissions that have already received this challenge
                    //       (-) score those submissions
                    //       FOR NOW - JUST CLOSE IT AND RANK IT...
                    // Close challenge
                    D.print("GameState: addScoredResponse - reached threshold & closing the challenge: " # debug_show(scoredResponseInput.challengeQuestion));
                    switch (await finalizeOpenChallenge(scoredResponseInput.challengeId)) {
                        case (false) {
                            // TODO - Error Handling: error handling (e.g. put into queue and try again later)
                        };
                        case (true) {
                            // continue
                        };
                    };
                };

                // Return
                let result : Types.ScoredResponseReturn = {
                    success : Bool = true;
                };
                return #Ok(result);                                     
            };
        };
    };

    // Function to get info on the latest challenge winners
    public query (msg) func getRecentChallengeWinners() : async Types.ChallengeWinnersResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        return #Ok(getWinnersForRecentChallenges());
    };

    // Function to get recent protocol activity (TODO - Security: decide if access should remain public)
    public query func getRecentProtocolActivity() : async Types.ProtocolActivityResult {
        let winnersForRecentChallenges : [Types.ChallengeWinnerDeclaration] = getWinnersForRecentChallenges();
        let openChallenges : [Types.Challenge] = getOpenChallenges();
        let result : Types.ProtocolActivityRecord = {
            winners = winnersForRecentChallenges;
            challenges = openChallenges;
        };
        return #Ok(result);
    };

    // Function for user to get the score of a submission by one of their mAIners
    public query (msg) func getScoreForSubmission(submissionInput : Types.SubmissionRetrievalInput) : async Types.ScoredResponseRetrievalResult {
        // TODO - Security: put access checks in place
        /* if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        }; */

        let result : ?Types.ScoredResponse = getScoredResponse(submissionInput.challengeId, submissionInput.submissionId);
        switch (result) {
            case (null) {
                return #Err(#InvalidId);
            };
            case (?scoredResponse) {
                // TODO - Security: decide if only owner of mAIner should be allowed to retrieve this
                return #Ok(scoredResponse);
            };
        };
    };

    public query func getProtocolTotalCyclesBurnt() : async Types.CyclesBurntResult {
        return #Ok(TOTAL_PROTOCOL_CYCLES_BURNT);
    };

// Mockup functions (TODO - Testing: remove)
    // Function for frontend integration testing that returns mockup data
    public query (msg) func getScoreForSubmission_mockup(submissionInput : Types.SubmissionRetrievalInput) : async Types.ScoredResponseRetrievalResult {
        switch (getOpenChallenge(submissionInput.challengeId)) {
            case (?openChallenge) {
                let scoredResponseEntry : Types.ScoredResponse = {
                    challengeTopic : Text = openChallenge.challengeTopic;
                    challengeTopicId : Text = openChallenge.challengeTopicId;
                    challengeTopicCreationTimestamp : Nat64 = openChallenge.challengeTopicCreationTimestamp;
                    challengeTopicStatus : Types.ChallengeTopicStatus = openChallenge.challengeTopicStatus;
                    challengeQuestion : Text = openChallenge.challengeQuestion;
                    challengeQuestionSeed : Nat32 = openChallenge.challengeQuestionSeed;
                    challengeId : Text = openChallenge.challengeId;
                    challengeCreationTimestamp : Nat64 = openChallenge.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = openChallenge.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = openChallenge.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = openChallenge.challengeClosedTimestamp;
                    submissionCyclesRequired : Nat = openChallenge.submissionCyclesRequired;
                    challengeQueuedId : Text = submissionInput.submissionId;
                    challengeQueuedBy : Principal = msg.caller;
                    challengeQueuedTo : Principal = msg.caller;
                    challengeQueuedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                    challengeAnswer : Text = "";
                    challengeAnswerSeed : Nat32 = 0;
                    submittedBy : Principal = msg.caller;
                    submissionId : Text = submissionInput.submissionId;
                    submittedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                    submissionStatus: Types.ChallengeResponseSubmissionStatus = #Judged;
                    judgedBy: Principal = msg.caller;
                    score: Nat = 5;
                    scoreSeed: Nat32 = 0;
                    judgedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                };
                return #Ok(scoredResponseEntry);              
            };
            case (null) {
                switch (getClosedChallenge(submissionInput.challengeId)) {
                    case (?closedChallenge) {
                        let scoredResponseEntry : Types.ScoredResponse = {
                            challengeTopic : Text = closedChallenge.challengeTopic;
                            challengeTopicId : Text = closedChallenge.challengeTopicId;
                            challengeTopicCreationTimestamp : Nat64 = closedChallenge.challengeTopicCreationTimestamp;
                            challengeTopicStatus : Types.ChallengeTopicStatus = closedChallenge.challengeTopicStatus;
                            challengeQuestion : Text = closedChallenge.challengeQuestion;
                            challengeQuestionSeed : Nat32 = closedChallenge.challengeQuestionSeed;
                            challengeId : Text = closedChallenge.challengeId;
                            challengeCreationTimestamp : Nat64 = closedChallenge.challengeCreationTimestamp;
                            challengeCreatedBy : Types.CanisterAddress = closedChallenge.challengeCreatedBy;
                            challengeStatus : Types.ChallengeStatus = closedChallenge.challengeStatus;
                            challengeClosedTimestamp : ?Nat64 = closedChallenge.challengeClosedTimestamp;
                            submissionCyclesRequired : Nat = closedChallenge.submissionCyclesRequired;
                            challengeQueuedId : Text = submissionInput.submissionId;
                            challengeQueuedBy : Principal = msg.caller;
                            challengeQueuedTo : Principal = msg.caller;
                            challengeQueuedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                            challengeAnswer : Text = "";
                            challengeAnswerSeed : Nat32 = 0;
                            submittedBy : Principal = msg.caller;
                            submissionId : Text = submissionInput.submissionId;
                            submittedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                            submissionStatus: Types.ChallengeResponseSubmissionStatus = #Judged;
                            judgedBy: Principal = msg.caller;
                            score: Nat = 5;
                            scoreSeed: Nat32 = 0;
                            judgedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                        };
                        return #Ok(scoredResponseEntry);                       
                    };
                    case (null) {
                        let scoredResponseEntry : Types.ScoredResponse = {
                            challengeTopic : Text = "";
                            challengeTopicId : Text = "";
                            challengeTopicCreationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                            challengeTopicStatus : Types.ChallengeTopicStatus = #Archived;
                            challengeQuestion : Text = "";
                            challengeQuestionSeed : Nat32 = 0;
                            challengeId : Text = submissionInput.challengeId;
                            challengeCreationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                            challengeCreatedBy : Types.CanisterAddress = "";
                            challengeStatus : Types.ChallengeStatus = #Archived;
                            challengeClosedTimestamp : ?Nat64 = ?Nat64.fromNat(Int.abs(Time.now()));
                            submissionCyclesRequired : Nat = SUBMISSION_CYCLES_REQUIRED;
                            challengeQueuedId : Text = submissionInput.submissionId;
                            challengeQueuedBy : Principal = msg.caller;
                            challengeQueuedTo : Principal = msg.caller;
                            challengeQueuedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                            challengeAnswer : Text = "";
                            challengeAnswerSeed : Nat32 = 0;
                            submittedBy : Principal = msg.caller;
                            submissionId : Text = submissionInput.submissionId;
                            submittedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                            submissionStatus: Types.ChallengeResponseSubmissionStatus = #Judged;
                            judgedBy: Principal = msg.caller;
                            score: Nat = 5;
                            scoreSeed: Nat32 = 0;
                            judgedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                        };
                        return #Ok(scoredResponseEntry);                        
                    };
                };  
            };
        };
    };

    public query func getRecentProtocolActivity_mockup() : async Types.ProtocolActivityResult {
        let mainerAgents : [Types.OfficialProtocolCanister] = getMainerAgents();

        if (mainerAgents.size() > 0) {
            var winnerAgent = mainerAgents[0];
            var secondPlaceAgent = mainerAgents[0];
            var thirdPlaceAgent = mainerAgents[0];
            if (mainerAgents.size() > 1) {
                secondPlaceAgent := mainerAgents[1];
            } else if (mainerAgents.size() > 2) {
                secondPlaceAgent := mainerAgents[1];
                thirdPlaceAgent := mainerAgents[2];
            };
            var participantsList : List.List<Types.ChallengeParticipantEntry> = List.nil<Types.ChallengeParticipantEntry>();
            // Winner
            var rewardAmount : Nat = getRewardAmountForResult(#Winner, 3);
            let winnerReward : Types.ChallengeWinnerReward = {
                rewardType : Types.RewardType = DEFAULT_REWARD_PER_CHALLENGE.rewardType;
                amount : Nat = rewardAmount;
                rewardDetails : Text = "";
                distributed : Bool = false;
                distributedTimestamp : ?Nat64 = null;
            };
            let winnerParticipant : Types.ChallengeParticipantEntry = {
                submissionId : Text = "";
                submittedBy : Principal = Principal.fromText(winnerAgent.address);
                ownedBy: Principal = winnerAgent.ownedBy;
                result : Types.ChallengeParticipationResult = #Winner;
                reward : Types.ChallengeWinnerReward = winnerReward;
            };
            participantsList := List.push<Types.ChallengeParticipantEntry>(winnerParticipant, participantsList);
            
            // Second Place
            rewardAmount := getRewardAmountForResult(#SecondPlace, 3);
            let secondPlaceReward : Types.ChallengeWinnerReward = {
                rewardType : Types.RewardType = DEFAULT_REWARD_PER_CHALLENGE.rewardType;
                amount : Nat = rewardAmount;
                rewardDetails : Text = "";
                distributed : Bool = false;
                distributedTimestamp : ?Nat64 = null;
            };
            let secondPlaceParticipant : Types.ChallengeParticipantEntry = {
                submissionId : Text = "";
                submittedBy : Principal = Principal.fromText(secondPlaceAgent.address);
                ownedBy: Principal = secondPlaceAgent.ownedBy;
                result : Types.ChallengeParticipationResult = #SecondPlace;
                reward : Types.ChallengeWinnerReward = secondPlaceReward;
            };
            participantsList := List.push<Types.ChallengeParticipantEntry>(secondPlaceParticipant, participantsList);
            
            // Third Place
            rewardAmount := getRewardAmountForResult(#ThirdPlace, 3);
            let thirdPlaceReward : Types.ChallengeWinnerReward = {
                rewardType : Types.RewardType = DEFAULT_REWARD_PER_CHALLENGE.rewardType;
                amount : Nat = rewardAmount;
                rewardDetails : Text = "";
                distributed : Bool = false;
                distributedTimestamp : ?Nat64 = null;
            };
            let thirdPlaceParticipant : Types.ChallengeParticipantEntry = {
                submissionId : Text = "";
                submittedBy : Principal = Principal.fromText(thirdPlaceAgent.address);
                ownedBy: Principal = thirdPlaceAgent.ownedBy;
                result : Types.ChallengeParticipationResult = #ThirdPlace;
                reward : Types.ChallengeWinnerReward = thirdPlaceReward;
            };
            participantsList := List.push<Types.ChallengeParticipantEntry>(thirdPlaceParticipant, participantsList);
            
            let challengeWinnerDeclaration : Types.ChallengeWinnerDeclaration = {
                challengeId : Text = "";
                finalizedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                winner : Types.ChallengeParticipantEntry = winnerParticipant;
                secondPlace : Types.ChallengeParticipantEntry = secondPlaceParticipant;
                thirdPlace : Types.ChallengeParticipantEntry = thirdPlaceParticipant;
                participants : List.List<Types.ChallengeParticipantEntry> = participantsList;
            };
            let winnersForRecentChallenges : [Types.ChallengeWinnerDeclaration] = [challengeWinnerDeclaration];
            let openChallenges : [Types.Challenge] = getOpenChallenges();
            let result : Types.ProtocolActivityRecord = {
                winners = winnersForRecentChallenges;
                challenges = openChallenges;
            };
            return #Ok(result);
        } else {
            return #Err(#InvalidId);
        };
    };

// Upgrade Hooks (TODO - Implementation: upgrade Motoko to use enhanced orthogonal persistence)
    system func preupgrade() {
        challengerCanistersStorageStable := Iter.toArray(challengerCanistersStorage.entries());
        judgeCanistersStorageStable := Iter.toArray(judgeCanistersStorage.entries());
        mainerCreatorCanistersStorageStable := Iter.toArray(mainerCreatorCanistersStorage.entries());
        mainerAgentCanistersStorageStable := Iter.toArray(mainerAgentCanistersStorage.entries());
        userToMainerAgentsStorageStable := Iter.toArray(userToMainerAgentsStorage.entries());
        openChallengeTopicsStorageStable := Iter.toArray(openChallengeTopicsStorage.entries());
        openChallengesStorageStable := Iter.toArray(openChallengesStorage.entries());
        submissionsStorageStable := Iter.toArray(submissionsStorage.entries());
        scoredResponsesPerChallengeStable := Iter.toArray(scoredResponsesPerChallenge.entries());
        winnerDeclarationForChallengeStable := Iter.toArray(winnerDeclarationForChallenge.entries());
        sharedServiceCanistersStorageStable := Iter.toArray(sharedServiceCanistersStorage.entries());
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
        userToMainerAgentsStorage := HashMap.fromIter(Iter.fromArray(userToMainerAgentsStorageStable), userToMainerAgentsStorageStable.size(), Principal.equal, Principal.hash);
        userToMainerAgentsStorageStable := [];
        openChallengeTopicsStorage := HashMap.fromIter(Iter.fromArray(openChallengeTopicsStorageStable), openChallengeTopicsStorageStable.size(), Text.equal, Text.hash);
        openChallengeTopicsStorageStable := [];
        openChallengesStorage := HashMap.fromIter(Iter.fromArray(openChallengesStorageStable), openChallengesStorageStable.size(), Text.equal, Text.hash);
        openChallengesStorageStable := [];
        submissionsStorage := HashMap.fromIter(Iter.fromArray(submissionsStorageStable), submissionsStorageStable.size(), Text.equal, Text.hash);
        submissionsStorageStable := [];
        scoredResponsesPerChallenge := HashMap.fromIter(Iter.fromArray(scoredResponsesPerChallengeStable), scoredResponsesPerChallengeStable.size(), Text.equal, Text.hash);
        scoredResponsesPerChallengeStable := [];
        winnerDeclarationForChallenge := HashMap.fromIter(Iter.fromArray(winnerDeclarationForChallengeStable), winnerDeclarationForChallengeStable.size(), Text.equal, Text.hash);
        winnerDeclarationForChallengeStable := [];
        sharedServiceCanistersStorage := HashMap.fromIter(Iter.fromArray(sharedServiceCanistersStorageStable), sharedServiceCanistersStorageStable.size(), Text.equal, Text.hash);
        sharedServiceCanistersStorageStable := [];
    };
};
