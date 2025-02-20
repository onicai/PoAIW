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

import Types "./Types";
import Utils "Utils";

actor class GameStateCanister() = this {

    // Function to verify that canister is up & running
    public shared query func health() : async Types.StatusCodeRecordResult {
        return #Ok({ status_code = 200 });
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
    stable let _CYCLES_TRILLION = 1_000_000_000_000;
    // TODO: Keep in sync with SUBMISSION_CYCLES_REQUIRED in mAIner
    stable let SUBMISSION_CYCLES_REQUIRED : Nat = 100 * CYCLES_BILLION; // TODO: determine how many cycles are needed to process one submission (incl. judge)
    
    stable let FAILED_SUBMISSION_CYCLES_CUT : Nat = SUBMISSION_CYCLES_REQUIRED / 5;
    stable let _JUDGE_CYCLES_PROVISION_PER_SUBMISSION : Nat = 80 * CYCLES_BILLION; // TODO: determine how many cycles should be forwarded to judge per submission

    stable var CYCLES_BURNT_CHALLENGE_CREATION : Nat = 50 * CYCLES_BILLION;
    stable var CYCLES_BURNT_RESPONSE_GENERATION : Nat = 50 * CYCLES_BILLION;
    stable var CYCLES_BURNT_JUDGE_SCORING : Nat = 50 * CYCLES_BILLION;

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

    private func getNextMainerCreatorCanisterEntry() : ?Types.OfficialProtocolCanister {
        return mainerCreatorCanistersStorage.vals().next();
    };

    // mAIner Registry: Official mAIner agent canisters (owned by users)
    stable var mainerAgentCanistersStorageStable : [(Text, Types.OfficialProtocolCanister)] = [];
    var mainerAgentCanistersStorage : HashMap.HashMap<Text, Types.OfficialProtocolCanister> = HashMap.HashMap(0, Text.equal, Text.hash);
    stable var userToMainerAgentsStorageStable : [(Principal, List.List<Types.OfficialProtocolCanister>)] = [];
    var userToMainerAgentsStorage : HashMap.HashMap<Principal, List.List<Types.OfficialProtocolCanister>> = HashMap.HashMap(0, Principal.equal, Principal.hash);

    private func putMainerAgentCanister(canisterAddress : Text, canisterEntry : Types.OfficialProtocolCanister) : Types.MainerAgentCanisterResult {
        switch (getMainerAgentCanister(canisterAddress)) {
            case (null) {
                mainerAgentCanistersStorage.put(canisterAddress, canisterEntry);
                switch (putUserMainerAgent(canisterEntry)) {
                    case (false) {
                        return #Err(#Other("Error in putUserMainerAgent"));
                    };
                    case (true) {
                        return #Ok(canisterEntry);
                    };
                };
            };
            case (?canisterEntry) { 
                //existing entry
                D.print("GameState: putMainerAgentCanister - canisterEntry already exists -" # debug_show(canisterEntry));
                return #Err(#Other("Canister entry already exists"));
            }; 
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
                // TODO: remove from userToMainerAgentsStorage
                return true;
            };
        };
    };

    private func putUserMainerAgent(canisterEntry : Types.OfficialProtocolCanister) : Bool {
        switch (getUserMainerAgents(canisterEntry.ownedBy)) {
            case (null) {
                // first entry
                let userCanistersList : List.List<Types.OfficialProtocolCanister> = List.make<Types.OfficialProtocolCanister>(canisterEntry);
                userToMainerAgentsStorage.put(canisterEntry.ownedBy, userCanistersList);
                return true;
            };
            case (?userCanistersList) { 
                //existing list, add entry to it
                let updatedUserCanistersList : List.List<Types.OfficialProtocolCanister> = List.push<Types.OfficialProtocolCanister>(canisterEntry, userCanistersList);
                userToMainerAgentsStorage.put(canisterEntry.ownedBy, updatedUserCanistersList);
                return true;
            }; 
        };
    };

    private func getUserMainerAgents(userId : Principal) : ?List.List<Types.OfficialProtocolCanister> {
        switch (userToMainerAgentsStorage.get(userId)) {
            case (null) { return null; };
            case (?userCanistersList) { return ?userCanistersList; };
        };
    };

    private func removeUserMainerAgent(canisterEntry : Types.OfficialProtocolCanister) : Bool {
        switch (getUserMainerAgents(canisterEntry.ownedBy)) {
            case (null) { return false; };
            case (?userCanistersList) { 
                //existing list, remove entry from it
                let updatedUserCanistersList : List.List<Types.OfficialProtocolCanister> = List.filter(userCanistersList, func(listEntry: Types.OfficialProtocolCanister) : Bool { listEntry.address != canisterEntry.address });
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

    stable var THRESHOLD_ARCHIVE_CLOSED_CHALLENGES : Nat = 30;

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

    private func removeSubmission(submissionId : Text) : Bool {
        switch (submissionsStorage.get(submissionId)) {
            case (null) { return false; };
            case (?submissionEntry) {
                let removeResult = submissionsStorage.remove(submissionId);
                return true;
            };
        };
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

    // Admin function to get all scored responses
    public shared query (msg) func getScoredChallengesAdmin() : async Types.ScoredChallengesResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let scoredChallengesArray : [(Text, List.List<Types.ScoredResponse>)] = Iter.toArray(scoredResponsesPerChallenge.entries());

        return #Ok(scoredChallengesArray);
    };

    // TODO: determine exact reward
    stable var REWARD_PER_CHALLENGE = {
        rewardType : Types.RewardType = #MainerToken;
        totalAmount : Nat = 100;
        winnerAmount : Nat = 35;
        secondPlaceAmount : Nat = 15;
        thirdPlaceAmount : Nat = 5;
        amountForAllParticipants : Nat = 45;
    };

    private func getRewardAmountForResult(achievedResult : Types.ChallengeParticipationResult, totalNumberParticipants : Nat) : Nat { 
        let participationReward = REWARD_PER_CHALLENGE.amountForAllParticipants / totalNumberParticipants;
        switch (achievedResult) {
            case (#Winner) { return REWARD_PER_CHALLENGE.winnerAmount + participationReward; };
            case (#SecondPlace) { return REWARD_PER_CHALLENGE.secondPlaceAmount + participationReward; };
            case (#ThirdPlace) { return REWARD_PER_CHALLENGE.thirdPlaceAmount + participationReward; };
            case (#Participated) { return participationReward; };
            case (_) { return 0; };
        };
    };

    private func getRewardForChallengeParticipant(challengeId : Text, achievedResult : Types.ChallengeParticipationResult, totalNumberParticipants : Nat) : Types.ChallengeWinnerReward { 
        var rewardAmount : Nat = getRewardAmountForResult(achievedResult, totalNumberParticipants);
        
        let participantReward : Types.ChallengeWinnerReward = {
            rewardType : Types.RewardType = REWARD_PER_CHALLENGE.rewardType;
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

    // Admin function to get the official protocol canisters
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

    // Function for Admin to retrieve current challenges
    public shared query (msg) func getCurrentChallengesAdmin() : async Types.ChallengesResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let challenges : [Types.Challenge] = getOpenChallenges();
        return #Ok(challenges);
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
        // TODO: require cycles for adding new challenge
        ignore increaseTotalProtocolCyclesBurnt(CYCLES_BURNT_CHALLENGE_CREATION);

        // Only official Challenger canisters may call this
        switch (getChallengerCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?challengerEntry) {
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

    // Function for user to create a new mAIner agent canister
    public shared (msg) func createUserMainerAgentCanister(mainerConfig : Types.MainerConfigurationInput) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // TODO: verify user's payment for this agent

        // Sanity checks on configuration of mAIner agent canister
        switch (mainerConfig.aiModel) {
            case (null) {
                // use default model
            };
            case (?#Qwen2_5_0_5_B) {
                // continue
            };
            case (_) { return #Err(#Other("Unsupported")); }
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
                    canisterType : Types.ProtocolCanisterType = #MainerAgent;
                    owner: Principal = msg.caller; // User
                };
                let result : Types.CanisterCreationResult = await creatorCanisterActor.createCanister(canisterCreationInput);
                switch (result) {
                    case (#Ok(canisterCreationRecord)) {
                        let canisterEntry : Types.OfficialProtocolCanister = {
                            address : Text = canisterCreationRecord.newCanisterId; // New canister's id
                            canisterType: Types.ProtocolCanisterType = #MainerAgent;
                            creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                            createdBy : Principal = msg.caller; // mAIner Creator
                            ownedBy : Principal = msg.caller; // User
                        };
                        putMainerAgentCanister(canisterCreationRecord.newCanisterId, canisterEntry);                        
                    };
                    case (_) { return #Err(#FailedOperation); };
                };            
            };
        };
    };

    // Function for mAIner Agent Creator canister to add new mAIner agent for user
    public shared (msg) func addMainerAgentCanister(canisterEntryToAdd : Types.MainerAgentCanisterInput) : async Types.MainerAgentCanisterResult {
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
                putMainerAgentCanister(canisterEntryToAdd.address, canisterEntry);           
            };
        };
    };

    // TODO: remove; admin Function to add new mAIner agent for testing
    public shared (msg) func addMainerAgentCanisterAdmin(canisterEntryToAdd : Types.MainerAgentCanisterInput) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (canisterEntryToAdd.canisterType) {
            case (#MainerAgent) {
                // continue
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };
        let canisterEntry : Types.OfficialProtocolCanister = {
            address : Text = canisterEntryToAdd.address;
            canisterType: Types.ProtocolCanisterType = canisterEntryToAdd.canisterType;
            creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            createdBy : Principal = msg.caller;
            ownedBy : Principal = canisterEntryToAdd.ownedBy;
        }; 
        putMainerAgentCanister(canisterEntryToAdd.address, canisterEntry); 
    };

    // Function for user to get their mAIner agent canisters
    public shared query (msg) func getMainerAgentCanistersForUser() : async Types.MainerAgentCanistersResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // Only official Challenger canisters may call this
        switch (getUserMainerAgents(msg.caller)) {
            case (null) { return #Err(#Other("No canisters for this caller")); };
            case (?userCanistersList) {
                return #Ok(List.toArray<Types.OfficialProtocolCanister>(userCanistersList));                              
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
        // TODO: adapt cycles burnt stats
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

    // Function for Admin to retrieve submissions
    public shared query (msg) func getSubmissionsAdmin() : async Types.ChallengeResponseSubmissionsResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let submissions : [Types.ChallengeResponseSubmission] = getSubmissions();
        return #Ok(submissions);
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

    // Function for Judge canister to add a new scored response
    stable let THRESHOLD_SCORED_RESPONSES_PER_CHALLENGE = 20; // TODO: determine threshold how many scored responses are needed before challenge is closed (for ranking and winner declaration)
    
    public shared (msg) func addScoredResponse(scoredResponseInput : Types.ScoredResponseInput) : async Types.ScoredResponseResult {
        D.print("GameState: addScoredResponse - entered");
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // TODO: adapt cycles burnt stats
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
                // TODO: likely we want to store the submissions from the mAIners and check here that it was an actual submission and that the data matches up

                // Verify that challenge is open
                if (not verifyChallenge(#Open, scoredResponseInput.challengeId)) {
                    // TODO: likely we want to store the scored response nevertheless for the closed challenge
                    D.print("GameState: addScoredResponse - 03");
                    return #Err(#InvalidId);
                };

                // TODO: do we really need a separate storage for submissions & scored submissions?
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

                // Determine if ranking of scored responses can be triggered
                if (numberOfScoredResponsesForChallenge >= THRESHOLD_SCORED_RESPONSES_PER_CHALLENGE) {
                    // Close challenge
                    switch (closeChallenge(scoredResponseInput.challengeId)) {
                        case (false) {
                            // TODO: error handling (e.g. put into queue and try ranking again later)
                        };
                        case (true) {
                            // Rank scored responses and declare winner
                            let rankResult : ?Types.ChallengeWinnerDeclaration = rankScoredResponsesForChallenge(scoredResponseInput.challengeId);
                            switch (rankResult) {
                                case (null) {
                                    // TODO: error handling (e.g. put into queue and try ranking again later)
                                };
                                case (?challengeWinnerDeclaration) {
                                    // TODO: Pay reward
                                    
                                };
                            };
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

    // Function to get recent protocol activity
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
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let result : ?Types.ScoredResponse = getScoredResponse(submissionInput.challengeId, submissionInput.submissionId);
        switch (result) {
            case (null) {
                return #Err(#InvalidId);
            };
            case (?scoredResponse) {
                // TODO: decide if only owner of mAIner should be allowed to retrieve this
                return #Ok(scoredResponse);
            };
        };
    };

    public query func getProtocolTotalCyclesBurnt() : async Types.CyclesBurntResult {
        return #Ok(TOTAL_PROTOCOL_CYCLES_BURNT);
    };

// Upgrade Hooks
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
    };
};
