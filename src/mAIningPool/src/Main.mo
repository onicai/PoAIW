import D "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import List "mo:base/List";
import Error "mo:base/Error";
import Hash "mo:base/Hash";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Option "mo:base/Option";

import Types "../../common/Types";
import Constants "../../common/Constants";

import CMC "../../common/cycles-minting-canister-interface";
import TokenLedger "../../common/icp-ledger-interface";

persistent actor class MainingPoolCanister() = this {

    var GAME_STATE_CANISTER_ID : Text = "r5m5y-diaaa-aaaaa-qanaa-cai"; // Corresponds to prd Game State canister

    public shared (msg) func setGameStateCanisterId(_game_state_canister_id : Text) : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        GAME_STATE_CANISTER_ID := _game_state_canister_id;
        let authRecord = { auth = "You set the game state canister for this canister." };
        return #Ok(authRecord);
    };

    public query (msg) func getGameStateCanisterId() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = { auth = "Game state canister id for this canister: " # GAME_STATE_CANISTER_ID };
        return #Ok(authRecord);
    };

    transient let CMC_ACTOR : CMC.CYCLES_MINTING_CANISTER = Types.CyclesMintingCanister_Actor;

    transient let ICP_LEDGER_ACTOR : TokenLedger.TOKEN_LEDGER = Types.IcpLedger_Actor;

    var TOKEN_LEDGER_CANISTER_ID : Text = "vpyot-zqaaa-aaaaa-qavaq-cai";

    transient let TokenLedger_Actor : TokenLedger.TOKEN_LEDGER = actor (TOKEN_LEDGER_CANISTER_ID);

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
    // Pool Configuration Constants
    
    private let MIN_ICP_CONTRIBUTION_E8S : Nat = 100_000_000; // 1 ICP minimum
    private let MAX_ICP_CONTRIBUTION_E8S : Nat = 10_000_000_000; // 100 ICP maximum
    private let TREASURY_FEE_PERCENTAGE : Nat = 10; // 10% fee for treasury
    
    // Week boundaries in nanoseconds (Sunday end of day is commitment deadline)
    // Using Monday 00:00:00 UTC as start of mAIning week
    
    // -------------------------------------------------------------------------------
    // Data Structures specific to mAIning Pool
    
    // Pool participant contribution record
    type PoolParticipantEntry = {
        principal : Principal;
        icpContributionE8S : Nat;
        funnaiDistributionE8S : Nat;
        joinTimestamp : Nat64;
        distributionTimestamp : Nat64;
    };
    
    // User history record
    type UserHistoryEntry = {
        poolCycleId : Nat;
        poolCycleStartTimestamp : Nat64;
        poolCycleEndTimestamp : Nat64;
        poolParticipantEntry : PoolParticipantEntry;
    };
    
    // Pool cycle record
    type PoolCycleRecord = {
        poolCycleId : Nat;
        poolCycleStartTimestamp : Nat64;
        poolCycleEndTimestamp : Nat64;
        totalIcpContributedE8S : Nat;
        totalFunnaiDistributedE8S : Nat;
        participantCount : Nat;
    };
    
    // mAIner owned by pool
    type PoolMainerEntry = Types.OfficialMainerAgentCanister;
    
    // -------------------------------------------------------------------------------
    // Storage Variables
    
    // Current pool cycle ID
    var currentCycleId : Nat = 0;
    
    // Current pool cycle timestamps
    var currentCycleStartTimestamp : Nat64 = 0;
    var currentCycleEndTimestamp : Nat64 = 0;
    
    // mAIners owned by the pool
    var poolMainersStorageStable : [(Text, PoolMainerEntry)] = [];
    transient var poolMainersStorage : HashMap.HashMap<Text, PoolMainerEntry> = HashMap.HashMap(0, Text.equal, Text.hash);
    
    // Current pool participants (active mAIning cycle)
    var currentPoolParticipantsStable : [(Principal, PoolParticipantEntry)] = [];
    transient var currentPoolParticipants : HashMap.HashMap<Principal, PoolParticipantEntry> = HashMap.HashMap(0, Principal.equal, Principal.hash);
    
    // Next pool participants (commitments for next mAIning cycle)
    var nextPoolParticipantsStable : [(Principal, PoolParticipantEntry)] = [];
    transient var nextPoolParticipants : HashMap.HashMap<Principal, PoolParticipantEntry> = HashMap.HashMap(0, Principal.equal, Principal.hash);
    
    // Archive of past pool mAIning cycles
    var archivedPoolCyclesStable : [(Nat, PoolCycleRecord)] = [];
    transient var archivedPoolCycles : HashMap.HashMap<Nat, PoolCycleRecord> = HashMap.HashMap(0, Nat.equal, Hash.hash);
    
    // Archive of past participants per mAIning cycle
    var archivedParticipantsStable : [(Nat, [(Principal, PoolParticipantEntry)])] = [];
    transient var archivedParticipants : HashMap.HashMap<Nat, [(Principal, PoolParticipantEntry)]> = HashMap.HashMap(0, Nat.equal, Hash.hash);
    
    // User history mapping (Principal -> list of history entries)
    var userHistoryStable : [(Principal, [UserHistoryEntry])] = [];
    transient var userHistory : HashMap.HashMap<Principal, Buffer.Buffer<UserHistoryEntry>> = HashMap.HashMap(0, Principal.equal, Principal.hash);
    
    // Balance tracking
    var poolIcpBalanceE8S : Nat = 0;
    var poolFunnaiBalanceE8S : Nat = 0;
    
    // Counters
    var totalParticipantsAllTime : Nat = 0;
    
    // -------------------------------------------------------------------------------
    // Helper Functions
    
    // Calculate cycles from ICP using CMC conversion rate (accounting for treasury fee)
    private func calculateCyclesFromIcp(icpE8S : Nat) : async Nat {        
        // Query the CMC for the current conversion rate
        let queryResult = await CMC_ACTOR.get_icp_xdr_conversion_rate();
        
        // Extract the conversion rate
        let xdrPermyriadPerIcp = queryResult.data.xdr_permyriad_per_icp;
        
        // Constants
        let CYCLES_PER_XDR : Nat = 1_000_000_000_000; // 1 trillion cycles per XDR
        let E8S_PER_ICP : Nat = 100_000_000; // 10^8 e8s per ICP
        
        // Calculate total cycles from ICP
        let totalCycles : Nat = (icpE8S * Nat64.toNat(xdrPermyriadPerIcp) * CYCLES_PER_XDR) / (10_000 * E8S_PER_ICP);
        
        // Apply treasury fee
        let treasuryFee = (totalCycles * TREASURY_FEE_PERCENTAGE) / 100;
        totalCycles - treasuryFee
    };
    
    // Get current timestamp in seconds
    private func getCurrentTimestamp() : Nat64 {
        let now = Time.now();
        Nat64.fromNat(Int.abs(now) / 1_000_000_000)
    };
    
    // Check if we're in commitment phase (before Monday start)
    private func isInCommitmentPhase() : Bool {
        let now = getCurrentTimestamp();
        // Commitment phase is until Sunday end of day (before current cycle ends)
        now < currentCycleEndTimestamp
    };
    
    // Calculate cycles per mAIner based on total cycles and number of mAIners
    private func calculateCyclesPerMainer(totalCycles : Nat, mainerCount : Nat) : Nat {
        if (mainerCount == 0) { return 0 };
        totalCycles / mainerCount
    };
    
    // Calculate burn rate for a mAIner for one week
    var cyclesBurnRateDefaultLow : Types.CyclesBurnRate = {
        cycles : Nat = 1 * Constants.CYCLES_TRILLION;
        timeInterval : Types.TimeInterval = #Daily;
    };
    var cyclesBurnRateDefaultMid : Types.CyclesBurnRate = {
        cycles : Nat = 2 * Constants.CYCLES_TRILLION;
        timeInterval : Types.TimeInterval = #Daily;
    };
    var cyclesBurnRateDefaultHigh : Types.CyclesBurnRate = {
        cycles : Nat = 4 * Constants.CYCLES_TRILLION;
        timeInterval : Types.TimeInterval = #Daily;
    };
    var cyclesBurnRateDefaultVeryHigh : Types.CyclesBurnRate = {
        cycles : Nat = 6 * Constants.CYCLES_TRILLION;
        timeInterval : Types.TimeInterval = #Daily;
    };

    // Determine the CyclesBurnRateDefault tier based on cycles allocated for the week
    private func determineBurnRateTier(cyclesForWeek : Nat) : Types.CyclesBurnRateDefault {
        if (cyclesForWeek <= 7 * cyclesBurnRateDefaultLow.cycles) {
            return #Low;
        } else if (cyclesForWeek <= 7 * cyclesBurnRateDefaultMid.cycles) {
            return #Mid;
        } else if (cyclesForWeek <= 7 * cyclesBurnRateDefaultHigh.cycles) {
            return #High;
        } else {
            return #VeryHigh;
        };
    };
    
    // Distribute FUNNAI rewards to participants based on their ICP contribution
    private func calculateFunnaiDistribution(userContribution : Nat, totalContributions : Nat, totalFunnaiRewards : Nat) : Nat {
        if (totalContributions == 0) { return 0 };
        (userContribution * totalFunnaiRewards) / totalContributions
    };

    // Helper function to get actual FUNNAI balance from ledger
    private func getFunnaiBalance() : async Nat {
        let funnaiAccount : TokenLedger.Account = {
            owner = Principal.fromActor(this);
            subaccount = null;
        };
        let actualFunnaiBalance = await TokenLedger_Actor.icrc1_balance_of(funnaiAccount);
        D.print("MiningPool: getFunnaiBalance - FUNNAI balance: " # debug_show(actualFunnaiBalance));
        return actualFunnaiBalance;
    };

    // Helper function to get actual ICP balance from ledger
    private func getIcpBalance() : async Nat {
        let icpAccount : TokenLedger.Account = {
            owner = Principal.fromActor(this);
            subaccount = null;
        };
        let actualIcpBalance = await ICP_LEDGER_ACTOR.icrc1_balance_of(icpAccount);
        D.print("MiningPool: getIcpBalance - ICP balance: " # debug_show(actualIcpBalance));
        return actualIcpBalance;
    };
    
    // Helper function to top up a mAIner with cycles via Game State
    private func topUpMainerWithCycles(mainerEntry : PoolMainerEntry, icpAmountE8S : Nat) : async Types.TextResult {
        D.print("MiningPool: topUpMainerWithCycles - mainerEntry: " # debug_show(mainerEntry));
        D.print("MiningPool: topUpMainerWithCycles - icpAmountE8S: " # debug_show(icpAmountE8S));
        
        // Step 1: Transfer ICP to Game State canister
        let gameStatePrincipal = Principal.fromText(GAME_STATE_CANISTER_ID);
        let icpFee : Nat = 10_000; // 0.0001 ICP fee
        
        let transferArgs : TokenLedger.TransferArg = {
            from_subaccount = null;
            to = {
                owner = gameStatePrincipal;
                subaccount = null;
            };
            amount = icpAmountE8S;
            fee = ?icpFee;
            memo = null;
            created_at_time = null;
        };
        
        D.print("MiningPool: topUpMainerWithCycles - transferArgs: " # debug_show(transferArgs));
        
        try {
            let transferResult = await ICP_LEDGER_ACTOR.icrc1_transfer(transferArgs);
            D.print("MiningPool: topUpMainerWithCycles - transferResult: " # debug_show(transferResult));
            
            switch (transferResult) {
                case (#Err(err)) {
                    D.print("MiningPool: topUpMainerWithCycles - ICP transfer failed: " # debug_show(err));
                    return #Err(#Other("ICP transfer to Game State failed: " # debug_show(err)));
                };
                case (#Ok(blockIndex)) {
                    D.print("MiningPool: topUpMainerWithCycles - ICP transfer successful, block: " # debug_show(blockIndex));
                    
                    // Step 2: Call topUpCyclesForMainerAgent on Game State
                    let gameStateCanisterActor = actor (GAME_STATE_CANISTER_ID) : Types.GameStateCanister_Actor;
                    
                    let topUpInput : Types.MainerAgentTopUpInput = {
                        paymentTransactionBlockId = Nat64.fromNat(blockIndex);
                        mainerAgent = mainerEntry;
                    };
                    
                    D.print("MiningPool: topUpMainerWithCycles - topUpInput: " # debug_show(topUpInput));
                    
                    let topUpResult = await gameStateCanisterActor.topUpCyclesForMainerAgent(topUpInput);
                    D.print("MiningPool: topUpMainerWithCycles - topUpResult: " # debug_show(topUpResult));
                    
                    switch (topUpResult) {
                        case (#Err(err)) {
                            D.print("MiningPool: topUpMainerWithCycles - Top up failed: " # debug_show(err));
                            return #Err(#Other("Top up failed: " # debug_show(err)));
                        };
                        case (#Ok(results)) {
                            D.print("MiningPool: topUpMainerWithCycles - Top up successful");
                            return #Ok("Topped up mAIner " # mainerEntry.address # " successfully");
                        };
                    };
                };
            };
        } catch (e) {
            D.print("MiningPool: topUpMainerWithCycles - Exception: " # Error.message(e));
            return #Err(#Other("Exception during top up: " # Error.message(e)));
        };
    };
    
    // -------------------------------------------------------------------------------
    // Pool Participant Functions
    
    // Contribute to next pool
    public shared (msg) func contributeToNextPool(icpAmountE8S : Nat) : async Types.NatResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        
        // Check minimum and maximum contribution
        if (icpAmountE8S < MIN_ICP_CONTRIBUTION_E8S) {
            return #Err(#Other("Contribution below minimum of " # Nat.toText(MIN_ICP_CONTRIBUTION_E8S / 100_000_000) # " ICP"));
        };
        
        if (icpAmountE8S > MAX_ICP_CONTRIBUTION_E8S) {
            return #Err(#Other("Contribution exceeds maximum of " # Nat.toText(MAX_ICP_CONTRIBUTION_E8S / 100_000_000) # " ICP"));
        };
        
        // Retrieve approved ICP from contributor using icrc2_transfer_from
        let icpFee : Nat = 10_000; // 0.0001 ICP fee
        let transferFromArgs : TokenLedger.TransferFromArgs = {
            from = { owner = msg.caller; subaccount = null };
            to = { owner = Principal.fromActor(this); subaccount = null };
            amount = icpAmountE8S;
            fee = ?icpFee;
            memo = null;
            created_at_time = null;
            spender_subaccount = null;
        };

        try {
            let icpTransferResult : TokenLedger.Result_3 = await ICP_LEDGER_ACTOR.icrc2_transfer_from(transferFromArgs);
            D.print("MiningPool: contributeToNextPool - icpTransferResult: " # debug_show(icpTransferResult));
            switch (icpTransferResult) {
                case (#Err(transferError)) {
                    D.print("MiningPool: contributeToNextPool - ICP transfer failed: " # debug_show(transferError));
                    return #Err(#Other("ICP payment transfer failed: " # debug_show(transferError)));
                };
                case (#Ok(icpBlockIndex)) {
                    D.print("MiningPool: contributeToNextPool - ICP transferred successfully, block: " # debug_show(icpBlockIndex));
                    // Continue with contribution processing
                };
            };
        } catch (e) {
            D.print("MiningPool: contributeToNextPool - Failed icrc2_transfer_from: " # Error.message(e));
            return #Err(#Other("Failed icrc2_transfer_from: " # Error.message(e)));
        };
        
        // Check if user already has an entry for next pool
        switch (nextPoolParticipants.get(msg.caller)) {
            case (?existingEntry) {
                // User already has a commitment, add to it
                let updatedEntry : PoolParticipantEntry = {
                    principal = existingEntry.principal;
                    icpContributionE8S = existingEntry.icpContributionE8S + icpAmountE8S;
                    funnaiDistributionE8S = existingEntry.funnaiDistributionE8S;
                    joinTimestamp = existingEntry.joinTimestamp;
                    distributionTimestamp = existingEntry.distributionTimestamp;
                };
                nextPoolParticipants.put(msg.caller, updatedEntry);
                
                // Update pool ICP balance
                poolIcpBalanceE8S := poolIcpBalanceE8S + icpAmountE8S;
                
                return #Ok(updatedEntry.icpContributionE8S);
            };
            case null {
                // New entry for next pool
                let newEntry : PoolParticipantEntry = {
                    principal = msg.caller;
                    icpContributionE8S = icpAmountE8S;
                    funnaiDistributionE8S = 0;
                    joinTimestamp = getCurrentTimestamp();
                    distributionTimestamp = 0;
                };
                nextPoolParticipants.put(msg.caller, newEntry);
                
                // Update pool ICP balance
                poolIcpBalanceE8S := poolIcpBalanceE8S + icpAmountE8S;
                
                // Track total participants
                totalParticipantsAllTime := totalParticipantsAllTime + 1;
                
                return #Ok(newEntry.icpContributionE8S);
            };
        };
    };
    
    // Query: Get my contribution for current pool
    public shared query (msg) func getMyCurrentPoolContribution() : async Types.NatResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        
        switch (currentPoolParticipants.get(msg.caller)) {
            case (?entry) {
                return #Ok(entry.icpContributionE8S);
            };
            case null {
                return #Ok(0);
            };
        };
    };
    
    // Query: Get my contribution for next pool
    public shared query (msg) func getMyNextPoolContribution() : async Types.NatResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        
        switch (nextPoolParticipants.get(msg.caller)) {
            case (?entry) {
                return #Ok(entry.icpContributionE8S);
            };
            case null {
                return #Ok(0);
            };
        };
    };
    
    // Query: Get my past contributions and distributions
    public shared query (msg) func getMyHistory() : async Types.Result<[UserHistoryEntry], Types.ApiError> {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        
        switch (userHistory.get(msg.caller)) {
            case (?historyBuffer) {
                return #Ok(Buffer.toArray(historyBuffer));
            };
            case null {
                return #Ok([]);
            };
        };
    };
    
    // Query: Get current pool statistics
    public shared query func getCurrentPoolStats() : async Types.Result<{
        cycleId : Nat;
        startTimestamp : Nat64;
        endTimestamp : Nat64;
        participantCount : Nat;
        totalIcpContributedE8S : Nat;
        totalFunnaiRewardsAccumulated : Nat;
    }, Types.ApiError> {
        let participantCount = currentPoolParticipants.size();
        var totalIcp : Nat = 0;
        
        for ((_, entry) in currentPoolParticipants.entries()) {
            totalIcp := totalIcp + entry.icpContributionE8S;
        };
        
        return #Ok({
            cycleId = currentCycleId;
            startTimestamp = currentCycleStartTimestamp;
            endTimestamp = currentCycleEndTimestamp;
            participantCount = participantCount;
            totalIcpContributedE8S = totalIcp;
            totalFunnaiRewardsAccumulated = poolFunnaiBalanceE8S;
        });
    };
    
    // Query: Get next pool statistics
    public shared query func getNextPoolStats() : async Types.Result<{
        cycleId : Nat;
        participantCount : Nat;
        totalIcpCommittedE8S : Nat;
        commitmentDeadline : Nat64;
    }, Types.ApiError> {
        let participantCount = nextPoolParticipants.size();
        var totalIcp : Nat = 0;
        
        for ((_, entry) in nextPoolParticipants.entries()) {
            totalIcp := totalIcp + entry.icpContributionE8S;
        };
        
        return #Ok({
            cycleId = currentCycleId + 1;
            participantCount = participantCount;
            totalIcpCommittedE8S = totalIcp;
            commitmentDeadline = currentCycleEndTimestamp;
        });
    };
    
    // -------------------------------------------------------------------------------
    // Admin Functions
    
    // Start next pool cycle - this distributes rewards and sets up the new cycle
    public shared (msg) func startNextPoolCycle(weekStartTimestamp : Nat64, weekEndTimestamp : Nat64) : async Types.TextResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        
        // Step 1: Distribute FUNNAI rewards to current pool participants
        var totalCurrentIcp : Nat = 0;
        for ((_, entry) in currentPoolParticipants.entries()) {
            totalCurrentIcp := totalCurrentIcp + entry.icpContributionE8S;
        };
        
        // Get actual FUNNAI balance from ledger
        var totalFunnaiToDistribute = poolFunnaiBalanceE8S;
        try {
            totalFunnaiToDistribute := await getFunnaiBalance();
            D.print("MiningPool: startNextPoolCycle - updated FUNNAI balance: " # debug_show(totalFunnaiToDistribute));
        } catch (e) {
            D.print("MiningPool: startNextPoolCycle - Failed to update FUNNAI balance: " # Error.message(e));
            return #Err(#Other("Failed to get FUNNAI balance: " # Error.message(e)));
        };
        
        // Calculate and update distributions for each participant
        let distributionTime = getCurrentTimestamp();
        for ((principal, entry) in currentPoolParticipants.entries()) {
            let distribution = calculateFunnaiDistribution(
                entry.icpContributionE8S,
                totalCurrentIcp,
                totalFunnaiToDistribute
            );
            
            let updatedEntry : PoolParticipantEntry = {
                principal = entry.principal;
                icpContributionE8S = entry.icpContributionE8S;
                funnaiDistributionE8S = distribution;
                joinTimestamp = entry.joinTimestamp;
                distributionTimestamp = distributionTime;
            };
            
            currentPoolParticipants.put(principal, updatedEntry);
            
            // Execute actual FUNNAI transfer to participant
            if (distribution > 0) {
                let transferArgs : TokenLedger.TransferArg = {
                    from_subaccount = null;
                    to = {
                        owner = principal;
                        subaccount = null;
                    };
                    amount = distribution;
                    fee = null;
                    memo = null;
                    created_at_time = null;
                };
                D.print("MiningPool: startNextPoolCycle - transferArgs: " # debug_show(transferArgs));
                
                try {
                    let transferResult = await TokenLedger_Actor.icrc1_transfer(transferArgs);
                    D.print("MiningPool: startNextPoolCycle - transferResult: " # debug_show(transferResult));
                    
                    switch (transferResult) {
                        case (#Ok(blockIndex)) {
                            D.print("MiningPool: startNextPoolCycle - FUNNAI transfer successful to " # debug_show(principal) # ", block: " # debug_show(blockIndex));
                        };
                        case (#Err(err)) {
                            D.print("MiningPool: startNextPoolCycle - FUNNAI transfer failed to " # debug_show(principal) # ": " # debug_show(err));
                        };
                    };
                } catch (e) {
                    D.print("MiningPool: startNextPoolCycle - Failed to call ledger for " # debug_show(principal));
                };
            };
        };

        // Reset FUNNAI balance after distribution
        poolFunnaiBalanceE8S := 0;
        
        // Step 2: Archive current pool participants and cycle data
        let cycleRecord : PoolCycleRecord = {
            poolCycleId = currentCycleId;
            poolCycleStartTimestamp = currentCycleStartTimestamp;
            poolCycleEndTimestamp = currentCycleEndTimestamp;
            totalIcpContributedE8S = totalCurrentIcp;
            totalFunnaiDistributedE8S = totalFunnaiToDistribute;
            participantCount = currentPoolParticipants.size();
        };
        
        archivedPoolCycles.put(currentCycleId, cycleRecord);
        
        // Archive participants for this cycle
        let participantsArray = Iter.toArray(currentPoolParticipants.entries());
        archivedParticipants.put(currentCycleId, participantsArray);
        
        // Step 3: Add to user history
        for ((principal, entry) in currentPoolParticipants.entries()) {
            let historyEntry : UserHistoryEntry = {
                poolCycleId = currentCycleId;
                poolCycleStartTimestamp = currentCycleStartTimestamp;
                poolCycleEndTimestamp = currentCycleEndTimestamp;
                poolParticipantEntry = entry;
            };
            
            switch (userHistory.get(principal)) {
                case (?buffer) {
                    buffer.add(historyEntry);
                };
                case null {
                    let newBuffer = Buffer.Buffer<UserHistoryEntry>(1);
                    newBuffer.add(historyEntry);
                    userHistory.put(principal, newBuffer);
                };
            };
        };
        
        // Step 4: Move next pool participants to current pool participants
        currentPoolParticipants := nextPoolParticipants;
        
        // Step 5: Reset next pool participants
        nextPoolParticipants := HashMap.HashMap(0, Principal.equal, Principal.hash);
        
        // Step 6: Update cycle IDs and timestamps
        currentCycleId := currentCycleId + 1;
        currentCycleStartTimestamp := weekStartTimestamp;
        currentCycleEndTimestamp := weekEndTimestamp;
        
        // Step 7: Calculate cycles for mAIners and set burn rates
        var totalNextIcp : Nat = 0;
        for ((_, entry) in currentPoolParticipants.entries()) {
            totalNextIcp := totalNextIcp + entry.icpContributionE8S;
        };

        var totalCyclesForWeek = 0;
        try {
            totalCyclesForWeek := await calculateCyclesFromIcp(totalNextIcp);
            D.print("MiningPool: startNextPoolCycle - calculated cycles from ICP: " # debug_show(totalCyclesForWeek));
        } catch (e) {
            D.print("MiningPool: startNextPoolCycle - Failed to calculate cycles from ICP: " # Error.message(e));
            return #Err(#Other("Failed to calculate cycles from ICP: " # Error.message(e)));
        };
        
        let mainerCount = poolMainersStorage.size();
        
        if (mainerCount > 0) {
            let cyclesPerMainer = calculateCyclesPerMainer(totalCyclesForWeek, mainerCount);
            let burnRatePerMainer = determineBurnRateTier(cyclesPerMainer);
            let icpPerMainer = totalNextIcp / mainerCount;
            
            for ((address, mainerEntry) in poolMainersStorage.entries()) {
                // Top up mAIner with cyclesPerMainer via Game State
                let topUpResult = await topUpMainerWithCycles(mainerEntry, icpPerMainer);
                D.print("MiningPool: startNextPoolCycle - topUpResult for " # address # ": " # debug_show(topUpResult));

                // Set burn rate based on cyclesPerMainer on mAIner canister
                let mainerCanisterActor = actor (mainerEntry.address) : Types.MainerAgentCtrlbCanister;
                let settingInput : Types.MainerAgentSettingsInput = {
                    cyclesBurnRate : Types.CyclesBurnRateDefault = burnRatePerMainer;
                };
                try {
                    let updateResult = await mainerCanisterActor.updateAgentSettings(settingInput);
                    D.print("MiningPool: startNextPoolCycle - updateSettings result for " # address # ": " # debug_show(updateResult));
                } catch (e) {
                    D.print("MiningPool: startNextPoolCycle - Error calling updateAgentSettings for " # address # ": " # Error.message(e));
                };
            };
        };
        
        return #Ok("Pool cycle " # Nat.toText(currentCycleId) # " started successfully. Participants: " # Nat.toText(currentPoolParticipants.size()));
    };
    
    // Admin function: Add a mAIner to the pool
    public shared (msg) func addPoolMainer(
        mainerEntry : Types.OfficialMainerAgentCanister
    ) : async Types.TextResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        
        // Check if mAIner already exists
        switch (poolMainersStorage.get(mainerEntry.address)) {
            case (?_) {
                return #Err(#Other("mAIner already exists in pool"));
            };
            case null {
                poolMainersStorage.put(mainerEntry.address, mainerEntry);
                return #Ok("mAIner " # mainerEntry.address # " added to pool");
            };
        };
    };
    
    // Admin function: Remove a mAIner from the pool
    public shared (msg) func removePoolMainer(mainerAddress : Text) : async Types.TextResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        
        switch (poolMainersStorage.remove(mainerAddress)) {
            case (?_) {
                return #Ok("mAIner " # mainerAddress # " removed from pool");
            };
            case null {
                return #Err(#Other("mAIner not found in pool"));
            };
        };
    };
    
    // Admin function: Update pool's ICP and FUNNAI balances
    public shared (msg) func updatePoolBalances(icpBalanceE8S : Nat, funnaiBalance : Nat) : async Types.TextResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        
        // Get balances from ledgers
        poolIcpBalanceE8S := await getIcpBalance();
        poolFunnaiBalanceE8S := await getFunnaiBalance();
        
        return #Ok("Pool balances updated: ICP=" # Nat.toText(icpBalanceE8S) # " e8s, FUNNAI=" # Nat.toText(funnaiBalance));
    };
    
    // -------------------------------------------------------------------------------
    // Query Functions for Historical Data
    
    // Query: Get archived pool cycle details
    public query (msg) func getArchivedPoolCycle(cycleId : Nat) : async Types.Result<PoolCycleRecord, Types.ApiError> {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (archivedPoolCycles.get(cycleId)) {
            case (?record) {
                return #Ok(record);
            };
            case null {
                return #Err(#Other("Pool cycle not found"));
            };
        };
    };
    
    // Query: Get all archived pool cycles
    public query (msg)func getAllArchivedPoolCycles() : async Types.Result<[PoolCycleRecord], Types.ApiError> {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let cycles = Buffer.Buffer<PoolCycleRecord>(archivedPoolCycles.size());
        for ((_, record) in archivedPoolCycles.entries()) {
            cycles.add(record);
        };
        return #Ok(Buffer.toArray(cycles));
    };
    
    // Query: Get participants for a specific archived cycle
    public query (msg) func getArchivedCycleParticipants(cycleId : Nat) : async Types.Result<[(Principal, PoolParticipantEntry)], Types.ApiError> {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (archivedParticipants.get(cycleId)) {
            case (?participants) {
                return #Ok(participants);
            };
            case null {
                return #Err(#Other("Participants not found for cycle"));
            };
        };
    };
    
    // Query: Get aggregated past contributions and distributions
    public shared query func getAggregatedHistory() : async Types.Result<{
        totalCycles : Nat;
        totalParticipants : Nat;
        totalIcpContributedE8S : Nat;
        totalFunnaiDistributed : Nat;
    }, Types.ApiError> {
        var totalIcp : Nat = 0;
        var totalFunnai : Nat = 0;
        
        for ((_, record) in archivedPoolCycles.entries()) {
            totalIcp := totalIcp + record.totalIcpContributedE8S;
            totalFunnai := totalFunnai + record.totalFunnaiDistributedE8S;
        };
        
        return #Ok({
            totalCycles = currentCycleId;
            totalParticipants = totalParticipantsAllTime;
            totalIcpContributedE8S = totalIcp;
            totalFunnaiDistributed = totalFunnai;
        });
    };
    
    // Query: Get pool mAIners
    public query (msg) func getPoolMainers() : async Types.Result<[PoolMainerEntry], Types.ApiError> {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let mainers = Buffer.Buffer<PoolMainerEntry>(poolMainersStorage.size());
        for ((_, mainer) in poolMainersStorage.entries()) {
            mainers.add(mainer);
        };
        return #Ok(Buffer.toArray(mainers));
    };
    
    // Query: Get specific pool mAIner
    public query (msg) func getPoolMainer(mainerAddress : Text) : async Types.Result<PoolMainerEntry, Types.ApiError> {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (poolMainersStorage.get(mainerAddress)) {
            case (?mainer) {
                return #Ok(mainer);
            };
            case null {
                return #Err(#Other("mAIner not found"));
            };
        };
    };
    
    // Query: Get pool balances
    public shared query func getPoolBalances() : async Types.Result<{
        icpBalanceE8S : Nat;
        funnaiBalance : Nat;
    }, Types.ApiError> {
        return #Ok({
            icpBalanceE8S = poolIcpBalanceE8S;
            funnaiBalance = poolFunnaiBalanceE8S;
        });
    };
    
    // Query: Get pool configuration
    public shared query func getPoolConfiguration() : async Types.Result<{
        minIcpContributionE8S : Nat;
        maxIcpContributionE8S : Nat;
        treasuryFeePercentage : Nat;
        currentCycleId : Nat;
        nextCycleId : Nat;
        totalPoolCycles : Nat;
        totalParticipantsAllTime : Nat;
    }, Types.ApiError> {
        return #Ok({
            minIcpContributionE8S = MIN_ICP_CONTRIBUTION_E8S;
            maxIcpContributionE8S = MAX_ICP_CONTRIBUTION_E8S;
            treasuryFeePercentage = TREASURY_FEE_PERCENTAGE;
            currentCycleId = currentCycleId;
            nextCycleId = currentCycleId + 1;
            totalPoolCycles = currentCycleId;
            totalParticipantsAllTime = totalParticipantsAllTime;
        });
    };

    // -------------------------------------------------------------------------------
    // System Functions for Upgrades
    
    system func preupgrade() {
        poolMainersStorageStable := Iter.toArray(poolMainersStorage.entries());
        currentPoolParticipantsStable := Iter.toArray(currentPoolParticipants.entries());
        nextPoolParticipantsStable := Iter.toArray(nextPoolParticipants.entries());
        archivedPoolCyclesStable := Iter.toArray(archivedPoolCycles.entries());
        archivedParticipantsStable := Iter.toArray(archivedParticipants.entries());
        
        // Convert user history buffers to arrays
        let userHistoryArray = Buffer.Buffer<(Principal, [UserHistoryEntry])>(userHistory.size());
        for ((principal, historyBuffer) in userHistory.entries()) {
            userHistoryArray.add((principal, Buffer.toArray(historyBuffer)));
        };
        userHistoryStable := Buffer.toArray(userHistoryArray);
    };
    
    system func postupgrade() {
        poolMainersStorage := HashMap.fromIter(poolMainersStorageStable.vals(), poolMainersStorageStable.size(), Text.equal, Text.hash);
        currentPoolParticipants := HashMap.fromIter(currentPoolParticipantsStable.vals(), currentPoolParticipantsStable.size(), Principal.equal, Principal.hash);
        nextPoolParticipants := HashMap.fromIter(nextPoolParticipantsStable.vals(), nextPoolParticipantsStable.size(), Principal.equal, Principal.hash);
        archivedPoolCycles := HashMap.fromIter(archivedPoolCyclesStable.vals(), archivedPoolCyclesStable.size(), Nat.equal, Hash.hash);
        archivedParticipants := HashMap.fromIter(archivedParticipantsStable.vals(), archivedParticipantsStable.size(), Nat.equal, Hash.hash);
        
        // Convert user history arrays back to buffers
        for ((principal, historyArray) in userHistoryStable.vals()) {
            let historyBuffer = Buffer.Buffer<UserHistoryEntry>(historyArray.size());
            for (entry in historyArray.vals()) {
                historyBuffer.add(entry);
            };
            userHistory.put(principal, historyBuffer);
        };
        
        // Clear stable storage
        poolMainersStorageStable := [];
        currentPoolParticipantsStable := [];
        nextPoolParticipantsStable := [];
        archivedPoolCyclesStable := [];
        archivedParticipantsStable := [];
        userHistoryStable := [];
    };
};