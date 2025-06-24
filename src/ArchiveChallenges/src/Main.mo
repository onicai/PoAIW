import D "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import List "mo:base/List";
import Error "mo:base/Error";
import Hash "mo:base/Hash";
import Array "mo:base/Array";

import Types "../../common/Types";

actor class ArchiveChallengesCanister() = this {

    stable var MASTER_CANISTER_ID : Text = "be2us-64aaa-aaaaa-qaabq-cai"; // Corresponds to Game State canister

    public shared (msg) func setMasterCanisterId(_master_canister_id : Text) : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        MASTER_CANISTER_ID := _master_canister_id;
        let authRecord = { auth = "You set the master canister for this canister." };
        return #Ok(authRecord);
    };

    public query (msg) func getMasterCanisterId() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = { auth = "Master canister id for this canister: " # MASTER_CANISTER_ID };
        return #Ok(authRecord);
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

    public shared (msg) func addChallenges(migrationInput : Types.ChallengeMigrationInput) : async Types.ChallengeMigrationResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (Principal.isController(msg.caller) or Principal.equal(msg.caller, Principal.fromText(MASTER_CANISTER_ID))) {
            let result = addArchivedChallenges(List.fromArray<Types.Challenge>(migrationInput.challenges));
            switch (result) {
                case (true) {
                    return #Ok({migrated = true});            
                };
                case (false) {
                    D.print("Archive Challenges: addChallenges - addArchivedChallenges return false");
                    return #Err(#FailedOperation);
                };
                case (_) { return #Err(#FailedOperation); }
            };
        } else {
            return #Err(#Unauthorized);
        };
    };

    public query (msg) func getChallenges() : async Types.ChallengesResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (Principal.isController(msg.caller)) {
            let result = getArchivedChallenges();
            return #Ok(result);
        } else {
            return #Err(#Unauthorized);
        };
    };

    public query (msg) func getNumChallenges() : async Types.NatResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (Principal.isController(msg.caller)) {
            let result = getArchivedChallenges();
            return #Ok(result.size());
        } else {
            return #Err(#Unauthorized);
        };
    };

    // mAIners backup
    stable var mainerAgentCanisters : List.List<(Text, Types.OfficialMainerAgentCanister)> = List.nil<(Text, Types.OfficialMainerAgentCanister)>();
    
    private func putMainer(entry : (Text, Types.OfficialMainerAgentCanister)) : Bool {
        mainerAgentCanisters := List.push<(Text, Types.OfficialMainerAgentCanister)>(entry, mainerAgentCanisters);
        return true;
    };

    private func getMainers() : [(Text, Types.OfficialMainerAgentCanister)] {
        return List.toArray<(Text, Types.OfficialMainerAgentCanister)>(mainerAgentCanisters);
    };

    private func addMainers(mainersToAdd : List.List<(Text, Types.OfficialMainerAgentCanister)>) : Bool {
        mainerAgentCanisters := List.append<(Text, Types.OfficialMainerAgentCanister)>(mainersToAdd, mainerAgentCanisters);
        return true;
    };

    public shared (msg) func addMainersAdmin(backupInput : Types.MainerBackupInput) : async Types.MainerBackupResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (Principal.isController(msg.caller) or Principal.equal(msg.caller, Principal.fromText(MASTER_CANISTER_ID))) {
            let result = addMainers(List.fromArray<(Text, Types.OfficialMainerAgentCanister)>(backupInput.mainers));
            switch (result) {
                case (true) {
                    return #Ok({backedUp = true});            
                };
                case (false) {
                    D.print("Archive Challenges: addMainersAdmin - addMainers return false");
                    return #Err(#FailedOperation);
                };
                case (_) { return #Err(#FailedOperation); }
            };
        } else {
            return #Err(#Unauthorized);
        };
    };

    public query (msg) func getMainersAdmin() : async Types.MainersResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (Principal.isController(msg.caller)) {
            let result = getMainers();
            return #Ok(result);
        } else {
            return #Err(#Unauthorized);
        };
    };

    public query (msg) func getNumMainersAdmin() : async Types.NatResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (Principal.isController(msg.caller)) {
            let result = getMainers();
            return #Ok(result.size());
        } else {
            return #Err(#Unauthorized);
        };
    };
};