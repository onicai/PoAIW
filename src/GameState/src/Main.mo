import D "mo:base/Debug";
import Buffer "mo:base/Buffer";
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
import Order "mo:base/Order";
import Error "mo:base/Error";
import Hash "mo:base/Hash";

import Types "../../common/Types";
import ICManagementCanister "../../common/ICManagementCanister";
import TokenLedger "../../common/icp-ledger-interface";
import Constants "../../common/Constants";
import CMC "../../common/cycles-minting-canister-interface";

import Utils "Utils";

actor class GameStateCanister() = this {

    let IC0 : ICManagementCanister.IC_Management = actor ("aaaaa-aa");

    // Function to verify that canister is up & running
    public shared query func health() : async Types.StatusCodeRecordResult {
        return #Ok({ status_code = 200 });
    };

    public shared query func getCanisterPrincipal() : async Text {
        return Principal.toText(Principal.fromActor(this));
    };

    // Token Ledger
    stable var TOKEN_LEDGER_CANISTER_ID : Text = "be2us-64aaa-aaaaa-qaabq-cai"; // TODO: update

    let ICP_LEDGER_ACTOR : TokenLedger.TOKEN_LEDGER = Types.IcpLedger_Actor;

    let CMC_ACTOR : CMC.CYCLES_MINTING_CANISTER = Types.CyclesMintingCanister_Actor;

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
        toSubaccount : ?TokenLedger.SubAccount;
    };
    private func transfer(args : TransferArgs) : async Result.Result<TokenLedger.BlockIndex, Text> {
        Debug.print(
            "Transferring "
            # debug_show (args.amount)
            # " tokens to principal "
            # debug_show (args.toPrincipal)
            # " subaccount "
            # debug_show (args.toSubaccount)
        );

        let transferArgs : TokenLedger.TransferArgs = {
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
            let transferResult = await ICP_LEDGER_ACTOR.transfer(transferArgs);

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

    private func verify_payment(paymentBlockIndex : TokenLedger.BlockIndex) : async Result.Result<Text, Text> {
        // https://internetcomputer.org/docs/defi/token-ledgers/usage/icp_ledger_usage#receiving-icp
        let startIndex : Nat64 = paymentBlockIndex;
        let queryLength : Nat64 = 1;
        let queryResult = await ICP_LEDGER_ACTOR.get_blocks({
            start = startIndex;
            length = queryLength;
        });
    }; */

    // Code Verification for all mAIner agents
        // Users should not be able to tamper with the mAIner code

    // mAIner agent wasm module hash that must match
        // TODO - Implementation: finalize implementation, ensure it's all stable, and remove any code not needed for production
        // -> For now, do not make it stable, so it can be updated via a canister upgrade
    var officialMainerAgentCanisterWasmHash : Blob = "\f5\d5\ab\57\f4\be\2d\c1\b2\1e\eb\51\02\1f\95\74\1f\3f\72\39\c5\c9\31\b1\e9\15\7d\73\4c\fc\8e\d8";
    stable var officialMainerAgentCanisterWasmHashVersion : Nat = 0;
    stable var officialMainerAgentCanisterWasmHashRecord : Types.CanisterWasmHashRecord = {
        wasmHash : Blob = officialMainerAgentCanisterWasmHash;
        creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
        createdBy : Principal = Principal.fromActor(this);
        version : Nat = officialMainerAgentCanisterWasmHashVersion;
        textNote : Text = "initial record";
    };

    stable var previousMainerAgentCanisterWasmHashRecords : List.List<Types.CanisterWasmHashRecord> = List.nil<Types.CanisterWasmHashRecord>();

    // Update the wasm hash record for the mAIner with the new wasm hash as input
    public shared (msg) func setOfficialMainerAgentCanisterWasmHashAdmin(updateWasmHashInput : Types.UpdateWasmHashInput) : async Types.CanisterWasmHashRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Increment version
        officialMainerAgentCanisterWasmHashVersion := officialMainerAgentCanisterWasmHashVersion + 1;
        // Archive current record
        previousMainerAgentCanisterWasmHashRecords := List.push<Types.CanisterWasmHashRecord>(officialMainerAgentCanisterWasmHashRecord, previousMainerAgentCanisterWasmHashRecords);
        // Update to new record
        let newMainerAgentCanisterWasmHashRecord : Types.CanisterWasmHashRecord = {
            wasmHash : Blob = updateWasmHashInput.wasmHash;
            creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            createdBy : Principal = msg.caller;
            version : Nat = officialMainerAgentCanisterWasmHashVersion;
            textNote : Text = updateWasmHashInput.textNote;
        };
        officialMainerAgentCanisterWasmHashRecord := newMainerAgentCanisterWasmHashRecord;
        officialMainerAgentCanisterWasmHash := updateWasmHashInput.wasmHash;

        return #Ok(newMainerAgentCanisterWasmHashRecord);
    };

    // Update the wasm hash record for the mAIner by getting the new wasm hash from a running mAIner
    public shared (msg) func deriveNewMainerAgentCanisterWasmHashAdmin(deriveWasmHashInput : Types.DeriveWasmHashInput) : async Types.CanisterWasmHashRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Get the mAIner canister's wasm module hash
        let IC_Management_Actor : ICManagementCanister.IC_Management = actor ("aaaaa-aa");
        try {
            let agentCanisterInfo = await IC_Management_Actor.canister_info({
                canister_id = Principal.fromText(deriveWasmHashInput.address);
                num_requested_changes = ?0;
            });  
            // Verify agent canister's wasm module hash
            switch (agentCanisterInfo.module_hash) {
                case (null) {
                    D.print("GameState: deriveOfficialMainerAgentCanisterWasmHashAdmin - canister has null as module hash: " # debug_show(deriveWasmHashInput));  
                    D.print("GameState: deriveOfficialMainerAgentCanisterWasmHashAdmin - agentCanisterInfo with null as module hash: " # debug_show(agentCanisterInfo));
                    return #Err(#Other("GameState: deriveOfficialMainerAgentCanisterWasmHashAdmin - canister has null as module hash: " # debug_show(deriveWasmHashInput)));
                };
                case (?agentModuleHash) {
                    D.print("GameState: deriveOfficialMainerAgentCanisterWasmHashAdmin - canister has module hash: " # debug_show(deriveWasmHashInput));  
                    D.print("GameState: deriveOfficialMainerAgentCanisterWasmHashAdmin - agentCanisterInfo with module hash: " # debug_show(agentCanisterInfo));
                    // Increment version
                    officialMainerAgentCanisterWasmHashVersion := officialMainerAgentCanisterWasmHashVersion + 1;
                    // Archive current record
                    previousMainerAgentCanisterWasmHashRecords := List.push<Types.CanisterWasmHashRecord>(officialMainerAgentCanisterWasmHashRecord, previousMainerAgentCanisterWasmHashRecords);
                    // Update to new record
                    let newMainerAgentCanisterWasmHashRecord : Types.CanisterWasmHashRecord = {
                        wasmHash : Blob = agentModuleHash;
                        creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                        createdBy : Principal = msg.caller;
                        version : Nat = officialMainerAgentCanisterWasmHashVersion;
                        textNote : Text = deriveWasmHashInput.textNote;
                    };
                    officialMainerAgentCanisterWasmHashRecord := newMainerAgentCanisterWasmHashRecord;
                    officialMainerAgentCanisterWasmHash := agentModuleHash;

                    return #Ok(newMainerAgentCanisterWasmHashRecord);
                };
            };
        } catch (e) {
            D.print("GameState: deriveOfficialMainerAgentCanisterWasmHashAdmin - Failed to retrieve info for mAIner: " # debug_show(deriveWasmHashInput) # Error.message(e));      
            return #Err(#Other("GameState: deriveOfficialMainerAgentCanisterWasmHashAdmin - Failed to retrieve info for mAIner: " # debug_show(deriveWasmHashInput) # Error.message(e)));
        };
    };
    
    public shared (msg) func testMainerCodeIntegrityAdmin() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let allMainerAgents : [Types.OfficialMainerAgentCanister] = getMainerAgents();
        let mainerAgentsIter : Iter.Iter<Types.OfficialMainerAgentCanister> = Iter.fromArray(allMainerAgents);
        
        try {
            // Retrieve each mAIner agent canister's info
            for (agentEntry in mainerAgentsIter) {
                try {
                    let agentCanisterInfo = await IC0.canister_info({
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
                            if (Blob.equal(agentModuleHash, officialMainerAgentCanisterWasmHashRecord.wasmHash)) {
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
    stable var THRESHOLD_SCORED_RESPONSES_PER_CHALLENGE : Nat = 7; // When reached, ranking and winner declaration; challenge is closed
    
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

    // Admin is responsible for setting the subnet IDs via the setSubnetsAdmin function
    stable var SUBNET_SHARE_AGENT_CTRL   : Text = "qdvhd-os4o2-zzrdw-xrcv4-gljou-eztdp-bj326-e6jgr-tkhuc-ql6v2-yqe";
    stable var SUBNET_SHARE_SERVICE_CTRL : Text = "qdvhd-os4o2-zzrdw-xrcv4-gljou-eztdp-bj326-e6jgr-tkhuc-ql6v2-yqe";
    stable var SUBNET_SHARE_SERVICE_LLM  : Text = "qdvhd-os4o2-zzrdw-xrcv4-gljou-eztdp-bj326-e6jgr-tkhuc-ql6v2-yqe";

    public shared (msg) func setSubnetsAdmin(subnets : Types.SubnetIds) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        try {
            let _ = Principal.fromText(subnets.subnetShareAgentCtrl);
            SUBNET_SHARE_AGENT_CTRL := subnets.subnetShareAgentCtrl;
        } catch (e) {
            // Ok, just continue, no need to set the subnet ID
        };
        try {
            let _ = Principal.fromText(subnets.subnetShareServiceCtrl);
            SUBNET_SHARE_SERVICE_CTRL := subnets.subnetShareServiceCtrl;
        } catch (e) {
            // Ok, just continue, no need to set the subnet ID
        };
        try {
            let _ = Principal.fromText(subnets.subnetShareServiceLlm);
            SUBNET_SHARE_SERVICE_LLM := subnets.subnetShareServiceLlm;
        } catch (e) {
            // Ok, just continue, no need to set the subnet ID
        };
        return #Ok({ status_code = 200 });
    };

    public shared query (msg) func getSubnetsAdmin() : async Types.SubnetIdsResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let subnets : Types.SubnetIds = {
            subnetShareAgentCtrl = SUBNET_SHARE_AGENT_CTRL;
            subnetShareServiceCtrl = SUBNET_SHARE_SERVICE_CTRL;
            subnetShareServiceLlm = SUBNET_SHARE_SERVICE_LLM;
        };
        return #Ok(subnets);
    };


    // Helper function
    private func getMainerSubnets(mainerAgentCanisterType : Types.MainerAgentCanisterType) : {subnetCtrl : Text; subnetLlm : Text} {       
        switch (mainerAgentCanisterType) {
            case (#Own) {
                return {
                    subnetCtrl = ""; // TODO
                    subnetLlm = "";  // TODO
                };
            };
            case (#ShareAgent) {
                return {
                    subnetCtrl = SUBNET_SHARE_AGENT_CTRL;
                    subnetLlm = "";  // No LLM for ShareAgent
                };
            };
            case (#ShareService) {
                // ShareService mAIners should be on high-performance subnets
                return {
                    subnetCtrl = SUBNET_SHARE_SERVICE_CTRL;
                    subnetLlm = SUBNET_SHARE_SERVICE_LLM;
                };
            };
            case (#NA) {
                return {
                    subnetCtrl = "";
                    subnetLlm = "";
                };
            };
        };
    };

    // Statistics 
    stable var TOTAL_PROTOCOL_CYCLES_BURNT : Nat = 0; // TODO - Implementation: ensure all relevant events for cycle buring are captured and adjust cycle burning numbers below to actual values
    // TODO: Update to actual values
    let CYCLES_BURNT_CHALLENGE_CREATION : Nat = 110 * Constants.CYCLES_BILLION;
    let CYCLES_BURNT_RESPONSE_GENERATION : Nat = 200 * Constants.CYCLES_BILLION;
    let CYCLES_BURNT_JUDGE_SCORING : Nat = 300 * Constants.CYCLES_BILLION;
    let CYCLES_BURNT_CANISTER_CREATION : Nat = 300 * Constants.CYCLES_BILLION;
    let CYCLES_BURNT_MAINER_CREATION : Nat = 300 * Constants.CYCLES_BILLION;
    let CYCLES_BURNT_LLM_CREATION : Nat = 1300 * Constants.CYCLES_BILLION;
    let CYCLES_BURNT_WINNER_DECLARATION : Nat = 100 * Constants.CYCLES_BILLION;

    // TODO: once a day, add the dailyIdleBurnRate using getDailyIdleBurnRate()
    private func increaseTotalProtocolCyclesBurnt(cyclesBurntToAdd : Nat) : Bool {
        TOTAL_PROTOCOL_CYCLES_BURNT := TOTAL_PROTOCOL_CYCLES_BURNT + cyclesBurntToAdd;
        return true;
    };

    // Price to create a mAIner TODO - Implementation: finalize prices (note that it's in 10000s)
    // Cycles for ShareAgent mAIner Creation
    stable var PRICE_FOR_SHARE_AGENT_ICP : Nat64 = 0; // TODO: Set to cost of a ShareAgent, in ICP
    public shared (msg) func setIcpForShareAgentAdmin(icpForShareAgent : Nat64) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        PRICE_FOR_SHARE_AGENT_ICP := icpForShareAgent;
        return #Ok({ status_code = 200 });
    };

    // Cycles for Own mAIner Creation 
    // Note: the ShareService mAIner will also use these values
    stable var PRICE_FOR_OWN_MAINER_ICP : Nat64 = 0; // TODO: Set to cost of a Own mAIner, in ICP
    public shared (msg) func setIcpForOwnMainerAdmin(icpForOwnMainer : Nat64) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        PRICE_FOR_OWN_MAINER_ICP := icpForOwnMainer;
        return #Ok({ status_code = 200 });
    };

    // TODO - Implementation: function to set the price for creating a mAIner
        // TODO - Implementation: Set timer for once a day that calculates the creation price based on the ICP/cycles conversion rate
    private func setPriceForCreatingMainer(newPrice : Nat64, mainerType : Types.MainerAgentCanisterType) : Bool {
        switch (mainerType) {
            case (#Own) {
                PRICE_FOR_OWN_MAINER_ICP := newPrice;
            };
            case (#ShareAgent) {
                PRICE_FOR_SHARE_AGENT_ICP := newPrice;
            };
            case (_) { return false; }
        };
        return true;
    };

    // Protocol parameters used in the mAIner Creation Cycles Flow calculations      
    let DEFAULT_CYCLES_CREATE_MAINER_MARGIN_GS          : Nat  =    25 * Constants.CYCLES_BILLION ; // Margin kept in GameState canister (includes actual costs)
    let DEFAULT_CYCLES_CREATE_MAINER_MARGIN_MC          : Nat  =   300 * Constants.CYCLES_BILLION ; // Margin kept in mAIner Creator canister (excludes actual costs)
    let DEFAULT_CYCLES_CREATE_MAINER_LLM_TARGET_BALANCE : Nat  =     2 * Constants.CYCLES_TRILLION; // Target balance for the Own LLM canister after creation
    let DEFAULT_COST_CREATE_MAINER_CTRL                 : Nat  =     1 * Constants.CYCLES_TRILLION; // Cost of a Mainer Controller canister for it's creation
    let DEFAULT_COST_CREATE_MAINER_LLM                  : Nat  =     1 * Constants.CYCLES_TRILLION; // Cost of a LLM canister for it's creation
    let DEFAULT_COST_MC_CREATE_MAINER_CTRL              : Nat  =     1 * Constants.CYCLES_BILLION ; // Cost for the MC to create a Mainer Controller canister
    let DEFAULT_COST_MC_CREATE_MAINER_LLM               : Nat  =   835 * Constants.CYCLES_BILLION ; // Cost for the MC to create a LLM canister

    stable var cyclesCreateMainerMarginGs         : Nat  = DEFAULT_CYCLES_CREATE_MAINER_MARGIN_GS;
    stable var cyclesCreatemMainerMarginMc        : Nat  = DEFAULT_CYCLES_CREATE_MAINER_MARGIN_MC;
    stable var cyclesCreateMainerLlmTargetBalance : Nat  = DEFAULT_CYCLES_CREATE_MAINER_LLM_TARGET_BALANCE;
    stable var costCreateMainerCtrl               : Nat  = DEFAULT_COST_CREATE_MAINER_CTRL;
    stable var costCreateMainerLlm                : Nat  = DEFAULT_COST_CREATE_MAINER_LLM;
    stable var costCreateMcMainerCtrl             : Nat  = DEFAULT_COST_MC_CREATE_MAINER_CTRL; 
    stable var costCreateMcMainerLlm              : Nat  = DEFAULT_COST_MC_CREATE_MAINER_LLM; 
    

    // Calculate the cycles that will be sent to the mAIner Creator once we know the user payment
    private func calculateCyclesCreateMainer(cyclesFromUser : Nat, mainerAgentCanisterType : Types.MainerAgentCanisterType) : Types.CyclesCreateMainer {
        // Call this at start of every mAIner canister creation

        var cyclesCreateMainerctrlGsMc         : Nat  = 0; // Cycles that will be sent to the mAIner Creator canister for the ctrl
        var cyclesCreateMainerllmGsMc          : Nat  = 0; // Cycles that will be sent to the mAIner Creator canister for the llm
        var cyclesCreateMainerctrlMcMainerctrl : Nat  = 0; // Cycles that will be sent to the mAIner Controller canister
        var cyclesCreateMainerllmMcMainerllm   : Nat  = 0; // Cycles that will be sent to the mAIner LLM canister
        
        switch (mainerAgentCanisterType) {
            case (#ShareAgent) {
                cyclesCreateMainerllmMcMainerllm := 0;
                cyclesCreateMainerllmGsMc        := 0;
            };
            case (_) {
                cyclesCreateMainerllmMcMainerllm  := cyclesCreateMainerLlmTargetBalance + costCreateMainerLlm;
                cyclesCreateMainerllmGsMc         := cyclesCreateMainerllmMcMainerllm + costCreateMcMainerLlm;
            };
        };

        D.print("GameState: calculateCyclesCreateMainer - cyclesFromUser                     : " # debug_show(cyclesFromUser));
        D.print("GameState: calculateCyclesCreateMainer - costCreateMainerCtrl               : " # debug_show(costCreateMainerCtrl));
        D.print("GameState: calculateCyclesCreateMainer - costCreateMainerLlm                : " # debug_show(costCreateMainerLlm));
        D.print("GameState: calculateCyclesCreateMainer - cyclesCreateMainerMarginGs         : " # debug_show(cyclesCreateMainerMarginGs));
        D.print("GameState: calculateCyclesCreateMainer - cyclesCreatemMainerMarginMc        : " # debug_show(cyclesCreatemMainerMarginMc));
        D.print("GameState: calculateCyclesCreateMainer - cyclesCreateMainerLlmTargetBalance : " # debug_show(cyclesCreateMainerLlmTargetBalance));
        D.print("GameState: calculateCyclesCreateMainer - cyclesCreateMainerllmGsMc          : " # debug_show(cyclesCreateMainerllmGsMc));
        D.print("GameState: calculateCyclesCreateMainer - cyclesCreateMainerllmMcMainerllm   : " # debug_show(cyclesCreateMainerllmMcMainerllm));

        let cyclesNeeded = cyclesCreateMainerMarginGs + cyclesCreatemMainerMarginMc + costCreateMainerCtrl + cyclesCreateMainerllmGsMc;
        if (cyclesFromUser < cyclesNeeded) {
            D.trap("GameState: calculateCyclesCreateMainer - Not enough cycles provided by user: " # debug_show(cyclesFromUser) # " < required: " # debug_show(cyclesNeeded));
        };
        cyclesCreateMainerctrlGsMc         := cyclesFromUser - cyclesCreateMainerMarginGs - cyclesCreateMainerllmGsMc;                 
        D.print("GameState: calculateCyclesCreateMainer - cyclesCreateMainerctrlGsMc         : " # debug_show(cyclesCreateMainerctrlGsMc));        

        cyclesCreateMainerctrlMcMainerctrl := cyclesCreateMainerctrlGsMc - cyclesCreatemMainerMarginMc;
        D.print("GameState: calculateCyclesCreateMainer - cyclesCreateMainerctrlMcMainerctrl : " # debug_show(cyclesCreateMainerctrlMcMainerctrl));
        
        let cyclesCreateMainer : Types.CyclesCreateMainer = {
            cyclesCreateMainerctrlGsMc = cyclesCreateMainerctrlGsMc;
            cyclesCreateMainerllmGsMc  = cyclesCreateMainerllmGsMc;
            cyclesCreateMainerctrlMcMainerctrl = cyclesCreateMainerctrlMcMainerctrl;
            cyclesCreateMainerllmMcMainerllm   = cyclesCreateMainerllmMcMainerllm;
        };
        return cyclesCreateMainer;
    };

    // Mainer Upgrade Cycles Flows are independent of user payments, so we can just set them
    let DEFAULT_COST_UPGRADE_MAINER_CTRL          : Nat  = 10 * Constants.CYCLES_BILLION; // Cost of a Mainer Controller canister for it's upgrade
    let DEFAULT_COST_UPGRADE_MAINER_LLM           : Nat  = 10 * Constants.CYCLES_BILLION; // Cost of a LLM canister for it's upgrade
    let DEFAULT_COST_MC_UPGRADE_MAINER_CTRL       : Nat  =  1 * Constants.CYCLES_BILLION ; // Cost for the MC to upgrade a Mainer Controller canister
    let DEFAULT_COST_MC_UPGRADE_MAINER_LLM        : Nat  =  1 * Constants.CYCLES_BILLION ; // Cost for the MC to upgrade a LLM canister
                                                                                                    // -> Note: we are NOT re-uploading the LLM model, only installing the new wasm
    stable var costUpgradeMainerCtrl              : Nat  = DEFAULT_COST_UPGRADE_MAINER_CTRL;
    stable var costUpgradeMainerLlm               : Nat  = DEFAULT_COST_UPGRADE_MAINER_LLM;
    stable var costUpgradeMcMainerCtrl            : Nat  = DEFAULT_COST_MC_UPGRADE_MAINER_CTRL;
    stable var costUpgradeMcMainerLlm             : Nat  = DEFAULT_COST_MC_UPGRADE_MAINER_LLM;

    stable var cyclesUpgradeMainerctrlGsMc         : Nat  = 0;
    stable var cyclesUpgradeMainerllmGsMc          : Nat  = 0;
    stable var cyclesUpgradeMainerctrlMcMainerctrl : Nat  = 0;
    stable var cyclesUpgradeMainerllmMcMainerllm   : Nat  = 0;

    private func setCyclesUpgradeMainer() {
        // To be called each time a variable is updated by Admin or by the protocol itself
        var cost : Nat = 0;

        cost := costUpgradeMainerCtrl + costUpgradeMcMainerCtrl;
        cyclesUpgradeMainerctrlGsMc         := cost + cost * marginCost / 100;

        cost := costUpgradeMainerLlm + costUpgradeMcMainerLlm;
        cyclesUpgradeMainerllmGsMc          := cost + cost * marginCost / 100;

        cyclesUpgradeMainerctrlMcMainerctrl := costUpgradeMainerCtrl;
        cyclesUpgradeMainerllmMcMainerllm   := costUpgradeMainerLlm;

        D.print("GameState: setCyclesUpgradeMainer - cyclesUpgradeMainerctrlGsMc         : " # debug_show(cyclesUpgradeMainerctrlGsMc));
        D.print("GameState: setCyclesUpgradeMainer - cyclesUpgradeMainerllmGsMc          : " # debug_show(cyclesUpgradeMainerllmGsMc));
        D.print("GameState: setCyclesUpgradeMainer - cyclesUpgradeMainerctrlMcMainerctrl : " # debug_show(cyclesUpgradeMainerctrlMcMainerctrl));
        D.print("GameState: setCyclesUpgradeMainer - cyclesUpgradeMainerllmMcMainerllm   : " # debug_show(cyclesUpgradeMainerllmMcMainerllm));
    };

    // Protocol parameters used in the Generation Cycles Flow calculations
    let DEFAULT_DAILY_CHALLENGES                : Nat = 5;                      // TODO: set the actual value or let the GameState automatically update this on a daily basis
    stable var dailyChallenges                  : Nat = DEFAULT_DAILY_CHALLENGES; // The lower the value, the more cycles are send with each challenge to the Challenger

    // -----------
    // TODO -- REMOVE THIS LOGIC. IT IS NOT USED...
    let DEFAULT_DAILY_SUBMISSIONS_PER_OWN_LOW      : Nat =  24; // TODO: set the actual value 
    stable var dailySubmissionsPerOwnLOW           : Nat = DEFAULT_DAILY_SUBMISSIONS_PER_OWN_LOW;
    let DEFAULT_DAILY_SUBMISSIONS_PER_OWN_MEDIUM   : Nat =  48; // TODO: set the actual value
    stable var dailySubmissionsPerOwnMEDIUM        : Nat = DEFAULT_DAILY_SUBMISSIONS_PER_OWN_MEDIUM;
    let DEFAULT_DAILY_SUBMISSIONS_PER_OWN_HIGH     : Nat =  72; // TODO: set the actual value
    stable var dailySubmissionsPerOwnHIGH          : Nat = DEFAULT_DAILY_SUBMISSIONS_PER_OWN_HIGH;

    let DEFAULT_DAILY_SUBMISSIONS_PER_SHARE_LOW    : Nat =   1; // TODO: set the actual value 
    stable var dailySubmissionsPerShareLOW         : Nat = DEFAULT_DAILY_SUBMISSIONS_PER_SHARE_LOW;
    let DEFAULT_DAILY_SUBMISSIONS_PER_SHARE_MEDIUM : Nat =   2; // TODO: set the actual value
    stable var dailySubmissionsPerShareMEDIUM      : Nat = DEFAULT_DAILY_SUBMISSIONS_PER_SHARE_MEDIUM;
    let DEFAULT_DAILY_SUBMISSIONS_PER_SHARE_HIGH   : Nat =   3; // TODO: set the actual value
    stable var dailySubmissionsPerShareHIGH        : Nat = DEFAULT_DAILY_SUBMISSIONS_PER_SHARE_HIGH;
    // -----------
    
    let DEFAULT_DAILY_SUBMISSIONS_ALL_OWN          : Nat =   0; // TODO = GameState automatically updates this on a daily basis
    stable var dailySubmissionsAllOwn              : Nat = DEFAULT_DAILY_SUBMISSIONS_ALL_OWN;
    let DEFAULT_DAILY_SUBMISSIONS_ALL_SHARE        : Nat = 100; // TODO = GameState automatically updates this on a daily basis
    stable var dailySubmissionsAllShare            : Nat = DEFAULT_DAILY_SUBMISSIONS_ALL_SHARE;

    let DEFAULT_PROTOCOL_OPERATION_FEES_CUT        : Nat =  10; // % added to unofficial mAIner agent's cycle topups to cover protocol operation fees  
    stable var protocolOperationFeesCut            : Nat = DEFAULT_PROTOCOL_OPERATION_FEES_CUT;
    let DEFAULT_MARGIN_FAILED_SUBMISSION_CUT       : Nat =  20; // % Margin for a Failed Submission Cut
    stable var marginFailedSubmissionCut           : Nat = DEFAULT_MARGIN_FAILED_SUBMISSION_CUT;
    let DEFAULT_MARGIN_COST                        : Nat =  10; // % Margin for all the cycles send to cover costs
    stable var marginCost                          : Nat = DEFAULT_MARGIN_COST;
    let DEFAULT_SUBMISSION_FEE                     : Nat =  75 * Constants.CYCLES_BILLION; // $0.10 Fee for the submission of a response to GameState
    stable var submissionFee                       : Nat = DEFAULT_SUBMISSION_FEE;

    // Number of protocol LLMs
    let DEFAULT_NUM_CHALLENGER_LLMS                : Nat =   1; // Number of Challenger   LLMs     - TODO: update to actual value
    stable var numChallengerLlms                   : Nat = DEFAULT_NUM_CHALLENGER_LLMS;
    let DEFAULT_NUM_JUDGE_LLMS                     : Nat =  24; // Number of Judge        LLMs     - TODO: update to actual value
    stable var numJudgeLlms                        : Nat = DEFAULT_NUM_JUDGE_LLMS;
    let DEFAULT_NUM_SHARE_SERVICE_LLMS             : Nat =  16; // Number of ShareService LLMs     - TODO: update to actual value
    stable var numShareServiceLlms                 : Nat = DEFAULT_NUM_SHARE_SERVICE_LLMS;
    
    // Cost of the idle burn rates for protocol canisters
    let DEFAULT_COST_IDLE_BURN_RATE_GS             : Nat = 201 * Constants.CYCLES_MILLION; // GameState                cost for idle burn rate
    stable var costIdleBurnRateGs                  : Nat = DEFAULT_COST_IDLE_BURN_RATE_GS;
    let DEFAULT_COST_IDLE_BURN_RATE_MC             : Nat =  28 * Constants.CYCLES_BILLION; // mAIner Creator           cost for idle burn rate
    stable var costIdleBurnRateMc                  : Nat = DEFAULT_COST_IDLE_BURN_RATE_MC;
    let DEFAULT_COST_IDLE_BURN_RATE_CHCTRL         : Nat = 115 * Constants.CYCLES_MILLION; // Challenger Controller    cost for idle burn rate
    stable var costIdleBurnRateChctrl              : Nat = DEFAULT_COST_IDLE_BURN_RATE_CHCTRL;
    let DEFAULT_COST_IDLE_BURN_RATE_CHLLM          : Nat =  24 * Constants.CYCLES_BILLION; // One Challenger LLM       cost for idle burn rate
    stable var costIdleBurnRateChllm               : Nat = DEFAULT_COST_IDLE_BURN_RATE_CHLLM;
    let DEFAULT_COST_IDLE_BURN_RATE_JUCTRL         : Nat = 115 * Constants.CYCLES_MILLION; // Judge Controller         cost for idle burn rate
    stable var costIdleBurnRateJuctrl              : Nat = DEFAULT_COST_IDLE_BURN_RATE_JUCTRL;
    let DEFAULT_COST_IDLE_BURN_RATE_JULLM          : Nat =  24 * Constants.CYCLES_BILLION; // One Judge LLM            cost for idle burn rate
    stable var costIdleBurnRateJullm               : Nat = DEFAULT_COST_IDLE_BURN_RATE_JULLM;
    let DEFAULT_COST_IDLE_BURN_RATE_SSCTRL         : Nat = 157 * Constants.CYCLES_MILLION; // ShareService Controller  cost for idle burn rate
    stable var costIdleBurnRateSsctrl              : Nat = DEFAULT_COST_IDLE_BURN_RATE_SSCTRL;
    let DEFAULT_COST_IDLE_BURN_RATE_SSLLM          : Nat =  24 * Constants.CYCLES_BILLION; // One ShareService LLM     cost for idle burn rate
    stable var costIdleBurnRateSsllm               : Nat = DEFAULT_COST_IDLE_BURN_RATE_SSLLM;

    
    // Cost of the idle burn rates for user canisters
    let DEFAULT_COST_IDLE_BURN_RATE_SACTRL         : Nat = 157 * Constants.CYCLES_MILLION; // ShareAgent Controller    cost for idle burn rate
    stable var costIdleBurnRateSactrl              : Nat = DEFAULT_COST_IDLE_BURN_RATE_SACTRL;
    let DEFAULT_COST_IDLE_BURN_RATE_SALLM          : Nat =  24 * Constants.CYCLES_BILLION; // One Share Service LLM    cost for idle burn rate
    stable var costIdleBurnRateSallm               : Nat = DEFAULT_COST_IDLE_BURN_RATE_SALLM;
    let DEFAULT_COST_IDLE_BURN_RATE_OWNCTRL        : Nat = 157 * Constants.CYCLES_MILLION; // Own Controller           cost for idle burn rate
    stable var costIdleBurnRateOwnctrl             : Nat = DEFAULT_COST_IDLE_BURN_RATE_OWNCTRL;
    let DEFAULT_COST_IDLE_BURN_RATE_OWNLLM         : Nat =  24 * Constants.CYCLES_BILLION; // Own LLM                  cost for idle burn rate
    stable var costIdleBurnRateOwnllm              : Nat = DEFAULT_COST_IDLE_BURN_RATE_OWNLLM;
    
    // Cost of the generations
    let DEFAULT_COST_GENERATE_CHALLENGE_GS         : Nat = 221 * Constants.CYCLES_MILLION; // GameState                cost for challenge generation
    stable var costGenerateChallengeGs             : Nat = DEFAULT_COST_GENERATE_CHALLENGE_GS;
    let DEFAULT_COST_GENERATE_CHALLENGE_CHCTRL     : Nat =  12 * Constants.CYCLES_BILLION; // Challenge Controller     cost for challenge generation
    stable var costGenerateChallengeChctrl         : Nat = DEFAULT_COST_GENERATE_CHALLENGE_CHCTRL;
    let DEFAULT_COST_GENERATE_CHALLENGE_CHLLM      : Nat = 305 * Constants.CYCLES_BILLION; // Challenge LLM            cost for challenge creation
    stable var costGenerateChallengeChllm          : Nat = DEFAULT_COST_GENERATE_CHALLENGE_CHLLM;

    let DEFAULT_COST_GENERATE_SCORE_GS             : Nat = 111 * Constants.CYCLES_MILLION; // GameState                cost for Score generation
    stable var costGenerateScoreGs                 : Nat = DEFAULT_COST_GENERATE_SCORE_GS;
    let DEFAULT_COST_GENERATE_SCORE_JUCTRL         : Nat =   6 * Constants.CYCLES_BILLION; // Judge Controller         cost for Score generation
    stable var costGenerateScoreJuctrl             : Nat = DEFAULT_COST_GENERATE_SCORE_JUCTRL;
    let DEFAULT_COST_GENERATE_SCORE_JULLM          : Nat = 125 * Constants.CYCLES_BILLION; // Judge LLM                cost for Score generation
    stable var costGenerateScoreJullm              : Nat = DEFAULT_COST_GENERATE_SCORE_JULLM;

    let DEFAULT_COST_GENERATE_RESPONSE_OWN_GS      : Nat = 150 * Constants.CYCLES_MILLION; // GameState                cost for Own response generation
    stable var costGenerateResponseOwnGs           : Nat = DEFAULT_COST_GENERATE_RESPONSE_OWN_GS;
    let DEFAULT_COST_GENERATE_RESPONSE_OWNCTRL     : Nat =   4 * Constants.CYCLES_BILLION; // Own Controller           cost for Own response generation
    stable var costGenerateResponseOwnctrl         : Nat = DEFAULT_COST_GENERATE_RESPONSE_OWNCTRL;
    let DEFAULT_COST_GENERATE_RESPONSE_OWNLLM      : Nat = 125 * Constants.CYCLES_BILLION; // Own LLM                  cost for Own response generation
    stable var costGenerateResponseOwnllm          : Nat = DEFAULT_COST_GENERATE_RESPONSE_OWNLLM;

    let DEFAULT_COST_GENERATE_RESPONSE_SHARE_GS    : Nat = 150 * Constants.CYCLES_MILLION; // GameState                cost for Share response generation
    stable var costGenerateResponseShareGs         : Nat = DEFAULT_COST_GENERATE_RESPONSE_SHARE_GS;
    let DEFAULT_COST_GENERATE_RESPONSE_SACTRL      : Nat = 100 * Constants.CYCLES_MILLION; // Share Agent   Controller cost for Share response generation
    stable var costGenerateResponseSactrl          : Nat = DEFAULT_COST_GENERATE_RESPONSE_SACTRL;
    let DEFAULT_COST_GENERATE_RESPONSE_SSCTRL      : Nat =   4 * Constants.CYCLES_BILLION; // Share Service Controller cost for Share response generation
    stable var costGenerateResponseSsctrl          : Nat = DEFAULT_COST_GENERATE_RESPONSE_SSCTRL;
    let DEFAULT_COST_GENERATE_RESPONSE_SSLLM       : Nat = 116 * Constants.CYCLES_BILLION; // Share Service LLM        cost for Share response generation
    stable var costGenerateResponseSsllm           : Nat = DEFAULT_COST_GENERATE_RESPONSE_SSLLM;

    // Calculate Cycles Flows for Challenge generation by Challenger
    stable var cyclesGenerateChallengeGsChctrl     : Nat = 0;
    stable var cyclesGenerateChallengeChctrlChllm  : Nat = 0;
    stable var cyclesBurntChallengeGeneration      : Nat = 0;
    private func setCyclesGenerateChallenge() {
        // To be called each time a variable is updated by Admin or by the protocol itself
        var cost : Nat = 0;

        cost := costGenerateChallengeChllm + costIdleBurnRateChllm / dailyChallenges;
        cyclesGenerateChallengeChctrlChllm  := cost + cost * marginCost / 100;

        cost := costGenerateChallengeChctrl + costIdleBurnRateChctrl / dailyChallenges;
        cyclesGenerateChallengeGsChctrl     := cyclesGenerateChallengeChctrlChllm +
                                               cost + cost * marginCost / 100 ;

        cyclesBurntChallengeGeneration        := costGenerateChallengeGs + costGenerateChallengeChctrl + costGenerateChallengeChllm;
        D.print("GameState: setCyclesGenerateChallenge - cyclesGenerateChallengeGsChctrl    : " # debug_show(cyclesGenerateChallengeGsChctrl));
        D.print("GameState: setCyclesGenerateChallenge - cyclesGenerateChallengeChctrlChllm : " # debug_show(cyclesGenerateChallengeChctrlChllm));
        D.print("GameState: setCyclesGenerateChallenge - cyclesBurntChallengeGeneration       : " # debug_show(cyclesBurntChallengeGeneration));
    };

    // Calculate Cycles Flows for Score generation by Judge
    stable var cyclesGenerateScoreGsJuctrl         : Nat = 0;
    stable var cyclesGenerateScoreJuctrlJullm      : Nat = 0;
    stable var cyclesBurntJudgeScoring             : Nat = 0;
    private func setCyclesGenerateScore() {
        // To be called each time a variable is updated by Admin or by the protocol itself
        var cost : Nat = 0;

        let dailySubmissions = dailySubmissionsAllOwn + dailySubmissionsAllShare;
        cost := costGenerateScoreJullm + costIdleBurnRateJullm / dailySubmissions;
        cyclesGenerateScoreJuctrlJullm      := cost + cost * marginCost / 100;

        cost := costGenerateScoreJuctrl + costIdleBurnRateJuctrl / dailySubmissions;
        cyclesGenerateScoreGsJuctrl         := cyclesGenerateScoreJuctrlJullm +
                                               cost + cost * marginCost / 100 ;

        cyclesBurntJudgeScoring             := costGenerateScoreGs + costGenerateScoreJuctrl + costGenerateScoreJullm;
        D.print("GameState: setCyclesGenerateScore - dailySubmissionsAllOwn            : " # debug_show(dailySubmissionsAllOwn));
        D.print("GameState: setCyclesGenerateScore - dailySubmissionsAllShare          : " # debug_show(dailySubmissionsAllShare));
        D.print("GameState: setCyclesGenerateScore - cyclesGenerateScoreGsJuctrl       : " # debug_show(cyclesGenerateScoreGsJuctrl));
        D.print("GameState: setCyclesGenerateScore - cyclesGenerateScoreJuctrlJullm    : " # debug_show(cyclesGenerateScoreJuctrlJullm));
        D.print("GameState: setCyclesGenerateScore - cyclesBurntJudgeScoring           : " # debug_show(cyclesBurntJudgeScoring));
    };

    // Calculate Cycles Flows for Response generation by mAIners
    stable var cyclesGenerateResponseOwnctrlGs           : Nat = 0; // Gs incurs cost for download of the prompt.cache
    stable var cyclesGenerateResponseOwnctrlOwnllmLOW    : Nat = 0;
    stable var cyclesGenerateResponseOwnctrlOwnllmMEDIUM : Nat = 0;
    stable var cyclesGenerateResponseOwnctrlOwnllmHIGH   : Nat = 0;
    stable var cyclesBurntResponseGenerationOwn          : Nat = 0; 

    stable var cyclesGenerateResponseSactrlSsctrl  : Nat = 0;
    stable var cyclesGenerateResponseSsctrlGs      : Nat = 0; // Gs incurs cost for download of the prompt.cache
    stable var cyclesGenerateResponseSsctrlSsllm   : Nat = 0;
    stable var cyclesBurntResponseGenerationShare  : Nat = 0; 

    stable var cyclesSubmitResponse                : Nat = 0;
    stable var cyclesFailedSubmissionCut           : Nat = 0; 

    private func setCyclesGenerateResponse() {
        // To be called each time a variable is updated by Admin or by the protocol itself
        var cost : Nat = 0;

        // Response generation by Own mAIner
        cost := costGenerateResponseOwnGs;
        cyclesGenerateResponseOwnctrlGs     := cost + cost * marginCost / 100;

        cost := costGenerateResponseOwnllm + costIdleBurnRateOwnllm / dailySubmissionsPerOwnLOW;
        cyclesGenerateResponseOwnctrlOwnllmLOW := cost + cost * marginCost / 100;

        cost := costGenerateResponseOwnllm + costIdleBurnRateOwnllm / dailySubmissionsPerOwnMEDIUM;
        cyclesGenerateResponseOwnctrlOwnllmMEDIUM := cost + cost * marginCost / 100;

        cost := costGenerateResponseOwnllm + costIdleBurnRateOwnllm / dailySubmissionsPerOwnHIGH;
        cyclesGenerateResponseOwnctrlOwnllmHIGH := cost + cost * marginCost / 100;

        // Response generation by Shared mAIner
        cost := costGenerateResponseShareGs;
        cyclesGenerateResponseSsctrlGs      := cost + cost * marginCost / 100;

        cost := costGenerateResponseSsctrl + costGenerateResponseSsllm +
               (costIdleBurnRateSsctrl + numShareServiceLlms * costIdleBurnRateSsllm) / dailySubmissionsAllShare;
        cyclesGenerateResponseSactrlSsctrl  := cyclesGenerateResponseSsctrlGs + 
                                               cost + cost * marginCost / 100;

        cost := costGenerateResponseSsllm + (numShareServiceLlms * costIdleBurnRateSsllm) / dailySubmissionsAllShare;
        cyclesGenerateResponseSsctrlSsllm   := cost + cost * marginCost / 100;

        // Total burnt cycles for response generation by ALL canisters involved (excludes idle burn)
        cyclesBurntResponseGenerationOwn    := costGenerateResponseOwnGs + costGenerateResponseOwnctrl + costGenerateResponseOwnllm;
        cyclesBurntResponseGenerationShare  := costGenerateResponseShareGs + costGenerateResponseSactrl + costGenerateResponseSsctrl + costGenerateResponseSsllm;


        // Submission of the response to GameState
        // Cover cost of:
        // -> GameState, Challenger & Judge for this response to a Challenge, including their idle burn rates
        // -> The idle burn rate of the mAInerCreator
        // Note that ShareService is not included here, as it's costs are already covered by the ShareAgent
        //
        let dailyIdleBurnRate = costIdleBurnRateGs + 
                                costIdleBurnRateChctrl + numChallengerLlms * costIdleBurnRateChllm + 
                                costIdleBurnRateJuctrl + numJudgeLlms      * costIdleBurnRateJullm +
                                costIdleBurnRateMc;
        let dailySubmissionsAll = dailySubmissionsAllOwn + dailySubmissionsAllShare;
        cost := costGenerateScoreGs + costGenerateScoreJuctrl + costGenerateScoreJullm +
               (costGenerateChallengeChctrl + costGenerateChallengeChllm) / THRESHOLD_SCORED_RESPONSES_PER_CHALLENGE +
                dailyIdleBurnRate / dailySubmissionsAll;
        cyclesSubmitResponse                := submissionFee + cost + cost * marginCost / 100;
        cyclesFailedSubmissionCut           := cyclesSubmitResponse * marginFailedSubmissionCut / 100;

        D.print("GameState: setCyclesGenerateResponse - cyclesGenerateResponseOwnctrlGs           : " # debug_show(cyclesGenerateResponseOwnctrlGs));
        D.print("GameState: setCyclesGenerateResponse - cyclesGenerateResponseOwnctrlOwnllmLOW    : " # debug_show(cyclesGenerateResponseOwnctrlOwnllmLOW));
        D.print("GameState: setCyclesGenerateResponse - cyclesGenerateResponseOwnctrlOwnllmMEDIUM : " # debug_show(cyclesGenerateResponseOwnctrlOwnllmMEDIUM));
        D.print("GameState: setCyclesGenerateResponse - cyclesGenerateResponseOwnctrlOwnllmHIGH   : " # debug_show(cyclesGenerateResponseOwnctrlOwnllmHIGH));
        
        D.print("GameState: setCyclesGenerateResponse - cyclesGenerateResponseSactrlSsctrl        : " # debug_show(cyclesGenerateResponseSactrlSsctrl));
        D.print("GameState: setCyclesGenerateResponse - cyclesGenerateResponseSsctrlGs            : " # debug_show(cyclesGenerateResponseSsctrlGs));
        D.print("GameState: setCyclesGenerateResponse - cyclesGenerateResponseSsctrlSsllm         : " # debug_show(cyclesGenerateResponseSsctrlSsllm));

        D.print("GameState: setCyclesGenerateResponse - cyclesBurntResponseGenerationOwn          : " # debug_show(cyclesBurntResponseGenerationOwn));
        D.print("GameState: setCyclesGenerateResponse - cyclesBurntResponseGenerationShare        : " # debug_show(cyclesBurntResponseGenerationShare));

        D.print("GameState: setCyclesGenerateResponse - cyclesSubmitResponse                      : " # debug_show(cyclesSubmitResponse));
        D.print("GameState: setCyclesGenerateResponse - cyclesFailedSubmissionCut                 : " # debug_show(cyclesFailedSubmissionCut));
    };

    private func resetCyclesFlow() {
        // Reset all parameters to their default values
        cyclesCreateMainerMarginGs         := DEFAULT_CYCLES_CREATE_MAINER_MARGIN_GS;
        cyclesCreatemMainerMarginMc        := DEFAULT_CYCLES_CREATE_MAINER_MARGIN_MC;
        cyclesCreateMainerLlmTargetBalance := DEFAULT_CYCLES_CREATE_MAINER_LLM_TARGET_BALANCE;
        costCreateMainerCtrl               := DEFAULT_COST_CREATE_MAINER_CTRL;
        costCreateMainerLlm                := DEFAULT_COST_CREATE_MAINER_LLM;        
        costCreateMcMainerCtrl             := DEFAULT_COST_MC_CREATE_MAINER_CTRL;
        costCreateMcMainerLlm              := DEFAULT_COST_MC_CREATE_MAINER_LLM;

        costUpgradeMainerCtrl               := DEFAULT_COST_UPGRADE_MAINER_CTRL;
        costUpgradeMainerLlm                := DEFAULT_COST_UPGRADE_MAINER_LLM;        
        costUpgradeMcMainerCtrl             := DEFAULT_COST_MC_UPGRADE_MAINER_CTRL;
        costUpgradeMcMainerLlm              := DEFAULT_COST_MC_UPGRADE_MAINER_LLM;

        dailyChallenges := DEFAULT_DAILY_CHALLENGES;
        
        dailySubmissionsPerOwnLOW := DEFAULT_DAILY_SUBMISSIONS_PER_OWN_LOW;
        dailySubmissionsPerOwnMEDIUM := DEFAULT_DAILY_SUBMISSIONS_PER_OWN_MEDIUM;
        dailySubmissionsPerOwnHIGH := DEFAULT_DAILY_SUBMISSIONS_PER_OWN_HIGH;
        
        dailySubmissionsPerShareLOW := DEFAULT_DAILY_SUBMISSIONS_PER_SHARE_LOW;
        dailySubmissionsPerShareMEDIUM := DEFAULT_DAILY_SUBMISSIONS_PER_SHARE_MEDIUM;
        dailySubmissionsPerShareHIGH := DEFAULT_DAILY_SUBMISSIONS_PER_SHARE_HIGH;
        
        dailySubmissionsAllOwn := DEFAULT_DAILY_SUBMISSIONS_ALL_OWN;
        dailySubmissionsAllShare := DEFAULT_DAILY_SUBMISSIONS_ALL_SHARE;
        
        marginFailedSubmissionCut := DEFAULT_MARGIN_FAILED_SUBMISSION_CUT;
        marginCost := DEFAULT_MARGIN_COST;
        submissionFee := DEFAULT_SUBMISSION_FEE;
        
        numChallengerLlms := DEFAULT_NUM_CHALLENGER_LLMS;
        numJudgeLlms := DEFAULT_NUM_JUDGE_LLMS;
        numShareServiceLlms := DEFAULT_NUM_SHARE_SERVICE_LLMS;
        
        costIdleBurnRateGs := DEFAULT_COST_IDLE_BURN_RATE_GS;
        costIdleBurnRateMc := DEFAULT_COST_IDLE_BURN_RATE_MC;
        costIdleBurnRateChctrl := DEFAULT_COST_IDLE_BURN_RATE_CHCTRL;
        costIdleBurnRateChllm := DEFAULT_COST_IDLE_BURN_RATE_CHLLM;
        costIdleBurnRateJuctrl := DEFAULT_COST_IDLE_BURN_RATE_JUCTRL;
        costIdleBurnRateJullm := DEFAULT_COST_IDLE_BURN_RATE_JULLM;
        costIdleBurnRateSsctrl := DEFAULT_COST_IDLE_BURN_RATE_SSCTRL;
        costIdleBurnRateSsllm := DEFAULT_COST_IDLE_BURN_RATE_SSLLM;
        
        costIdleBurnRateSactrl := DEFAULT_COST_IDLE_BURN_RATE_SACTRL;
        costIdleBurnRateSallm := DEFAULT_COST_IDLE_BURN_RATE_SALLM;
        costIdleBurnRateOwnctrl := DEFAULT_COST_IDLE_BURN_RATE_OWNCTRL;
        costIdleBurnRateOwnllm := DEFAULT_COST_IDLE_BURN_RATE_OWNLLM;
        
        costGenerateChallengeGs := DEFAULT_COST_GENERATE_CHALLENGE_GS;
        costGenerateChallengeChctrl := DEFAULT_COST_GENERATE_CHALLENGE_CHCTRL;
        costGenerateChallengeChllm := DEFAULT_COST_GENERATE_CHALLENGE_CHLLM;
        
        costGenerateScoreGs := DEFAULT_COST_GENERATE_SCORE_GS;
        costGenerateScoreJuctrl := DEFAULT_COST_GENERATE_SCORE_JUCTRL;
        costGenerateScoreJullm := DEFAULT_COST_GENERATE_SCORE_JULLM;
        
        costGenerateResponseOwnGs := DEFAULT_COST_GENERATE_RESPONSE_OWN_GS;
        costGenerateResponseOwnctrl := DEFAULT_COST_GENERATE_RESPONSE_OWNCTRL;
        costGenerateResponseOwnllm := DEFAULT_COST_GENERATE_RESPONSE_OWNLLM;
        
        costGenerateResponseShareGs := DEFAULT_COST_GENERATE_RESPONSE_SHARE_GS;
        costGenerateResponseSactrl := DEFAULT_COST_GENERATE_RESPONSE_SACTRL;
        costGenerateResponseSsctrl := DEFAULT_COST_GENERATE_RESPONSE_SSCTRL;
        costGenerateResponseSsllm := DEFAULT_COST_GENERATE_RESPONSE_SSLLM;

        // Then set all the cycles flows
        setCyclesFlow();
    };

    private func setCyclesFlow() {
        // Calculate the cycles flows
        setCyclesUpgradeMainer();
        setCyclesGenerateChallenge();
        setCyclesGenerateScore();
        setCyclesGenerateResponse();
    };

    // Endpoint for mAIner #ShareAgent and #Own to get current cost of response generation & submissions
    public shared (msg) func getMainerCyclesUsedPerResponse() : async Types.NatResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Only official mAIner agent canisters may call this
        switch (getMainerAgentCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?mainerAgentEntry) {
                var cyclesUsed : Nat = cyclesSubmitResponse;
                
                switch (mainerAgentEntry.canisterType) {
                    case (#MainerAgent(#Own)) {
                        cyclesUsed := cyclesUsed + costGenerateResponseOwnctrl + costGenerateResponseOwnllm;
                    };
                    case (#MainerAgent(#ShareAgent)) {
                        cyclesUsed := cyclesUsed + costGenerateResponseSactrl + cyclesGenerateResponseSactrlSsctrl;
                    };
                    case (_) { return #Err(#Other("Unsupported")); }
                    };
                
                D.print("GameState: getMainerCyclesUsedPerResponse - cyclesUsed: " # debug_show(cyclesUsed) # " returned to mAiner (" # debug_show(mainerAgentEntry.canisterType) # ") " # Principal.toText(msg.caller));
                return #Ok(cyclesUsed);
            };
        };
    };
    
    // Cycle Flow Settings Admin Endpoints
    public shared (msg) func getCyclesFlowAdmin() : async Types.CyclesFlowResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Return the current cycles flow settings
        let cyclesFlow : Types.CyclesFlow = {
            // mAIner creation
            cyclesCreateMainerMarginGs = cyclesCreateMainerMarginGs;
            cyclesCreatemMainerMarginMc = cyclesCreatemMainerMarginMc;
            cyclesCreateMainerLlmTargetBalance = cyclesCreateMainerLlmTargetBalance;
            costCreateMainerCtrl = costCreateMainerCtrl;
            costCreateMainerLlm = costCreateMainerLlm;
            costCreateMcMainerCtrl = costCreateMcMainerCtrl;
            costCreateMcMainerLlm = costCreateMcMainerLlm;
            costUpgradeMainerCtrl = costUpgradeMainerCtrl;
            costUpgradeMainerLlm = costUpgradeMainerLlm;
            costUpgradeMcMainerCtrl = costUpgradeMcMainerCtrl;
            costUpgradeMcMainerLlm = costUpgradeMcMainerLlm;


            // Generations
            dailyChallenges = dailyChallenges;
            dailySubmissionsPerOwnLOW = dailySubmissionsPerOwnLOW;
            dailySubmissionsPerOwnMEDIUM = dailySubmissionsPerOwnMEDIUM;
            dailySubmissionsPerOwnHIGH = dailySubmissionsPerOwnHIGH;
            dailySubmissionsPerShareLOW = dailySubmissionsPerShareLOW;
            dailySubmissionsPerShareMEDIUM = dailySubmissionsPerShareMEDIUM;
            dailySubmissionsPerShareHIGH = dailySubmissionsPerShareHIGH;
            dailySubmissionsAllOwn = dailySubmissionsAllOwn;
            dailySubmissionsAllShare = dailySubmissionsAllShare;
            marginFailedSubmissionCut = marginFailedSubmissionCut;
            marginCost = marginCost;
            submissionFee = submissionFee;

            numChallengerLlms = numChallengerLlms;
            numJudgeLlms = numJudgeLlms;
            numShareServiceLlms = numShareServiceLlms;

            costIdleBurnRateGs = costIdleBurnRateGs;
            costIdleBurnRateMc = costIdleBurnRateMc;
            costIdleBurnRateChctrl = costIdleBurnRateChctrl;
            costIdleBurnRateChllm = costIdleBurnRateChllm;
            costIdleBurnRateJuctrl = costIdleBurnRateJuctrl;
            costIdleBurnRateJullm = costIdleBurnRateJullm;
            costIdleBurnRateSsctrl = costIdleBurnRateSsctrl;
            costIdleBurnRateSsllm = costIdleBurnRateSsllm;

            costIdleBurnRateSactrl = costIdleBurnRateSactrl;
            costIdleBurnRateSallm = costIdleBurnRateSallm;
            costIdleBurnRateOwnctrl = costIdleBurnRateOwnctrl;
            costIdleBurnRateOwnllm = costIdleBurnRateOwnllm;

            costGenerateChallengeGs = costGenerateChallengeGs;
            costGenerateChallengeChctrl = costGenerateChallengeChctrl;
            costGenerateChallengeChllm = costGenerateChallengeChllm;
            costGenerateScoreGs = costGenerateScoreGs;
            costGenerateScoreJuctrl = costGenerateScoreJuctrl;
            costGenerateScoreJullm = costGenerateScoreJullm;
            costGenerateResponseOwnGs = costGenerateResponseOwnGs;
            costGenerateResponseOwnctrl = costGenerateResponseOwnctrl;
            costGenerateResponseOwnllm = costGenerateResponseOwnllm;
            costGenerateResponseShareGs = costGenerateResponseShareGs;
            costGenerateResponseSactrl = costGenerateResponseSactrl;
            costGenerateResponseSsctrl = costGenerateResponseSsctrl;
            costGenerateResponseSsllm = costGenerateResponseSsllm;

            cyclesGenerateChallengeGsChctrl = cyclesGenerateChallengeGsChctrl;
            cyclesGenerateChallengeChctrlChllm = cyclesGenerateChallengeChctrlChllm;
            cyclesBurntChallengeGeneration = cyclesBurntChallengeGeneration;
            cyclesGenerateScoreGsJuctrl = cyclesGenerateScoreGsJuctrl;
            cyclesGenerateScoreJuctrlJullm = cyclesGenerateScoreJuctrlJullm;
            cyclesBurntJudgeScoring = cyclesBurntJudgeScoring;
            cyclesGenerateResponseOwnctrlGs = cyclesGenerateResponseOwnctrlGs;
            cyclesGenerateResponseOwnctrlOwnllmLOW = cyclesGenerateResponseOwnctrlOwnllmLOW;
            cyclesGenerateResponseOwnctrlOwnllmMEDIUM = cyclesGenerateResponseOwnctrlOwnllmMEDIUM;
            cyclesGenerateResponseOwnctrlOwnllmHIGH = cyclesGenerateResponseOwnctrlOwnllmHIGH;
            cyclesGenerateResponseSactrlSsctrl = cyclesGenerateResponseSactrlSsctrl;
            cyclesGenerateResponseSsctrlGs = cyclesGenerateResponseSsctrlGs;
            cyclesGenerateResponseSsctrlSsllm = cyclesGenerateResponseSsctrlSsllm;
            cyclesBurntResponseGenerationOwn = cyclesBurntResponseGenerationOwn;
            cyclesBurntResponseGenerationShare = cyclesBurntResponseGenerationShare;
            cyclesSubmitResponse = cyclesSubmitResponse;
            protocolOperationFeesCut = protocolOperationFeesCut;
            cyclesFailedSubmissionCut = cyclesFailedSubmissionCut;
        };

        return #Ok(cyclesFlow);
    };

    public shared (msg) func resetCyclesFlowAdmin() : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        resetCyclesFlow();

        return #Ok({ status_code = 200 });
    };

    public shared (msg) func setCyclesFlowAdmin(settings: Types.CyclesFlowSettings) : async Types.StatusCodeRecordResult {
        // Function to allow the admin to set the parameters and the calculated values in stable memory
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Optionally, update the Protocol parameters
        switch (settings.dailyChallenges) { case (null) {}; case (?value) { dailyChallenges := value; }; }; // TODO: remove this once we update it automatically
        switch (settings.dailySubmissionsPerOwnLOW) { case (null) {}; case (?value) { dailySubmissionsPerOwnLOW := value; }; };
        switch (settings.dailySubmissionsPerOwnMEDIUM) { case (null) {}; case (?value) { dailySubmissionsPerOwnMEDIUM := value; }; };
        switch (settings.dailySubmissionsPerOwnHIGH) { case (null) {}; case (?value) { dailySubmissionsPerOwnHIGH := value; }; };
        switch (settings.dailySubmissionsPerShareLOW) { case (null) {}; case (?value) { dailySubmissionsPerShareLOW := value; }; };
        switch (settings.dailySubmissionsPerShareMEDIUM) { case (null) {}; case (?value) { dailySubmissionsPerShareMEDIUM := value; }; };
        switch (settings.dailySubmissionsPerShareHIGH) { case (null) {}; case (?value) { dailySubmissionsPerShareHIGH := value; }; };
        switch (settings.dailySubmissionsAllOwn) { case (null) {}; case (?value) { dailySubmissionsAllOwn := value; }; }; // TODO: remove this once we update it automatically
        switch (settings.dailySubmissionsAllShare) { case (null) {}; case (?value) { dailySubmissionsAllShare := value; }; }; // TODO: remove this once we update it automatically
        switch (settings.marginFailedSubmissionCut) { case (null) {}; case (?value) { marginFailedSubmissionCut := value; }; };
        switch (settings.marginCost) { case (null) {}; case (?value) { marginCost := value; }; };
        switch (settings.submissionFee) { case (null) {}; case (?value) { submissionFee := value; }; };
        switch (settings.protocolOperationFeesCut) { case (null) {}; case (?value) { protocolOperationFeesCut := value; }; };

        // Optionally, update the mAIner creation parameters
        switch (settings.cyclesCreateMainerMarginGs) { case (null) {}; case (?value) { cyclesCreateMainerMarginGs := value; }; };
        switch (settings.cyclesCreatemMainerMarginMc) { case (null) {}; case (?value) { cyclesCreatemMainerMarginMc := value; }; };
        switch (settings.cyclesCreateMainerLlmTargetBalance) { case (null) {}; case (?value) { cyclesCreateMainerLlmTargetBalance := value; }; };
        switch (settings.costCreateMainerCtrl) { case (null) {}; case (?value) { costCreateMainerCtrl := value; }; };
        switch (settings.costCreateMainerLlm) { case (null) {}; case (?value) { costCreateMainerLlm := value; }; };
        switch (settings.costCreateMcMainerCtrl) { case (null) {}; case (?value) { costCreateMcMainerCtrl := value; }; };
        switch (settings.costCreateMcMainerLlm) { case (null) {}; case (?value) { costCreateMcMainerLlm := value; }; };
        
        // Optionally, update the mAIner upgrade parameters
        switch (settings.costUpgradeMainerCtrl) { case (null) {}; case (?value) { costUpgradeMainerCtrl := value; }; };
        switch (settings.costUpgradeMainerLlm) { case (null) {}; case (?value) { costUpgradeMainerLlm := value; }; };
        switch (settings.costUpgradeMcMainerCtrl) { case (null) {}; case (?value) { costUpgradeMcMainerCtrl := value; }; };
        switch (settings.costUpgradeMcMainerLlm) { case (null) {}; case (?value) { costUpgradeMcMainerLlm := value; }; };
            
        // Optionally, update the number of LLMs
        // TODO: remove this once we update it automatically as part of the protocol
        switch (settings.numChallengerLlms) { case (null) {}; case (?value) { numChallengerLlms := value; }; };
        switch (settings.numJudgeLlms) { case (null) {}; case (?value) { numJudgeLlms := value; }; };
        switch (settings.numShareServiceLlms) { case (null) {}; case (?value) { numShareServiceLlms := value; }; };

        // Optionally, update the idle burn rates for protocol canisters
        switch (settings.costIdleBurnRateGs) { case (null) {}; case (?value) { costIdleBurnRateGs := value; }; };
        switch (settings.costIdleBurnRateMc) { case (null) {}; case (?value) { costIdleBurnRateMc := value; }; };
        switch (settings.costIdleBurnRateChctrl) { case (null) {}; case (?value) { costIdleBurnRateChctrl := value; }; };
        switch (settings.costIdleBurnRateChllm) { case (null) {}; case (?value) { costIdleBurnRateChllm := value; }; };
        switch (settings.costIdleBurnRateJuctrl) { case (null) {}; case (?value) { costIdleBurnRateJuctrl := value; }; };
        switch (settings.costIdleBurnRateJullm) { case (null) {}; case (?value) { costIdleBurnRateJullm := value; }; };
        switch (settings.costIdleBurnRateSsctrl) { case (null) {}; case (?value) { costIdleBurnRateSsctrl := value; }; };
        switch (settings.costIdleBurnRateSsllm) { case (null) {}; case (?value) { costIdleBurnRateSsllm := value; }; };

        // Optionally, update the idle burn rates for user canisters
        switch (settings.costIdleBurnRateSactrl) { case (null) {}; case (?value) { costIdleBurnRateSactrl := value; }; };
        switch (settings.costIdleBurnRateSallm) { case (null) {}; case (?value) { costIdleBurnRateSallm := value; }; };
        switch (settings.costIdleBurnRateOwnctrl) { case (null) {}; case (?value) { costIdleBurnRateOwnctrl := value; }; };
        switch (settings.costIdleBurnRateOwnllm) { case (null) {}; case (?value) { costIdleBurnRateOwnllm := value; }; };
        
        // Optionally, update Generation cost
        switch (settings.costGenerateChallengeGs) { case (null) {}; case (?value) { costGenerateChallengeGs := value; }; };
        switch (settings.costGenerateChallengeChctrl) { case (null) {}; case (?value) { costGenerateChallengeChctrl := value; }; };
        switch (settings.costGenerateChallengeChllm) { case (null) {}; case (?value) { costGenerateChallengeChllm := value; }; };
        
        switch (settings.costGenerateScoreGs) { case (null) {}; case (?value) { costGenerateScoreGs := value; }; };
        switch (settings.costGenerateScoreJuctrl) { case (null) {}; case (?value) { costGenerateScoreJuctrl := value; }; };
        switch (settings.costGenerateScoreJullm) { case (null) {}; case (?value) { costGenerateScoreJullm := value; }; };

        switch (settings.costGenerateResponseOwnGs) { case (null) {}; case (?value) { costGenerateResponseOwnGs := value; }; };
        switch (settings.costGenerateResponseOwnctrl) { case (null) {}; case (?value) { costGenerateResponseOwnctrl := value; }; };
        switch (settings.costGenerateResponseOwnllm) { case (null) {}; case (?value) { costGenerateResponseOwnllm := value; }; };
        
        switch (settings.costGenerateResponseShareGs) { case (null) {}; case (?value) { costGenerateResponseShareGs := value; }; };
        switch (settings.costGenerateResponseSactrl) { case (null) {}; case (?value) { costGenerateResponseSactrl := value; }; };
        switch (settings.costGenerateResponseSsctrl) { case (null) {}; case (?value) { costGenerateResponseSsctrl := value; }; };
        switch (settings.costGenerateResponseSsllm) { case (null) {}; case (?value) { costGenerateResponseSsllm := value; }; };

        // Then calculate & set the cycles flow values
        setCyclesFlow();

        // Optionally, update calculated cycles flow values (these are computed, but can be overridden)
        switch (settings.cyclesGenerateChallengeGsChctrl) { case (null) {}; case (?value) { cyclesGenerateChallengeGsChctrl := value; }; };
        switch (settings.cyclesGenerateChallengeChctrlChllm) { case (null) {}; case (?value) { cyclesGenerateChallengeChctrlChllm := value; }; };
        switch (settings.cyclesBurntChallengeGeneration) { case (null) {}; case (?value) { cyclesBurntChallengeGeneration := value; }; };
        switch (settings.cyclesGenerateScoreGsJuctrl) { case (null) {}; case (?value) { cyclesGenerateScoreGsJuctrl := value; }; };
        switch (settings.cyclesGenerateScoreJuctrlJullm) { case (null) {}; case (?value) { cyclesGenerateScoreJuctrlJullm := value; }; };
        switch (settings.cyclesBurntJudgeScoring) { case (null) {}; case (?value) { cyclesBurntJudgeScoring := value; }; };
        switch (settings.cyclesGenerateResponseOwnctrlGs) { case (null) {}; case (?value) { cyclesGenerateResponseOwnctrlGs := value; }; };
        switch (settings.cyclesGenerateResponseOwnctrlOwnllmLOW) { case (null) {}; case (?value) { cyclesGenerateResponseOwnctrlOwnllmLOW := value; }; };
        switch (settings.cyclesGenerateResponseOwnctrlOwnllmMEDIUM) { case (null) {}; case (?value) { cyclesGenerateResponseOwnctrlOwnllmMEDIUM := value; }; };
        switch (settings.cyclesGenerateResponseOwnctrlOwnllmHIGH) { case (null) {}; case (?value) { cyclesGenerateResponseOwnctrlOwnllmHIGH := value; }; };
        switch (settings.cyclesGenerateResponseSactrlSsctrl) { case (null) {}; case (?value) { cyclesGenerateResponseSactrlSsctrl := value; }; };
        switch (settings.cyclesGenerateResponseSsctrlGs) { case (null) {}; case (?value) { cyclesGenerateResponseSsctrlGs := value; }; };
        switch (settings.cyclesGenerateResponseSsctrlSsllm) { case (null) {}; case (?value) { cyclesGenerateResponseSsctrlSsllm := value; }; };
        switch (settings.cyclesBurntResponseGenerationOwn) { case (null) {}; case (?value) { cyclesBurntResponseGenerationOwn := value; }; };
        switch (settings.cyclesBurntResponseGenerationShare) { case (null) {}; case (?value) { cyclesBurntResponseGenerationShare := value; }; };
        switch (settings.cyclesSubmitResponse) { case (null) {}; case (?value) { cyclesSubmitResponse := value; }; };
        switch (settings.cyclesFailedSubmissionCut) { case (null) {}; case (?value) { cyclesFailedSubmissionCut := value; }; };

        return #Ok({ status_code = 200 });
    };

    // The total daily idle burn rate of all the canisters
    private func getDailyIdleBurnRate() : Nat {
        let numOwnMainers : Nat = 0;   // TODO: use the actual value
        let numShareMainers : Nat = 0; // TODO: use the actual value
        let dailyIdleBurnRate : Nat = 
                costIdleBurnRateGs + costIdleBurnRateMc + 
                costIdleBurnRateChctrl + numChallengerLlms   * costIdleBurnRateChllm + 
                costIdleBurnRateJuctrl + numJudgeLlms        * costIdleBurnRateJullm + 
                costIdleBurnRateSsctrl + numShareServiceLlms * costIdleBurnRateSsllm +
                numShareMainers *  costIdleBurnRateSactrl +
                numOwnMainers   * (costIdleBurnRateOwnctrl + costIdleBurnRateOwnllm); // TODO: update once we allow an Own mAIner to have multiple LLMs
        D.print("GameState: setDailyIdleBurnRate - dailyIdleBurnRate    : " # debug_show(dailyIdleBurnRate));
        return dailyIdleBurnRate;
    };

    
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
        // TODO - Security: for security reasons, include checks here for an entry that already exists i.e. that immutable fields aren't changed
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

    private func resetOpenChallenges() : Bool {
        // Create a new empty HashMap to replace the current one
        let emptyStorage : HashMap.HashMap<Text, Types.Challenge> = HashMap.HashMap(0, Text.equal, Text.hash);
        
        // Replace the openChallengesStorage with an empty HashMap
        openChallengesStorage := emptyStorage;
        
        // Return success
        return true;
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

    // Admin functions to get all closed challenges and their count
    public shared query (msg) func getClosedChallengesAdmin() : async Types.ChallengesResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let closedChallengesArray : [Types.Challenge] = getClosedChallenges();

        return #Ok(closedChallengesArray);
    };

    public shared query (msg) func getNumClosedChallengesAdmin() : async Types.NatResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let closedChallengesArray : [Types.Challenge] = getClosedChallenges();

        return #Ok(closedChallengesArray.size());
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

    // Admin functions to get all archived challenges and their count
    public shared query (msg) func getArchivedChallengesAdmin() : async Types.ChallengesResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let archivedChallengesArray : [Types.Challenge] = getArchivedChallenges();

        return #Ok(archivedChallengesArray);
    };

    public shared query (msg) func getNumArchivedChallengesAdmin() : async Types.NatResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let archivedChallengesArray : [Types.Challenge] = getArchivedChallenges();

        return #Ok(archivedChallengesArray.size());
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

    // Hashmap for mAIner prompt & prompt cache storage, key=mainerPromptId
    stable var mainerPromptsStable : [(Text, Types.MainerPrompt)] = [];
    var mainerPrompts : HashMap.HashMap<Text, Types.MainerPrompt> = HashMap.HashMap(0, Text.equal, Text.hash);

    // Emepheral Hashmap for mAIner prompt cache upload buffers for chunked uploads, key=mainerPromptId
    var mainerPromptCacheUploadBuffers : HashMap.HashMap<Text, Buffer.Buffer<Blob>> = HashMap.HashMap(0, Text.equal, Text.hash);

    // Function to be called by Challenger to start upload of the mainer prompt & prompt cache
    public shared (msg) func startUploadMainerPromptCache() : async Types.StartUploadMainerPromptCacheRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Only official Challenger canisters may call this
        switch (getChallengerCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?challengerEntry) {
                // Verify consistency of the caller
                if (challengerEntry.address != Principal.toText(msg.caller)) {
                    return #Err(#Unauthorized);
                };

                let mainerPromptId : Text = await Utils.newRandomUniqueId();
                D.print("GameState: startUploadMainerPromptCache - mainerPromptId: " # debug_show(mainerPromptId));

                // Initialize the prompt cache upload session for this Challenge
                let mainerPromptCacheUploadBuffer : Buffer.Buffer<Blob> = Buffer.Buffer<Blob>(0);
                mainerPromptCacheUploadBuffers.put(mainerPromptId, mainerPromptCacheUploadBuffer);
                
                return #Ok({ mainerPromptId = mainerPromptId });
            };             
        };
    };

    // Function to be called by Challenger to upload a chunk of the mAIner prompt cache for a given challenge
    public shared (msg) func uploadMainerPromptCacheBytesChunk(uploadMainerPromptCacheBytesChunkInput: Types.UploadMainerPromptCacheBytesChunkInput) : async Types.StatusCodeRecordResult {
        let mainerPromptId: Text = uploadMainerPromptCacheBytesChunkInput.mainerPromptId;
        let bytesChunk : Blob = uploadMainerPromptCacheBytesChunkInput.bytesChunk;
        let chunkID : Nat = uploadMainerPromptCacheBytesChunkInput.chunkID;

        D.print("GameState: uploadMainerPromptCacheBytesChunk - mainerPromptId: " # debug_show(mainerPromptId) # ", chunkID : " # debug_show(chunkID));
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Only official Challenger canisters may call this
        switch (getChallengerCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?challengerEntry) {
                // Verify consistency of the caller
                if (challengerEntry.address != Principal.toText(msg.caller)) {
                    return #Err(#Unauthorized);
                };

                switch (mainerPromptCacheUploadBuffers.get(mainerPromptId)) {
                    case (null) { return #Err(#Other("No upload buffer found for mainerPromptId: " # mainerPromptId # "first call: startUploadMainerPromptCache")); };
                    case (?mainerPromptCacheUploadBuffer) { 
                        let expectedChunkID = mainerPromptCacheUploadBuffer.size();
                        // Only process if this is the expected next chunk or a retry of a previous chunk
                        if (chunkID < expectedChunkID) {
                            // This is a retry of a chunk we've already processed
                            return #Ok({ status_code = 200 });
                        } else if (chunkID == expectedChunkID) {
                            // This is the expected next chunk, so process it
                            mainerPromptCacheUploadBuffer.add(bytesChunk);
                            return #Ok({ status_code = 200 });
                        } else {
                            // This is a chunk ahead of what we expect (gap in sequence)
                            return #Err(#Other("Chunk ID " # Nat.toText(chunkID) # " is ahead of the expected chunk ID " # Nat.toText(expectedChunkID)));
                        };
                    };
                };
            };             
        };
    };

    // Function to be called by Challenger to finish upload of the mainer prompt cache & store it with prompt text and sha256
    public shared (msg) func finishUploadMainerPromptCache(finishUploadMainerPromptCacheInput : Types.FinishUploadMainerPromptCacheInput) : async Types.StatusCodeRecordResult {
        let mainerPromptId: Text = finishUploadMainerPromptCacheInput.mainerPromptId;
        let promptText: Text = finishUploadMainerPromptCacheInput.promptText;
        let promptCacheSha256: Text = finishUploadMainerPromptCacheInput.promptCacheSha256;
        let promptCacheFilename: Text = finishUploadMainerPromptCacheInput.promptCacheFilename;

        D.print("GameState: finishUploadMainerPromptCache - mainerPromptId: " # debug_show(mainerPromptId));
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Only official Challenger canisters may call this
        switch (getChallengerCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?challengerEntry) {
                // Verify consistency of the caller
                if (challengerEntry.address != Principal.toText(msg.caller)) {
                    return #Err(#Unauthorized);
                };

                switch (mainerPromptCacheUploadBuffers.get(mainerPromptId)) {
                    case (null) { return #Err(#Other("No upload buffer found for mainerPromptId: " # mainerPromptId)); };
                    case (?mainerPromptCacheUploadBuffer) { 
                        // Store the mAIner prompt & cache & sha256 for this Challenge
                        let mainerPrompt : Types.MainerPrompt = {
                            promptText = promptText;
                            promptCacheSha256 = promptCacheSha256;
                            promptCacheFilename = promptCacheFilename;
                            promptCacheNumberOfChunks = mainerPromptCacheUploadBuffer.size();
                            promptCacheChunks = Buffer.toArray<Blob>(mainerPromptCacheUploadBuffer);
                        };
                        D.print("GameState: finishUploadMainerPromptCache - Storing mainerPrompt for mainerPromptId: " # debug_show(mainerPromptId) # "\n" #
                            "promptText: " # debug_show(promptText) # "\n" #
                            "promptCacheSha256: " # debug_show(promptCacheSha256));
                        mainerPrompts.put(mainerPromptId, mainerPrompt);

                        // Delete the prompt cache upload buffer for this Challenge
                        let _ = mainerPromptCacheUploadBuffers.remove(mainerPromptId);

                        return #Ok({ status_code = 200 });
                    };
                };
            };             
        };
    };

    // Function to be called by mAIner to get the mainer prompt info
    public shared query (msg) func getMainerPromptInfo(mainerPromptId : Text) : async Types.MainerPromptInfoResult {
        D.print("GameState: getMainerPromptInfo - mainerPromptId: " # debug_show(mainerPromptId));
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Only official mAIner canisters may call this
        switch (getMainerAgentCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?mainerAgentEntry) {
                // Verify consistency of the caller
                if (mainerAgentEntry.address != Principal.toText(msg.caller)) {
                    return #Err(#Unauthorized);
                };
                
                switch (mainerPrompts.get(mainerPromptId)) {
                    case (null) { return #Err(#Other("No mainerPrompt found for mainerPromptId: " # mainerPromptId)); };
                    case (?mainerPrompt) { 
                        // Store the mAIner prompt & cache & sha256 for this Challenge
                        let mainerPromptInfo : Types.MainerPromptInfo = {
                            promptText = mainerPrompt.promptText;
                            promptCacheSha256 = mainerPrompt.promptCacheSha256;
                            promptCacheFilename = mainerPrompt.promptCacheFilename;
                            promptCacheNumberOfChunks = mainerPrompt.promptCacheNumberOfChunks;
                        };
                        D.print("GameState: getMainerPromptInfo - Returning mainerPromptInfo for mainerPromptId: " # debug_show(mainerPromptId) # "\n" #
                            "mainerPromptInfo: " # debug_show(mainerPromptInfo) );
                        return #Ok(mainerPromptInfo);
                    };
                };
            };             
        };
    };

    // Function to be called by mAIner to get the mainer prompt cache in chunks
    public shared query (msg) func downloadMainerPromptCacheBytesChunk(downloadMainerPromptCacheBytesChunkInput : Types.DownloadMainerPromptCacheBytesChunkInput) : async Types.DownloadMainerPromptCacheBytesChunkRecordResult {
        D.print("GameState: downloadMainerPromptCacheBytesChunk.");
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Only official mAIner canisters may call this
        switch (getMainerAgentCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?mainerAgentEntry) {
                // Verify consistency of the caller
                if (mainerAgentEntry.address != Principal.toText(msg.caller)) {
                    return #Err(#Unauthorized);
                };

                let mainerPromptId: Text = downloadMainerPromptCacheBytesChunkInput.mainerPromptId;
                let chunkID : Nat = downloadMainerPromptCacheBytesChunkInput.chunkID;
                
                switch (mainerPrompts.get(mainerPromptId)) {
                    case (null) { return #Err(#Other("No mainerPrompt found for mainerPromptId: " # mainerPromptId)); };
                    case (?mainerPrompt) { 
                        let promptCacheChunks : [Blob] = mainerPrompt.promptCacheChunks;
                        if (chunkID >= promptCacheChunks.size()) {
                            return #Err(#Other("Chunk ID " # Nat.toText(chunkID) # " is out of range for mainerPromptId: " # mainerPromptId));
                        };
                        let chunk : Blob = promptCacheChunks[chunkID];
                        let downloadMainerPromptCacheBytesChunkRecord : Types.DownloadMainerPromptCacheBytesChunkRecord = {
                            mainerPromptId : Text = mainerPromptId;
                            chunkID : Nat = chunkID;
                            bytesChunk : Blob = chunk;
                        };

                        return #Ok(downloadMainerPromptCacheBytesChunkRecord);
                    };
                };
            };             
        };
    };

    // Hashmap for Judge prompt & prompt cache storage, key=judgePromptId
    stable var judgePromptsStable : [(Text, Types.JudgePrompt)] = [];
    var judgePrompts : HashMap.HashMap<Text, Types.JudgePrompt> = HashMap.HashMap(0, Text.equal, Text.hash);

    // Emepheral Hashmap for Judge prompt cache upload buffers for chunked uploads, key=judgePromptId
    var judgePromptCacheUploadBuffers : HashMap.HashMap<Text, Buffer.Buffer<Blob>> = HashMap.HashMap(0, Text.equal, Text.hash);

    // Function to be called by Challenger to start upload of the Judge prompt & prompt cache
    public shared (msg) func startUploadJudgePromptCache() : async Types.StartUploadJudgePromptCacheRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Only official Challenger canisters may call this
        switch (getChallengerCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?challengerEntry) {
                // Verify consistency of the caller
                if (challengerEntry.address != Principal.toText(msg.caller)) {
                    return #Err(#Unauthorized);
                };

                let judgePromptId : Text = await Utils.newRandomUniqueId();
                D.print("GameState: startUploadJudgePromptCache - judgePromptId: " # debug_show(judgePromptId));

                // Initialize the prompt cache upload session for this Challenge
                let judgePromptCacheUploadBuffer : Buffer.Buffer<Blob> = Buffer.Buffer<Blob>(0);
                judgePromptCacheUploadBuffers.put(judgePromptId, judgePromptCacheUploadBuffer);
                
                return #Ok({ judgePromptId = judgePromptId });
            };             
        };
    };

    // Function to be called by Challenger to upload a chunk of the Judge prompt cache for a given challenge
    public shared (msg) func uploadJudgePromptCacheBytesChunk(uploadJudgePromptCacheBytesChunkInput: Types.UploadJudgePromptCacheBytesChunkInput) : async Types.StatusCodeRecordResult {
        let judgePromptId: Text = uploadJudgePromptCacheBytesChunkInput.judgePromptId;
        let bytesChunk : Blob = uploadJudgePromptCacheBytesChunkInput.bytesChunk;
        let chunkID : Nat = uploadJudgePromptCacheBytesChunkInput.chunkID;

        D.print("GameState: uploadJudgePromptCacheBytesChunk - judgePromptId: " # debug_show(judgePromptId) # ", chunkID : " # debug_show(chunkID));
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Only official Challenger canisters may call this
        switch (getChallengerCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?challengerEntry) {
                // Verify consistency of the caller
                if (challengerEntry.address != Principal.toText(msg.caller)) {
                    return #Err(#Unauthorized);
                };

                switch (judgePromptCacheUploadBuffers.get(judgePromptId)) {
                    case (null) { return #Err(#Other("No upload buffer found for judgePromptId: " # judgePromptId # "first call: startUploadJudgePromptCache")); };
                    case (?judgePromptCacheUploadBuffer) { 
                        let expectedChunkID = judgePromptCacheUploadBuffer.size();
                        // Only process if this is the expected next chunk or a retry of a previous chunk
                        if (chunkID < expectedChunkID) {
                            // This is a retry of a chunk we've already processed
                            return #Ok({ status_code = 200 });
                        } else if (chunkID == expectedChunkID) {
                            // This is the expected next chunk, so process it
                            judgePromptCacheUploadBuffer.add(bytesChunk);
                            return #Ok({ status_code = 200 });
                        } else {
                            // This is a chunk ahead of what we expect (gap in sequence)
                            return #Err(#Other("Chunk ID " # Nat.toText(chunkID) # " is ahead of the expected chunk ID " # Nat.toText(expectedChunkID)));
                        };
                    };
                };
            };             
        };
    };

    // Function to be called by Challenger to finish upload of the Judge prompt cache & store it with prompt text and sha256
    public shared (msg) func finishUploadJudgePromptCache(finishUploadJudgePromptCacheInput : Types.FinishUploadJudgePromptCacheInput) : async Types.StatusCodeRecordResult {
        let judgePromptId: Text = finishUploadJudgePromptCacheInput.judgePromptId;
        let promptText: Text = finishUploadJudgePromptCacheInput.promptText;
        let promptCacheSha256: Text = finishUploadJudgePromptCacheInput.promptCacheSha256;
        let promptCacheFilename: Text = finishUploadJudgePromptCacheInput.promptCacheFilename;

        D.print("GameState: finishUploadJudgePromptCache - judgePromptId: " # debug_show(judgePromptId));
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Only official Challenger canisters may call this
        switch (getChallengerCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?challengerEntry) {
                // Verify consistency of the caller
                if (challengerEntry.address != Principal.toText(msg.caller)) {
                    return #Err(#Unauthorized);
                };

                switch (judgePromptCacheUploadBuffers.get(judgePromptId)) {
                    case (null) { return #Err(#Other("No upload buffer found for judgePromptId: " # judgePromptId)); };
                    case (?judgePromptCacheUploadBuffer) { 
                        // Store the Judge prompt & cache & sha256 for this Challenge
                        let judgePrompt : Types.JudgePrompt = {
                            promptText = promptText;
                            promptCacheSha256 = promptCacheSha256;
                            promptCacheFilename = promptCacheFilename;
                            promptCacheNumberOfChunks = judgePromptCacheUploadBuffer.size();
                            promptCacheChunks = Buffer.toArray<Blob>(judgePromptCacheUploadBuffer);
                        };
                        D.print("GameState: finishUploadJudgePromptCache - Storing judgePrompt for judgePromptId: " # debug_show(judgePromptId) # "\n" #
                            "promptText: " # debug_show(promptText) # "\n" #
                            "promptCacheSha256: " # debug_show(promptCacheSha256));
                        judgePrompts.put(judgePromptId, judgePrompt);

                        // Delete the prompt cache upload buffer for this Challenge
                        let _ = judgePromptCacheUploadBuffers.remove(judgePromptId);

                        return #Ok({ status_code = 200 });
                    };
                };
            };             
        };
    };

    // Function to be called by Judge to get the judge prompt info
    public shared query (msg) func getJudgePromptInfo(judgePromptId : Text) : async Types.JudgePromptInfoResult {
        D.print("GameState: getJudgePromptInfo - judgePromptId: " # debug_show(judgePromptId));
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Only official Judge canisters may call this
        switch (getJudgeCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?judgeEntry) {
                // Verify consistency of the caller
                if (judgeEntry.address != Principal.toText(msg.caller)) {
                    return #Err(#Unauthorized);
                };
                
                switch (judgePrompts.get(judgePromptId)) {
                    case (null) { return #Err(#Other("No judgePrompt found for judgePromptId: " # judgePromptId)); };
                    case (?judgePrompt) { 
                        // Store the Judge prompt & cache & sha256 for this Challenge
                        let judgePromptInfo : Types.JudgePromptInfo = {
                            promptText = judgePrompt.promptText;
                            promptCacheSha256 = judgePrompt.promptCacheSha256;
                            promptCacheFilename = judgePrompt.promptCacheFilename;
                            promptCacheNumberOfChunks = judgePrompt.promptCacheNumberOfChunks;
                        };
                        D.print("GameState: getJudgePromptInfo - Returning judgePromptInfo for judgePromptId: " # debug_show(judgePromptId) # "\n" #
                            "judgePromptInfo: " # debug_show(judgePromptInfo) );
                        return #Ok(judgePromptInfo);
                    };
                };
            };             
        };
    };

    // Function to be called by Judge to get the judge prompt cache in chunks
    public shared query (msg) func downloadJudgePromptCacheBytesChunk(downloadJudgePromptCacheBytesChunkInput : Types.DownloadJudgePromptCacheBytesChunkInput) : async Types.DownloadJudgePromptCacheBytesChunkRecordResult {
        D.print("GameState: downloadJudgePromptCacheBytesChunk.");
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Only official Judge canisters may call this
        switch (getJudgeCanister(Principal.toText(msg.caller))) {
            case (null) { return #Err(#Unauthorized); };
            case (?judgeEntry) {
                // Verify consistency of the caller
                if (judgeEntry.address != Principal.toText(msg.caller)) {
                    return #Err(#Unauthorized);
                };

                let judgePromptId: Text = downloadJudgePromptCacheBytesChunkInput.judgePromptId;
                let chunkID : Nat = downloadJudgePromptCacheBytesChunkInput.chunkID;
                
                switch (judgePrompts.get(judgePromptId)) {
                    case (null) { return #Err(#Other("No judgePrompt found for judgePromptId: " # judgePromptId)); };
                    case (?judgePrompt) { 
                        let promptCacheChunks : [Blob] = judgePrompt.promptCacheChunks;
                        if (chunkID >= promptCacheChunks.size()) {
                            return #Err(#Other("Chunk ID " # Nat.toText(chunkID) # " is out of range for judgePromptId: " # judgePromptId));
                        };
                        let chunk : Blob = promptCacheChunks[chunkID];
                        let downloadJudgePromptCacheBytesChunkRecord : Types.DownloadJudgePromptCacheBytesChunkRecord = {
                            judgePromptId : Text = judgePromptId;
                            chunkID : Nat = chunkID;
                            bytesChunk : Blob = chunk;
                        };

                        return #Ok(downloadJudgePromptCacheBytesChunkRecord);
                    };
                };
            };             
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

     private func getOpenSubmissionsForOpenChallenges() : [Types.ChallengeResponseSubmission] {
        return Iter.toArray(Iter.filter(submissionsStorage.vals(), func(submission: Types.ChallengeResponseSubmission) : Bool {
            if (verifyChallenge(#Open, submission.challengeId)) {
                switch (submission.submissionStatus) {
                case (#Submitted) { return true };
                case (_) { return false };
                }
            };
            return false;
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

    public shared query (msg) func getOpenSubmissionsForOpenChallengesAdmin() : async Types.ChallengeResponseSubmissionsResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let openSubmissions : [Types.ChallengeResponseSubmission] = getOpenSubmissionsForOpenChallenges();
        return #Ok(openSubmissions);
    };

    public shared query (msg) func getNumOpenSubmissionsForOpenChallengesAdmin() : async Types.NatResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let openSubmissions : [Types.ChallengeResponseSubmission] = getOpenSubmissionsForOpenChallenges();
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
    let DEFAULT_REWARD_PER_CHALLENGE : Types.RewardPerChallenge = {
        rewardType : Types.RewardType = #MainerToken;
        totalAmount : Nat = 1000000;
        winnerAmount : Nat = 350000;
        secondPlaceAmount : Nat = 150000;
        thirdPlaceAmount : Nat = 50000;
        amountForAllParticipants : Nat = 450000;
    };

    stable var rewardPerChallenge : Types.RewardPerChallenge = DEFAULT_REWARD_PER_CHALLENGE;

    // TODO - Implementation: keep a history of the reward changes
    public shared (msg) func setRewardPerChallengeAdmin(totalReward : Nat) : async Types.RewardPerChallengeResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let newRewards : Types.RewardPerChallenge = {
            rewardType : Types.RewardType = #MainerToken;
            totalAmount : Nat = totalReward;
            winnerAmount : Nat = totalReward * 35 / 100;
            secondPlaceAmount : Nat = totalReward * 15 / 100;
            thirdPlaceAmount : Nat = totalReward * 5 / 100;
            amountForAllParticipants : Nat = totalReward * 45 / 100;
        };
        rewardPerChallenge := newRewards;
        return #Ok(rewardPerChallenge);
    };

    private func getRewardAmountForResult(achievedResult : Types.ChallengeParticipationResult, totalNumberParticipants : Nat) : Nat { 
        // TODO - Implementation: is this safe? i.e. what could happen with rounding errors?
        let participationReward = rewardPerChallenge.amountForAllParticipants / totalNumberParticipants; 
        switch (achievedResult) {
            case (#Winner) { return rewardPerChallenge.winnerAmount + participationReward; };
            case (#SecondPlace) { return rewardPerChallenge.secondPlaceAmount + participationReward; };
            case (#ThirdPlace) { return rewardPerChallenge.thirdPlaceAmount + participationReward; };
            case (#Participated) { return participationReward; };
            case (_) { return 0; };
        };
    };

    private func getRewardForChallengeParticipant(challengeId : Text, achievedResult : Types.ChallengeParticipationResult, totalNumberParticipants : Nat) : Types.ChallengeWinnerReward { 
        var rewardAmount : Nat = getRewardAmountForResult(achievedResult, totalNumberParticipants);
        
        let participantReward : Types.ChallengeWinnerReward = {
            rewardType : Types.RewardType = rewardPerChallenge.rewardType;
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
                        // 2nd Place
                        let secondPlaceScoredResponseEntry : ?Types.ScoredResponse = sortedScoredResponsesIter.next();
                        switch (secondPlaceScoredResponseEntry) {
                            case (null) { return null };
                            case (?secondPlaceScoredResponse) {
                                let secondPlaceParticipantEntry : ?Types.ChallengeParticipantEntry = getParticipantEntryFromScoredResponse(secondPlaceScoredResponse, #SecondPlace, numberOfParticipants);
                                switch (secondPlaceParticipantEntry) {
                                    case (null) { return null };
                                    case (?secondPlaceParticipant) {
                                        // 3rd Place
                                        let thirdPlaceScoredResponseEntry : ?Types.ScoredResponse = sortedScoredResponsesIter.next();
                                        switch (thirdPlaceScoredResponseEntry) {
                                            case (null) { return null };
                                            case (?thirdPlaceScoredResponse) {
                                                let thirdPlaceParticipantEntry : ?Types.ChallengeParticipantEntry = getParticipantEntryFromScoredResponse(thirdPlaceScoredResponse, #ThirdPlace, numberOfParticipants);
                                                switch (thirdPlaceParticipantEntry) {
                                                    case (null) { return null };
                                                    case (?thirdPlaceParticipant) {
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
        // Ensure the CyclesFlows are set for Challenge Generation
        setCyclesFlow();

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
                cyclesGenerateChallengeGsChctrl : Nat = cyclesGenerateChallengeGsChctrl;
                cyclesGenerateChallengeChctrlChllm : Nat = cyclesGenerateChallengeChctrlChllm;
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
            cyclesGenerateChallengeGsChctrl : Nat = cyclesGenerateChallengeGsChctrl;
            cyclesGenerateChallengeChctrlChllm : Nat = cyclesGenerateChallengeChctrlChllm;
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

    // Functions for Admin to reset (delete all) current (open) challenges
    public shared (msg) func resetCurrentChallengesAdmin() : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        D.print("GameState: resetCurrentChallengesAdmin - entered");
        if (not resetOpenChallenges()){
            return #Err(#Other("An error occurred resetting the challenges"));
        };
        return #Ok({ status_code = 200 });
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
                        // First send cycles to the Challenger to pay for the challenge generation
                        let cyclesAdded = cyclesGenerateChallengeGsChctrl;
                        D.print("GameState: getRandomOpenChallengeTopic - calling Cycles.add for = " # debug_show(cyclesAdded) # " Cycles");
                        Cycles.add<system>(cyclesAdded);
                        try {
                            let deposit_cycles_args = { canister_id : Principal = msg.caller; };
                            let _ = await IC0.deposit_cycles(deposit_cycles_args);

                            D.print("GameState: getRandomOpenChallengeTopic - Successfully deposited " # debug_show(cyclesAdded) # " cycles to Challenger canister " # Principal.toText(msg.caller) );

                            // Now we can return the challenge topic
                            return #Ok(challengeTopic);  

                        } catch (e) {
                            D.print("GameState: getRandomOpenChallengeTopic - Failed to deposit " # debug_show(cyclesAdded) # " cycles to Challenger canister " # Principal.toText(msg.caller));
                            D.print("GameState: getRandomOpenChallengeTopic - Failed to deposit error is" # Error.message(e));

                            return #Err(#FailedOperation);
                        };    
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
                    cyclesGenerateChallengeGsChctrl : Nat = newChallenge.cyclesGenerateChallengeGsChctrl;
                    cyclesGenerateChallengeChctrlChllm : Nat = newChallenge.cyclesGenerateChallengeChctrlChllm;
                    challengeId : Text = challengeId;
                    challengeQuestion : Text = newChallenge.challengeQuestion;
                    challengeQuestionSeed : Nat32 = newChallenge.challengeQuestionSeed;
                    mainerPromptId : Text = newChallenge.mainerPromptId;
                    mainerMaxContinueLoopCount : Nat = newChallenge.mainerMaxContinueLoopCount;
                    mainerNumTokens : Nat64 = newChallenge.mainerNumTokens;
                    mainerTemp : Float = newChallenge.mainerTemp;
                    judgePromptId : Text = newChallenge.judgePromptId;
                    challengeCreationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                    challengeCreatedBy : Types.CanisterAddress = challengerEntry.address;
                    challengeStatus : Types.ChallengeStatus = #Open;
                    challengeClosedTimestamp : ?Nat64 = null;
                    cyclesSubmitResponse : Nat = cyclesSubmitResponse;
                    protocolOperationFeesCut : Nat = protocolOperationFeesCut;
                    cyclesGenerateResponseSactrlSsctrl : Nat = cyclesGenerateResponseSactrlSsctrl;
                    cyclesGenerateResponseSsctrlGs : Nat = cyclesGenerateResponseSsctrlGs;
                    cyclesGenerateResponseSsctrlSsllm : Nat = cyclesGenerateResponseSsctrlSsllm;
                    cyclesGenerateResponseOwnctrlGs : Nat = cyclesGenerateResponseOwnctrlGs;
                    cyclesGenerateResponseOwnctrlOwnllmLOW : Nat = cyclesGenerateResponseOwnctrlOwnllmLOW;
                    cyclesGenerateResponseOwnctrlOwnllmMEDIUM : Nat = cyclesGenerateResponseOwnctrlOwnllmMEDIUM;
                    cyclesGenerateResponseOwnctrlOwnllmHIGH : Nat = cyclesGenerateResponseOwnctrlOwnllmHIGH;
                };

                let putResult = putOpenChallenge(challengeId, challengeAdded);
                ignore increaseTotalProtocolCyclesBurnt(CYCLES_BURNT_CHALLENGE_CREATION);
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

    public shared (msg) func getSharedServiceCanistersAdmin() : async Types.OfficialProtocolCanistersResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let sharedServiceCanisters : [Types.OfficialProtocolCanister] = Iter.toArray(sharedServiceCanistersStorage.vals());
        return #Ok(sharedServiceCanisters);
    };

    public shared (msg) func removeSharedServiceCanisterAdmin( {canisterId : Text} ) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (removeSharedServiceCanister(canisterId)) {
            case (false) { return #Err(#Other("ShareService Canister ID not found: " # canisterId)); };
            case (true) { return #Ok({ status_code = 200 }); };
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
                    subnet : Text = canisterEntryToAdd.subnet;
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
                    subnet : Text = canisterEntryToAdd.subnet;
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
                    subnet : Text = canisterEntryToAdd.subnet;
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
                    subnet : Text = canisterEntryToAdd.subnet;
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
        ignore increaseTotalProtocolCyclesBurnt(CYCLES_BURNT_CANISTER_CREATION);
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
            address : Text = ""; // To be assigned (when Controller canister is created)
            subnet : Text = ""; // To be assigned (when Controller canister is created)
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

    // Helpers for payments
    stable var redeemedTransactionBlocksStorageStable : [(Nat, Types.RedeemedTransactionBlock)] = [];
    var redeemedTransactionBlocksStorage : HashMap.HashMap<Nat, Types.RedeemedTransactionBlock> = HashMap.HashMap(0, Nat.equal, Hash.hash);

    func checkExistingTransactionBlock(transactionBlock : Nat64) : Bool {
        switch (redeemedTransactionBlocksStorage.get(Nat64.toNat(transactionBlock))) {
            case (null) {
                return false;
            };
            case (?existingTransactionBlock) {
                return true;
            };
        };
    };

    private func putRedeemedTransactionBlock(transactionEntry : Types.RedeemedTransactionBlock) : Bool {
        switch (checkExistingTransactionBlock(transactionEntry.paymentTransactionBlockId)) {
            case (false) {
                // new entry
                redeemedTransactionBlocksStorage.put(Nat64.toNat(transactionEntry.paymentTransactionBlockId), transactionEntry);
                return true;
            };
            case (true) { 
                //existing entry
                return false;
            }; 
        };
    };

    // Function for Admin to get a RedeemedTransactionBlock in case something went wrong and it can then be retried
    public shared (msg) func getRedeemedTransactionBlockAdmin(paymentTransactionBlockId : Types.PaymentTransactionBlockId) : async Types.RedeemedTransactionBlockResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (redeemedTransactionBlocksStorage.get(Nat64.toNat(paymentTransactionBlockId.paymentTransactionBlockId))) {
            case (null) {
                return #Err(#Other("GameState: getRedeemedTransactionBlockAdmin - entry not found"));
            };
            case (?entry) {
                return #Ok(entry);
            };
        };
    };

    // Function for Admin to clear a RedeemedTransactionBlock in case something went wrong and it can then be retried
    public shared (msg) func removeRedeemedTransactionBlockAdmin(paymentTransactionBlockId : Types.PaymentTransactionBlockId) : async Types.TextResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        switch (redeemedTransactionBlocksStorage.remove(Nat64.toNat(paymentTransactionBlockId.paymentTransactionBlockId))) {
            case (null) {
                return #Err(#Other("GameState: getRedeemedTransactionBlockAdmin - entry not found"));
            };
            case (?entry) {
                // Remove the entry
                return #Ok("GameState: removeRedeemedTransactionBlock - Removed entry: " # debug_show(entry));
            };
        };
    };

    // Payment memo to specify in transaction to Protocol
    stable let MEMO_PAYMENT : Nat64 = 173; // TODO - Security: double check value can be used
    let PROTOCOL_PRINCIPAL_BLOB : Blob = Principal.toLedgerAccount(Principal.fromActor(this), null); // TODO - Implementation: this doesn't seem to fit the address on the ledger
    // Construct subaccount for the canister principal
    func principalToSubaccount(principal : Principal) : Blob {
        let sub = Buffer.Buffer<Nat8>(32);
        let subaccount_blob = Principal.toBlob(principal);

        sub.add(Nat8.fromNat(subaccount_blob.size()));
        sub.append(Buffer.fromArray<Nat8>(Blob.toArray(subaccount_blob)));
        while (sub.size() < 32) {
            sub.add(0);
        };

        Blob.fromArray(Buffer.toArray(sub));
    };
    let PROTOCOL_SUBACCOUNT : Blob = principalToSubaccount(Principal.fromActor(this));
    // e.g. this is for dev stage, verify with: https://dashboard.internetcomputer.org/account/c88ef9865df034927487e4178da1f80a1648ec5a764e4959cba513c372ceb520
    //let PROTOCOL_PRINCIPAL_BLOB : Blob = "\C8\8E\F9\86\5D\F0\34\92\74\87\E4\17\8D\A1\F8\0A\16\48\EC\5A\76\4E\49\59\CB\A5\13\C3\72\CE\B5\20";

    let PROTOCOL_CYCLES_BALANCE_BUFFER : Nat = 400 * Constants.CYCLES_TRILLION;

    // TODO - Implementation: new function to decide on usage of incoming funds (e.g. for mAIner creation or top ups)
    private func handleIncomingFunds(transactionEntry : Types.RedeemedTransactionBlock) : async Types.HandleIncomingFundsResult {
        D.print("GameState: handleIncomingFunds - transactionEntry: "# debug_show(transactionEntry));
        // TODO - Implementation: Calculate cut for Protocol's operational expenses (in ICP)
        D.print("GameState: handleIncomingFunds - protocolOperationFeesCut: "# debug_show(protocolOperationFeesCut));
        D.print("GameState: handleIncomingFunds - protocolOperationFeesCut / 100: "# debug_show(protocolOperationFeesCut / 100));
        var amountToKeep : Nat = transactionEntry.amount * protocolOperationFeesCut / 100; // TODO - Implementation: ensure this math operation works
        let amountForMainer : Nat = transactionEntry.amount - amountToKeep;
        var amountToConvert : Nat = 0;
        D.print("GameState: handleIncomingFunds - amountToKeep: "# debug_show(amountToKeep));
        D.print("GameState: handleIncomingFunds - amountForMainer: "# debug_show(amountForMainer));       
        // TODO - Implementation: if cycle balance > security buffer: take cycles from cycle balance
        switch (transactionEntry.redeemedFor) {
            case (#MainerCreation(#Own)) {
                D.print("GameState: handleIncomingFunds - #MainerCreation(#Own) PROTOCOL_CYCLES_BALANCE_BUFFER: "# debug_show(PROTOCOL_CYCLES_BALANCE_BUFFER)); 
                D.print("GameState: handleIncomingFunds - #MainerCreation(#Own) Cycles.balance(): "# debug_show(Cycles.balance())); 
                if (PROTOCOL_CYCLES_BALANCE_BUFFER > Cycles.balance()) {
                    // Cycles balance is lower than security threshold, so convert the payment's share for the mAIner to cycles
                    amountToConvert := amountForMainer;
                } else {
                    // No need to convert to cycles as cycle balance is high enough
                    amountToConvert := 0;
                };           
            };
            case (#MainerCreation(#ShareAgent)) {
                D.print("GameState: handleIncomingFunds - #MainerCreation(#ShareAgent) PROTOCOL_CYCLES_BALANCE_BUFFER: "# debug_show(PROTOCOL_CYCLES_BALANCE_BUFFER)); 
                D.print("GameState: handleIncomingFunds - #MainerCreation(#ShareAgent) Cycles.balance(): "# debug_show(Cycles.balance())); 
                if (PROTOCOL_CYCLES_BALANCE_BUFFER > Cycles.balance()) {
                    // Cycles balance is lower than security threshold, so convert the payment's share for the mAIner to cycles
                    amountToConvert := amountForMainer;
                } else {
                    // No need to convert to cycles as cycle balance is high enough
                    amountToConvert := 0;
                };
            };
            case (#MainerTopUp(mainerCanisterAddress)) {
                D.print("GameState: handleIncomingFunds - #MainerTopUp(mainerCanisterAddress): "# debug_show(mainerCanisterAddress)); 
                amountToConvert := amountForMainer; // Always convert mAIner's share of payment into cycles
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };
        D.print("GameState: handleIncomingFunds - amountToKeep: "# debug_show(amountToKeep));
        // TODO - Implementation: Convert amountToKeep to FUNNAI

        D.print("GameState: handleIncomingFunds - amountToConvert: "# debug_show(amountToConvert));
        if (amountToConvert > 0) {
            // Convert amountToConvert to cycles via Cycles Minting Canister (mint cycles to itself)
            // Send ICP to Cycles Minting Canister
            D.print("GameState: handleIncomingFunds - subaccount: "# debug_show(PROTOCOL_SUBACCOUNT));
            let cmcAccount : TokenLedger.Account = {
                owner : Principal = Principal.fromActor(CMC_ACTOR);
                subaccount : ?Blob = ?PROTOCOL_SUBACCOUNT; // needs to match canister to credit cycles to in notify_top_up call, thus this canister
            };
            let notifyTopUpMemo : ?Blob = ?"\54\50\55\50\00\00\00\00"; // TODO - Implementation: double check
            let transferArg : TokenLedger.TransferArg = {
                to : TokenLedger.Account = cmcAccount;
                fee : ?Nat = null;
                memo : ?Blob = notifyTopUpMemo; // needed for CMC to accept top up
                from_subaccount : ?Blob = null;
                created_at_time : ?Nat64 = null;
                amount : Nat = amountToConvert; // TODO: deduct transfer fee
            };
            let transferResult : TokenLedger.Result = await ICP_LEDGER_ACTOR.icrc1_transfer(transferArg);
            D.print("GameState: handleIncomingFunds - transferResult: "# debug_show(transferResult));
            switch (transferResult) {
                case (#Ok(transactionBlockId)) {
                    D.print("GameState: handleIncomingFunds - transferResult #Ok(transactionBlockId): "# debug_show(transactionBlockId));
                    // Then notify Cycles Minting Canister to credit the corresponding cycles to this canister
                    let notifyTopUpArg : CMC.NotifyTopUpArg = {
                        block_index : CMC.BlockIndex = Nat64.fromNat(transactionBlockId);
                        canister_id : Principal = Principal.fromActor(this); // Game State (Protocol); Note: cycles will be sent to mAIner via direct calls as part of dedicated functions (e.g. for creation or for top ups)
                    };
                    let notifyTopUpResult : CMC.NotifyTopUpResult = await CMC_ACTOR.notify_top_up(notifyTopUpArg);
                    D.print("GameState: handleIncomingFunds - transferResult #Ok(transactionBlockId) notifyTopUpResult: "# debug_show(notifyTopUpResult));
                    switch (notifyTopUpResult) {
                        case (#Ok(cyclesReceived)) {
                            D.print("GameState: handleIncomingFunds - transferResult #Ok(transactionBlockId) notifyTopUpResult cyclesReceived: "# debug_show(cyclesReceived));
                            var cyclesForMainer : Nat = cyclesReceived;
                            var cyclesForProtocol : Nat = 0; // Protocol already took its cut in ICP

                            // Sanity check
                            D.print("GameState: handleIncomingFunds - transferResult #Ok(transactionBlockId) notifyTopUpResult cyclesForMainer: "# debug_show(cyclesForMainer));
                            if (cyclesForMainer > cyclesReceived) {
                                // This should never happen
                                return #Err(#Other("cyclesForMainer > cyclesReceived"));                            
                            };

                            let response : Types.HandleIncomingFundsRecord = {
                                cyclesForProtocol: Nat = cyclesForProtocol;
                                cyclesForMainer : Nat = cyclesForMainer;
                            };
                            D.print("GameState: handleIncomingFunds - transferResult #Ok(transactionBlockId) notifyTopUpResult response: "# debug_show(response));
                            return #Ok(response);               
                        };
                        case (#Err(topUpError)) {
                            D.print("GameState: handleIncomingFunds - transferResult notifyTopUpResult #Err(topUpError): "# debug_show(topUpError));
                            return #Err(#Other("Error during CMC notify top up: " # debug_show(topUpError)));
                        };
                        case (_) { return #Err(#FailedOperation); }
                    };              
                };
                case (#Err(transferError)) {
                    D.print("GameState: handleIncomingFunds - transferResult #Err(transferError): "# debug_show(transferError));
                    return #Err(#Other("Error during ICP transfer: " # debug_show(transferError)));
                };
                case (_) { return #Err(#FailedOperation); }
            };
        } else {
            // TODO - Implementation: calculate the amount of cycles that the mAIner will get based on the payment
            D.print("GameState: handleIncomingFunds - no conversion necessary, calculate mAIner's cycles");
            // Call Cycles Minting Canister for cycles/ICP exchange rate            
            // First, get the ICP amount for the mAIner
            let icpAmount = amountForMainer;
            D.print("GameState: handleIncomingFunds - no conversion necessary, icpAmount: "# debug_show(icpAmount));
            // Query the CMC for the current conversion rate
            let queryResult : CMC.IcpXdrConversionRateResponse = await CMC_ACTOR.get_icp_xdr_conversion_rate();
            D.print("GameState: handleIncomingFunds - no conversion necessary, queryResult: "# debug_show(queryResult));
            // Extract the conversion rate
            let xdrPermyriadPerIcp = queryResult.data.xdr_permyriad_per_icp;
            D.print("GameState: handleIncomingFunds - no conversion necessary, xdrPermyriadPerIcp: "# debug_show(xdrPermyriadPerIcp));
            // Constants
            let CYCLES_PER_XDR : Nat = 1 * Constants.CYCLES_TRILLION; // 1 trillion cycles per XDR
            D.print("GameState: handleIncomingFunds - no conversion necessary, CYCLES_PER_XDR: "# debug_show(CYCLES_PER_XDR));
            let E8S_PER_ICP : Nat = 100_000_000; // 10^8 e8s per ICP
            // Calculate cycles
            let cycles : Nat = (icpAmount * Nat64.toNat(xdrPermyriadPerIcp) * CYCLES_PER_XDR) / (10_000 * E8S_PER_ICP); // Where 10_000 is to convert from permyriad (1/10000 of a unit)
            D.print("GameState: handleIncomingFunds - no conversion necessary, cycles: "# debug_show(cycles));
            
            let cyclesForMainer : Nat = cycles;
            let cyclesForProtocol : Nat = 0; // Protocol already took its cut in ICP
            
            D.print("GameState: handleIncomingFunds - no conversion necessary, cyclesForMainer: "# debug_show(cyclesForMainer));
            let response : Types.HandleIncomingFundsRecord = {
                cyclesForProtocol: Nat = cyclesForProtocol;
                cyclesForMainer : Nat = cyclesForMainer;
            };
            D.print("GameState: handleIncomingFunds - no conversion necessary, response: "# debug_show(response));
            return #Ok(response);  
        };
    };

    // TODO - Implementation: new function to verify a payment to the Protocol (e.g. for mAIner creation or top ups)
    private func verifyIncomingPayment(transactionEntry : Types.RedeemedTransactionBlock) : async Types.VerifyPaymentResult {
        // Memo to add to transaction?
        // Retrieve transaction from Ledger
            // https://dashboard.internetcomputer.org/canister/ryjl3-tyaaa-aaaaa-aaaba-cai
        let getBlocksArgs : TokenLedger.GetBlocksArgs = {
            start : Nat64 = transactionEntry.paymentTransactionBlockId;
            length : Nat64 = 1;
        };
        D.print("GameState: verifyIncomingPayment - getBlocksArgs: "# debug_show(getBlocksArgs));
        let queryBlocksResponse : TokenLedger.QueryBlocksResponse = await ICP_LEDGER_ACTOR.query_blocks(getBlocksArgs);
        D.print("GameState: verifyIncomingPayment - queryBlocksResponse.blocks: "# debug_show(queryBlocksResponse.blocks));
        // Verify transaction exists
        if (queryBlocksResponse.blocks.size() < 1) {
            return #Err(#InvalidId);
        };
        D.print("GameState: verifyIncomingPayment - queryBlocksResponse.blocks.size(): "# debug_show(queryBlocksResponse.blocks.size()));
        let retrievedTransaction : TokenLedger.CandidTransaction = queryBlocksResponse.blocks[0].transaction;
        D.print("GameState: verifyIncomingPayment - retrievedTransaction: "# debug_show(retrievedTransaction));
        // Verify transaction memo
        D.print("GameState: verifyIncomingPayment - retrievedTransaction.memo: "# debug_show(retrievedTransaction.memo));
        D.print("GameState: verifyIncomingPayment - MEMO_PAYMENT: "# debug_show(MEMO_PAYMENT));
        /* if (Nat64.notEqual(retrievedTransaction.memo, MEMO_PAYMENT)) {
            return #Err(#Other("Unsupported Memo"));
        }; */ // TODO - Implementation: check if needed
        // Verify transaction went to Protocol's account
        D.print("GameState: verifyIncomingPayment - retrievedTransaction.operation: "# debug_show(retrievedTransaction.operation));
        switch (retrievedTransaction.operation) {
            case (null) {
                D.print("GameState: verifyIncomingPayment - retrievedTransaction.operation: null");
                return #Err(#Other("Couldn't verify transaction operation details"));  
            };
            case (?transactionOperation) {
                D.print("GameState: verifyIncomingPayment - transactionOperation: "# debug_show(transactionOperation));
                switch (transactionOperation) {
                    case (#Transfer(transferDetails)) {
                        D.print("GameState: verifyIncomingPayment - #Transfer transferDetails: "# debug_show(transferDetails));
                        D.print("GameState: verifyIncomingPayment - transferDetails.to: "# debug_show(transferDetails.to));
                        D.print("GameState: verifyIncomingPayment - PROTOCOL_PRINCIPAL_BLOB: "# debug_show(PROTOCOL_PRINCIPAL_BLOB));
                        D.print("GameState: verifyIncomingPayment - toLedgerAccount: "# debug_show(Principal.toLedgerAccount(Principal.fromActor(this), null)));
                        if (Blob.notEqual(transferDetails.to, PROTOCOL_PRINCIPAL_BLOB)) {
                            return #Err(#Other("Transaction didn't go to Protocol's address")); 
                        };
                        // TODO - Implementation: ensure that paid amount equals price
                        D.print("GameState: verifyIncomingPayment - transactionEntry.redeemedFor: "# debug_show(transactionEntry.redeemedFor));
                        switch (transactionEntry.redeemedFor) {
                            case (#MainerCreation(mainerAgentCanisterType)) {
                                D.print("GameState: verifyIncomingPayment - #MainerCreation mainerAgentCanisterType: "# debug_show(mainerAgentCanisterType));
                                switch (mainerAgentCanisterType) {
                                    case (#Own) {
                                        D.print("GameState: verifyIncomingPayment - #MainerCreation Own transferDetails.amount.e8s: "# debug_show(transferDetails.amount.e8s));
                                        D.print("GameState: verifyIncomingPayment - #MainerCreation Own PRICE_OWN_MAINER: "# debug_show(PRICE_FOR_OWN_MAINER_ICP));
                                        if (transferDetails.amount.e8s < PRICE_FOR_OWN_MAINER_ICP) {
                                            return #Err(#Other("Transaction didn't pay full price"));
                                        };                              
                                    };
                                    case (#ShareAgent) {
                                        D.print("GameState: verifyIncomingPayment - #MainerCreation ShareAgent transferDetails.amount.e8s: "# debug_show(transferDetails.amount.e8s));
                                        D.print("GameState: verifyIncomingPayment - #MainerCreation ShareAgent PRICE_SHARED_MAINER: "# debug_show(PRICE_FOR_SHARE_AGENT_ICP));
                                        if (transferDetails.amount.e8s < PRICE_FOR_SHARE_AGENT_ICP) {
                                            return #Err(#Other("Transaction didn't pay full price"));
                                        };                                
                                    };
                                    case (_) { return #Err(#Other("Unsupported")); }
                                };                             
                            };
                            case (#MainerTopUp(_)) {
                                D.print("GameState: verifyIncomingPayment - #MainerTopUp ");
                                // continue as there is no fixed price                             
                            };
                            case (_) { return #Err(#Other("Unsupported")); }
                        };
                        D.print("GameState: verifyIncomingPayment - verified: ");
                        let amountPaid = Nat64.toNat(transferDetails.amount.e8s);
                        D.print("GameState: verifyIncomingPayment - amountPaid: "# debug_show(amountPaid));
                        return #Ok({
                            amountPaid : Nat = amountPaid;
                            verified : Bool = true;
                        });
                    };
                    case (_) { return #Err(#Other("Transaction wasn't sent correctly")); }
                };
            };
        };
    };

    // Function for user or Admin to create a new mAIner agent
    public shared (msg) func createUserMainerAgent(mainerCreationInput : Types.MainerCreationInput) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let transactionToVerify = mainerCreationInput.paymentTransactionBlockId;
        D.print("GameState: createUserMainerAgent - transactionToVerify: "# debug_show(transactionToVerify));

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
                // TODO - Implementation: ensure this transaction block hasn't been redeemed yet (no double spending)
                switch (checkExistingTransactionBlock(transactionToVerify)) {
                    case (false) {
                        // new transaction, continue
                    };
                    case (true) {
                        // already redeem transaction
                        return #Err(#Other("Already redeemd this paymentTransactionBlockId " # debug_show(transactionToVerify) )); // no double spending
                    };
                };
            };
            case (#ShareAgent) {
                switch (checkExistingTransactionBlock(transactionToVerify)) {
                    case (false) {
                        // new transaction, continue
                    };
                    case (true) {
                        // already redeem transaction
                        return #Err(#Other("Already redeemd this paymentTransactionBlockId " # debug_show(transactionToVerify) )); // no double spending
                    };
                };
            };
            case (#ShareService) {
                // Only a controller is allowed to create a shared service canister
                if (not Principal.isController(msg.caller)) {
                    return #Err(#Unauthorized);
                };
            };
            case (_) { return #Err(#Other("Unsupported")); }
        };

        D.print("GameState: createUserMainerAgent - mainerConfig: "# debug_show(mainerConfig));

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

        // TODO - Implementation: verify user's payment for this agent via the TransactionBlockId
        var verifiedPayment : Bool = false;
        var amountPaid : Nat = 0;
        let redeemedFor : Types.RedeemedForOptions = #MainerCreation(mainerConfig.mainerAgentCanisterType);
        let creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
        var continueForAdminWithoutPaymentVerification : Bool = false;
        // TODO - Testing: comment out this switch statement for testing locally
        switch (mainerConfig.mainerAgentCanisterType) {
            case (#ShareService) {
                // Skip payment verification in case of ShareService, which is created by an Admin (Controller)
                if (not Principal.isController(msg.caller)) {
                    return #Err(#Unauthorized);
                };
                verifiedPayment := true;
            };
            case (_) {
                let transactionEntryToVerify : Types.RedeemedTransactionBlock = {
                    paymentTransactionBlockId : Nat64 = transactionToVerify;
                    creationTimestamp : Nat64 = creationTimestamp;
                    redeemedBy : Principal = msg.caller;
                    redeemedFor : Types.RedeemedForOptions = redeemedFor;
                    amount : Nat = amountPaid; // to be updated
                };
                D.print("GameState: createUserMainerAgent - transactionEntryToVerify: "# debug_show(transactionEntryToVerify));

                let verificationResponse = await verifyIncomingPayment(transactionEntryToVerify);
                D.print("GameState: createUserMainerAgent - verificationResponse: "# debug_show(verificationResponse));
                switch (verificationResponse) {
                    case (#Ok(verificationResult)) {
                        verifiedPayment := verificationResult.verified;
                        amountPaid := verificationResult.amountPaid;
                    };
                    case (_) {
                        // TODO - Outcomment this for testing without actual ICP payment
                        if (Principal.isController(msg.caller)) {
                            verifiedPayment := true; 
                            amountPaid := 6 * Constants.CYCLES_TRILLION; // #own needs this much... TODO: amount is in ICP, not cycles
                            continueForAdminWithoutPaymentVerification := true; // continue with creation
                            D.print("GameState: createUserMainerAgent - Payment verification failed, but since caller is Admin (controller), we will continue with creation");
                        } else {
                            return #Err(#Other("Payment verification failed")); 
                        };
                    };
                };
            };
        };

        if (not verifiedPayment) {
            return #Err(#Other("Payment couldn't be verified"));
        }; // TODO - Testing: comment out this check for testing locally

        var handleResponse : Types.HandleIncomingFundsResult = #Err(#FailedOperation);
        switch (mainerConfig.mainerAgentCanisterType) {
            case (#ShareService) {
                // Skip handling of funds in case of ShareService, which is created by an Admin (Controller)
                // We do need a value for cyclesForMainer, because it is used by the creation process
                if (not Principal.isController(msg.caller)) {
                    D.print("GameState: createUserMainerAgent - ERROR: Not a controller. Only controllers can create a ShareService.");
                    return #Err(#Unauthorized);
                };
                let cyclesForMainer = cyclesCreateMainerLlmTargetBalance  + costCreateMainerLlm + 
                                      costCreateMcMainerLlm + costCreateMainerCtrl + 
                                      cyclesCreateMainerMarginGs + cyclesCreatemMainerMarginMc + 1 * Constants.CYCLES_MILLION; // 1M for calculation buffer
                handleResponse := #Ok({cyclesForMainer : Nat = cyclesForMainer; cyclesForProtocol : Nat = 0});
            };
            case (_) {
                D.print("GameState: createUserMainerAgent - mainerConfig.mainerAgentCanisterType: "# debug_show(mainerConfig.mainerAgentCanisterType));
                if (Principal.isController(msg.caller) and continueForAdminWithoutPaymentVerification) {
                    D.print("GameState: createUserMainerAgent - continueForAdminWithoutPaymentVerification: true");
                    handleResponse := #Ok({cyclesForMainer : Nat = amountPaid; cyclesForProtocol : Nat = 0});
                } else {
                    let transactionEntry : Types.RedeemedTransactionBlock = {
                        paymentTransactionBlockId : Nat64 = transactionToVerify;
                        creationTimestamp : Nat64 = creationTimestamp;
                        redeemedBy : Principal = msg.caller;
                        redeemedFor : Types.RedeemedForOptions = redeemedFor;
                        amount : Nat = amountPaid;
                    };
                    handleResponse := await handleIncomingFunds(transactionEntry);
                };
            };
        };
        D.print("GameState: createUserMainerAgent - handleResponse: "# debug_show(handleResponse));

        switch (handleResponse) {
            case (#Err(error)) {
                return #Err(#FailedOperation);
            };
            case (#Ok(handleResult)) {
                let mainerSubnets = getMainerSubnets(mainerConfig.mainerAgentCanisterType); // the subnet where the mAIner Controller will be created
                let updatedMainerConfig : Types.MainerConfigurationInput = {
                    mainerAgentCanisterType: Types.MainerAgentCanisterType = mainerConfig.mainerAgentCanisterType;
                    selectedLLM : ?Types.SelectableMainerLLMs = mainerConfig.selectedLLM;
                    cyclesForMainer : Nat = handleResult.cyclesForMainer; // to be used by the creation process
                    subnetCtrl : Text = mainerSubnets.subnetCtrl; // the subnet where the mAIner Controller will be created
                    subnetLlm : Text = mainerSubnets.subnetLlm; // the subnet where the mAIner LLM will be created
                };
                let canisterEntry : Types.OfficialMainerAgentCanister = {
                    address : Text = ""; // To be assigned (when Controller canister is created)
                    subnet : Text = ""; // To be assigned (when Controller canister is created)
                    canisterType: Types.ProtocolCanisterType = #MainerAgent(mainerConfig.mainerAgentCanisterType);
                    creationTimestamp : Nat64 = creationTimestamp;
                    createdBy : Principal = msg.caller; // User (Admin (controller) in case of ShareService)
                    ownedBy : Principal = msg.caller; // User (Admin (controller) in case of ShareService)
                    status : Types.CanisterStatus = #Paid; // TODO - Implementation: add transaction id to status #Paid or introduce new field
                    mainerConfig : Types.MainerConfigurationInput = updatedMainerConfig;
                };
                let newTransactionEntry : Types.RedeemedTransactionBlock = {
                    paymentTransactionBlockId : Nat64 = transactionToVerify;
                    creationTimestamp : Nat64 = canisterEntry.creationTimestamp;
                    redeemedBy : Principal = msg.caller;
                    redeemedFor : Types.RedeemedForOptions = redeemedFor;
                    amount : Nat = amountPaid;
                };
                D.print("GameState: createUserMainerAgent - canisterEntry: "# debug_show(canisterEntry));
                switch (putUserMainerAgent(canisterEntry)) {
                    case (true) {
                        D.print("GameState: createUserMainerAgent - putUserMainerAgent: true");
                        // TODO - Implementation: track redeemed transaction blocks to ensure no double spending
                        switch (putRedeemedTransactionBlock(newTransactionEntry)) {
                            case (false) {
                                // TODO - Error Handling: likely retry
                                D.print("GameState: createUserMainerAgent - putRedeemedTransactionBlock: false");
                            };
                            case (true) {
                                // continue
                                D.print("GameState: createUserMainerAgent - putRedeemedTransactionBlock: true");
                            };
                        };
                        return #Ok(canisterEntry);
                    };
                    case (false) {
                        D.print("GameState: createUserMainerAgent - putUserMainerAgent: false");
                        // TODO - Error Handling: likely retry
                        return #Err(#FailedOperation);
                    }
                };
            };
        };
    };

    // Function for user to create a new mAIner agent Controller canister
    public shared (msg) func spinUpMainerControllerCanister(mainerInfo : Types.OfficialMainerAgentCanister) : async Types.MainerAgentCanisterResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        D.print("GameState: spinUpMainerControllerCanister - Entered with mainerInfo: "# debug_show(mainerInfo));

        // Sanity checks on mAIner info
        if (not Principal.equal(mainerInfo.ownedBy, msg.caller)) {
            // Only the same user may continue with the creation flow
            D.print("GameState: spinUpMainerControllerCanister - 01 ");
            return #Err(#Unauthorized);
        };
        if (mainerInfo.address != "") {
            // At this point, no canister should have been created, i.e. no canister address
            D.print("GameState: spinUpMainerControllerCanister - 02 ");
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
                D.print("GameState: spinUpMainerControllerCanister - 03 ");
                return #Err(#Unauthorized);
            };
            case (?userMainerEntries) {
                // Find entry by creationTimestamp as no Controller address exists yet
                switch (List.find<Types.OfficialMainerAgentCanister>(userMainerEntries, func(mainerEntry: Types.OfficialProtocolCanister) : Bool { mainerEntry.creationTimestamp == mainerInfo.creationTimestamp } )) {
                    case (null) {
                        D.print("GameState: spinUpMainerControllerCanister - 04 ");
                        return #Err(#InvalidId);
                    };
                    case (?userMainerEntry) {
                        D.print("GameState: spinUpMainerControllerCanister - Found userMainerEntry: "# debug_show(userMainerEntry));
                        // Sanity checks on userMainerEntry (i.e. info provided is correct and matches entry info)
                        if (userMainerEntry.address != "") {
                            // At this point, no canister should have been created, i.e. no canister address
                            D.print("GameState: spinUpMainerControllerCanister - 05 ");
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
                            case (_) { 
                                D.print("GameState: spinUpMainerControllerCanister - 06 ");
                                return #Err(#Other("Unsupported")); 
                            }
                        };
                        let temporaryEntry : Types.OfficialMainerAgentCanister = {
                            address : Text = userMainerEntry.address;
                            subnet : Text = userMainerEntry.subnet;
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
                                D.print("GameState: spinUpMainerControllerCanister - 07 ");
                                return #Err(#Unauthorized);
                            };
                            case (?mainerCreatorEntry) {
                                let creatorCanisterActor = actor(mainerCreatorEntry.address): Types.MainerCreator_Actor;

                                // Get the Shared Service canister entry if of type ShareAgent
                                var associatedCanisterAddress : ?Types.CanisterAddress = null;
                                var associatedCanisterSubnet : Text = "";
                                var mainerAgentCanisterType : Types.MainerAgentCanisterType = #ShareAgent;
                                switch (userMainerEntry.canisterType) {
                                    case (#MainerAgent(#Own)) {
                                        // continue
                                        mainerAgentCanisterType := #Own;
                                    };
                                    case (#MainerAgent(#ShareService)) {
                                        // continue
                                        mainerAgentCanisterType := #ShareService;
                                    };
                                    case (#MainerAgent(#ShareAgent)) {
                                        mainerAgentCanisterType := #ShareAgent;
                                        // if of type ShareAgent, the shareServiceCanisterAddress is provided from the Game State info and added here as associatedCanisterAddress
                                        switch (getNextSharedServiceCanisterEntry()) {
                                            case (null) {
                                                // This should never happen as it indicates there isn't any Shared mAIning Service canister registered here
                                                D.print("GameState: spinUpMainerControllerCanister - There is no Shared mAIning Service canister registered.");
                                                return #Err(#Unauthorized);
                                            };
                                            case (?sharedServiceEntry) {
                                                associatedCanisterAddress := ?sharedServiceEntry.address;
                                                associatedCanisterSubnet := sharedServiceEntry.subnet;
                                                try {
                                                    // Make sure the associated ShareService canister actually exists
                                                    let _ = Principal.fromText(sharedServiceEntry.address); // this will throw an error if it's not a valid canister address
                                                    let associatedControllerCanisterActor = actor (sharedServiceEntry.address) : Types.MainerAgentCtrlbCanister;
                                                    let healthResult = await associatedControllerCanisterActor.health();
                                                    D.print("GameState: spinUpMainerControllerCanister - Associated ShareService canister (" # sharedServiceEntry.address # ") healthResult " # debug_show (healthResult));
                                                    switch (healthResult) {
                                                        case (#Err(error)) {
                                                            return #Err(error);
                                                        };
                                                        case _ {
                                                            // all good, continue
                                                        };
                                                    };
                                                } catch (e) {
                                                    D.print("GameState: spinUpMainerControllerCanister -  failed to validate existence & health of associated ShareService canister: " # debug_show(sharedServiceEntry.address ) # " Error: " # Error.message(e) );
                                                    return #Err(#Other("GameState: spinUpMainerControllerCanister -  failed to validate existence & health of associated ShareService canister: " # debug_show(sharedServiceEntry.address ) #  " Error: " # Error.message(e)));
                                                };
                                            };
                                        };
                                    };
                                    case (_) { return #Err(#Other("Unsupported")); }
                                };

                                let cyclesCreateMainer : Types.CyclesCreateMainer = calculateCyclesCreateMainer(userMainerEntry.mainerConfig.cyclesForMainer, mainerAgentCanisterType);
                                
                                let canisterCreationInput : Types.CanisterCreationConfiguration = {
                                    canisterType : Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                    owner: Principal = userMainerEntry.ownedBy; // User
                                    associatedCanisterAddress : ?Types.CanisterAddress = associatedCanisterAddress; // null for #Own, shareServiceCanisterAddress for ShareAgent
                                    associatedCanisterSubnet : Text = associatedCanisterSubnet;
                                    mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                    userMainerEntryCreationTimestamp : Nat64 = userMainerEntry.creationTimestamp;
                                    userMainerEntryCanisterType : Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                    cyclesCreateMainerctrlGsMc : Nat = cyclesCreateMainer.cyclesCreateMainerctrlGsMc;
                                    cyclesCreateMainerllmGsMc : Nat = cyclesCreateMainer.cyclesCreateMainerllmGsMc;
                                    cyclesCreateMainerctrlMcMainerctrl : Nat = cyclesCreateMainer.cyclesCreateMainerctrlMcMainerctrl;
                                    cyclesCreateMainerllmMcMainerllm : Nat = cyclesCreateMainer.cyclesCreateMainerllmMcMainerllm;
                                };
                                
                                let cyclesAdded = cyclesCreateMainer.cyclesCreateMainerctrlGsMc;
                                D.print("GameState: spinUpMainerControllerCanister - calling Cycles.add for = " # debug_show(cyclesAdded) # " Cycles");
                                Cycles.add<system>(cyclesAdded);

                                D.print("GameState: spinUpMainerControllerCanister - calling creatorCanisterActor.createCanister with canisterCreationInput: "# debug_show(canisterCreationInput));
                                // This only creates the canister and returns:
                                // -> Use await, so we can return the controller's address to frontend
                                let result : Types.CanisterCreationResult = await creatorCanisterActor.createCanister(canisterCreationInput);
                                D.print("GameState: spinUpMainerControllerCanister - createCanister result: "# debug_show(result));

                                switch (result) {
                                    case (#Ok(canisterCreationRecord)) {

                                        // Setup the controller canister (install code & configurations)
                                        let setupCanisterInput : Types.SetupCanisterInput = {
                                            newCanisterId : Text = canisterCreationRecord.newCanisterId;
                                            subnet : Text = canisterCreationRecord.subnet;
                                            configurationInput : Types.CanisterCreationConfiguration = canisterCreationInput;
                                        };
                                        D.print("GameState: spinUpMainerControllerCanister - calling creatorCanisterActor.setupCanister with setupCanisterInput: " # debug_show(setupCanisterInput) );
                                        ignore creatorCanisterActor.setupCanister(setupCanisterInput);

                                        let canisterEntryToAdd : Types.OfficialMainerAgentCanister = {
                                            address : Text = canisterCreationRecord.newCanisterId; // New mAIner Controller canister's id
                                            subnet : Text = canisterCreationRecord.subnet; // New mAIner Controller canister's subnet
                                            canisterType: Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                            creationTimestamp : Nat64 = userMainerEntry.creationTimestamp;
                                            createdBy : Principal = Principal.fromText(mainerCreatorEntry.address); // mAIner Creator
                                            ownedBy : Principal = userMainerEntry.ownedBy; // User
                                            status : Types.CanisterStatus = #Running;
                                            mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                        };
                                        D.print("GameState: spinUpMainerControllerCanister - canisterEntryToAdd: " # debug_show(canisterEntryToAdd) );
                                        ignore increaseTotalProtocolCyclesBurnt(CYCLES_BURNT_MAINER_CREATION);
                                        addMainerAgentCanister_(canisterEntryToAdd);
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


    // Function for Admin to upgrade an existing mAIner agent controller
    public shared (msg) func upgradeMainerControllerAdmin(mainerctrlUpgradeInput : Types.MainerctrlUpgradeInput) : async Types.MainerAgentCanisterResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let canisterAddress : Text = mainerctrlUpgradeInput.canisterAddress;
        D.print("GameState: upgradeMainerControllerAdmin - canister to upgrade: " # canisterAddress);

        switch (getMainerAgentCanister(canisterAddress)) {
            case (null) { 
                D.print("GameState: upgradeMainerControllerAdmin - ERROR: canister to upgrade is not found: " # canisterAddress);
                return #Err(#Other("Canister to upgrade is not found: " # canisterAddress )); 
            };
            case (?mainerAgentEntry) {
                // Forward upgrade request to mAIner Creator canister
                switch (getNextMainerCreatorCanisterEntry()) {
                    case (null) {
                        // This should never happen as it indicates there isn't any mAIner Creator canister registered here
                        D.print("GameState: upgradeMainerControllerAdmin - No mAIner Creator canister registered.");
                        return #Err(#Unauthorized);
                    };
                    case (?mainerCreatorEntry) {
                        let creatorCanisterActor = actor(mainerCreatorEntry.address): Types.MainerCreator_Actor;

                        // Get the Shared Service canister entry if of type ShareAgent
                        var associatedCanisterAddress : ?Types.CanisterAddress = null;
                        var associatedCanisterSubnet : Text = "";
                        var mainerAgentCanisterType : Types.MainerAgentCanisterType = #ShareAgent;
                        switch (mainerAgentEntry.canisterType) {
                            case (#MainerAgent(#Own)) {
                                // continue
                                mainerAgentCanisterType := #Own;
                            };
                            case (#MainerAgent(#ShareService)) {
                                // continue
                                mainerAgentCanisterType := #ShareService;
                            };
                            case (#MainerAgent(#ShareAgent)) {
                                mainerAgentCanisterType := #ShareAgent;
                                // if of type ShareAgent, the shareServiceCanisterAddress is provided from the Game State info and added here as associatedCanisterAddress
                                switch (getNextSharedServiceCanisterEntry()) {
                                    case (null) {
                                        // This should never happen as it indicates there isn't any Shared mAIning Service canister registered here
                                        D.print("GameState: upgradeMainerControllerAdmin - There is no Shared mAIning Service canister registered.");
                                        return #Err(#Unauthorized);
                                    };
                                    case (?sharedServiceEntry) {
                                        associatedCanisterAddress := ?sharedServiceEntry.address;
                                        associatedCanisterSubnet := sharedServiceEntry.subnet;
                                        try {
                                            // Make sure the associated ShareService canister actually exists
                                            let _ = Principal.fromText(sharedServiceEntry.address); // this will throw an error if it's not a valid canister address
                                            let associatedControllerCanisterActor = actor (sharedServiceEntry.address) : Types.MainerAgentCtrlbCanister;
                                            let healthResult = await associatedControllerCanisterActor.health();
                                            D.print("GameState: upgradeMainerControllerAdmin - Associated ShareService (" # sharedServiceEntry.address # ") canister healthResult" # debug_show (healthResult));
                                            switch (healthResult) {
                                                case (#Err(error)) {
                                                    return #Err(error);
                                                };
                                                case _ {
                                                    // all good, continue
                                                };
                                            };
                                        } catch (e) {
                                            D.print("GameState: upgradeMainerControllerAdmin -  failed to validate existence & health of associated ShareService canister: " # debug_show(sharedServiceEntry.address ) # " Error: " # Error.message(e) );
                                            return #Err(#Other("GameState: upgradeMainerControllerAdmin -  failed to validate existence & health of associated ShareService canister: " # debug_show(sharedServiceEntry.address ) #  " Error: " # Error.message(e)));
                                        };
                                    };
                                };
                            };
                            case (_) { return #Err(#Other("Unsupported")); }
                        };

                        let cyclesAdded = cyclesUpgradeMainerctrlGsMc;
                        D.print("GameState: upgradeMainerControllerAdmin - calling Cycles.add for = " # debug_show(cyclesAdded) # " Cycles");
                        Cycles.add<system>(cyclesAdded);

                        let upgradeMainerctrlInput : Types.UpgradeMainerctrlInput = {
                            mainerAgentEntry : Types.OfficialMainerAgentCanister = mainerAgentEntry; // Canister to upgrade
                            associatedCanisterAddress : ?Types.CanisterAddress = associatedCanisterAddress; // null for #Own, shareServiceCanisterAddress for ShareAgent
                            associatedCanisterSubnet : Text = associatedCanisterSubnet;
                            cyclesUpgradeMainerctrlGsMc : Nat = cyclesUpgradeMainerctrlGsMc;
                            cyclesUpgradeMainerctrlMcMainerctrl : Nat = cyclesUpgradeMainerctrlMcMainerctrl;
                        };
                        D.print("GameState: upgradeMainerControllerAdmin - calling creatorCanisterActor.upgradeMainerctrl with canisterCreationInput: " # debug_show(upgradeMainerctrlInput) );
                        ignore creatorCanisterActor.upgradeMainerctrl(upgradeMainerctrlInput);

                        // Update the status of the mAIner agent entry to indicate that the upgrade is in progress
                        let canisterEntryToAdd : Types.OfficialMainerAgentCanister = {
                            address : Text = mainerAgentEntry.address; 
                            subnet : Text = mainerAgentEntry.subnet; 
                            canisterType: Types.ProtocolCanisterType = mainerAgentEntry.canisterType;
                            creationTimestamp : Nat64 = mainerAgentEntry.creationTimestamp;
                            createdBy : Principal = mainerAgentEntry.createdBy; 
                            ownedBy : Principal = mainerAgentEntry.ownedBy;
                            status : Types.CanisterStatus = #Other("Controller Upgrade in Progress");
                            mainerConfig : Types.MainerConfigurationInput = mainerAgentEntry.mainerConfig;
                        };
                        D.print("GameState: upgradeMainerControllerAdmin - canisterEntryToAdd: " # debug_show(canisterEntryToAdd) );
                        // ignore increaseTotalProtocolCyclesBurnt(CYCLES_BURNT_MAINER_CREATION); // TODO
                        addMainerAgentCanister_(canisterEntryToAdd);            
                    };
                };
            };
        };
    };

    // Function for user to set up an LLM for a mAIner agent
    public shared (msg) func setUpMainerLlmCanister(mainerInfo : Types.OfficialMainerAgentCanister) : async Types.SetUpMainerLlmCanisterResult {
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
            case (#LlmSetupInProgress(_)) {
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
                        var mainerAgentCanisterType : Types.MainerAgentCanisterType = #Own;
                        switch (userMainerEntry.canisterType) {
                            case (#MainerAgent(#Own)) {
                                mainerAgentCanisterType := #Own;
                                // mAIners of type Own may have dedicated LLMs attached
                                // continue
                            };
                            case (#MainerAgent(#ShareService)) {
                                mainerAgentCanisterType := #ShareService;
                                // mAIners of type ShareService may have dedicated LLMs attached
                                // continue
                            };
                            case (_) { 
                                D.print("GameState: setUpMainerLlmCanister - Unsupported userMainerEntry.canisterType: " # debug_show(userMainerEntry.canisterType) );
                                return #Err(#Other("Unsupported")); 
                            }
                        };
                        // TODO: These checks are dangerous.
                        // for example, if something went wrong with setup of LLM before, the status may be set to #LlmSetupInProgress(#CanisterCreated)
                        // and we are not able to add an LLM canister -> the controller is stuck
                        switch (userMainerEntry.status) {
                            case (#ControllerCreated) {
                                // continue
                            };
                            case (#LlmSetupInProgress(_)) {
                                // indicates a retry
                                // continue
                            };
                            case (_) { 
                                D.print("GameState: setUpMainerLlmCanister - Unsupported userMainerEntry.status: " # debug_show(userMainerEntry.status) );
                                return #Err(#Other("Unsupported userMainerEntry.status: " # debug_show(userMainerEntry.status))); 
                            }
                        };

                        // ------------------------------------------------------
                        // Update status of the controller (usermAInerEntry) to LlmSetupInProgress
                        let temporaryEntry : Types.OfficialMainerAgentCanister = {
                            address : Text = userMainerEntry.address;
                            subnet : Text = userMainerEntry.subnet;
                            canisterType: Types.ProtocolCanisterType = userMainerEntry.canisterType;
                            creationTimestamp : Nat64 = userMainerEntry.creationTimestamp; // for deduplication by putUserMainerAgent
                            createdBy : Principal = userMainerEntry.createdBy;
                            ownedBy : Principal = userMainerEntry.ownedBy;
                            status : Types.CanisterStatus = #LlmSetupInProgress(#CanisterCreationInProgress); // only field updated
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
                                
                                let cyclesCreateMainer : Types.CyclesCreateMainer = calculateCyclesCreateMainer(userMainerEntry.mainerConfig.cyclesForMainer, mainerAgentCanisterType);
                                
                                let canisterCreationInput : Types.CanisterCreationConfiguration = {
                                    canisterType : Types.ProtocolCanisterType = #MainerLlm;
                                    owner: Principal = userMainerEntry.ownedBy; // User
                                    associatedCanisterAddress : ?Types.CanisterAddress = ?userMainerEntry.address; // Controller address
                                    associatedCanisterSubnet : Text = userMainerEntry.subnet; // Controller subnet
                                    mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                    userMainerEntryCreationTimestamp : Nat64 = userMainerEntry.creationTimestamp; // Controller
                                    userMainerEntryCanisterType : Types.ProtocolCanisterType = userMainerEntry.canisterType; // Controller
                                    cyclesCreateMainerctrlGsMc : Nat = cyclesCreateMainer.cyclesCreateMainerctrlGsMc;
                                    cyclesCreateMainerllmGsMc : Nat = cyclesCreateMainer.cyclesCreateMainerllmGsMc;
                                    cyclesCreateMainerctrlMcMainerctrl : Nat = cyclesCreateMainer.cyclesCreateMainerctrlMcMainerctrl;
                                    cyclesCreateMainerllmMcMainerllm : Nat = cyclesCreateMainer.cyclesCreateMainerllmMcMainerllm;
                                };

                                let cyclesAdded = cyclesCreateMainer.cyclesCreateMainerllmGsMc; 
                                D.print("GameState: setUpMainerLlmCanister - calling Cycles.add for = " # debug_show(cyclesAdded) # " Cycles");
                                Cycles.add<system>(cyclesAdded);
                                
                                D.print("GameState: setUpMainerLlmCanister - calling creatorCanisterActor.createCanister with canisterCreationInput: "# debug_show(canisterCreationInput));
                                // This only creates the LLM canister and returns
                                let result : Types.CanisterCreationResult = await creatorCanisterActor.createCanister(canisterCreationInput);
                                D.print("GameState: setUpMainerLlmCanister - createCanister returned " # debug_show(result) );

                                switch (result) {
                                    case (#Ok(canisterCreationRecord)) {
                                        
                                        // Setup the LLM canister (install code & configurations)
                                        let setupCanisterInput : Types.SetupCanisterInput = {
                                            newCanisterId : Text = canisterCreationRecord.newCanisterId;
                                            subnet : Text = canisterCreationRecord.subnet;
                                            configurationInput : Types.CanisterCreationConfiguration = canisterCreationInput;
                                        };
                                        D.print("GameState: setUpMainerLlmCanister - calling creatorCanisterActor.setupCanister with setupCanisterInput: " # debug_show(setupCanisterInput) );
                                        ignore creatorCanisterActor.setupCanister(setupCanisterInput);

                                        let canisterEntryToAdd : Types.OfficialMainerAgentCanister = {
                                            address : Text = userMainerEntry.address; // Controller 
                                            subnet : Text = userMainerEntry.subnet;
                                            canisterType: Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                            creationTimestamp : Nat64 = userMainerEntry.creationTimestamp;
                                            createdBy : Principal = Principal.fromText(mainerCreatorEntry.address); // mAIner Creator
                                            ownedBy : Principal = userMainerEntry.ownedBy; // User
                                            status : Types.CanisterStatus = #LlmSetupInProgress(#CanisterCreated); //This is status of the controller
                                            mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                        };
                                        D.print("GameState: setUpMainerLlmCanister - returning canisterEntryToAdd: " # debug_show(canisterEntryToAdd) );
                                        ignore increaseTotalProtocolCyclesBurnt(CYCLES_BURNT_LLM_CREATION);
                                        let _ = addMainerAgentCanister_(canisterEntryToAdd);
                                        return #Ok(
                                            {
                                            llmCanisterId : Text = canisterCreationRecord.newCanisterId;
                                            controllerCanisterEntry : Types.OfficialMainerAgentCanister = canisterEntryToAdd;
                                            }
                                        );
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
    public shared (msg) func addLlmCanisterToMainer(mainerInfo : Types.OfficialMainerAgentCanister) : async Types.SetUpMainerLlmCanisterResult {
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
            case (_) { 
                D.print("GameState: addLlmCanisterToMainer - Unsupported mainerInfo.canisterType: " # debug_show(mainerInfo.canisterType) );
                return #Err(#Other("Unsupported")); 
            }
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
            case (_) { 
                D.print("GameState: addLlmCanisterToMainer - Unsupported mainerInfo.status: " # debug_show(mainerInfo.status) );
                return #Err(#Other("Unsupported")); 
            }
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
                        var mainerAgentCanisterType : Types.MainerAgentCanisterType = #Own;
                        switch (userMainerEntry.canisterType) {
                            case (#MainerAgent(#Own)) {
                                mainerAgentCanisterType := #Own;
                                // mAIners of type Own may have dedicated LLMs attached
                                // continue
                            };
                            case (#MainerAgent(#ShareService)) {
                                mainerAgentCanisterType := #ShareService;
                                // mAIners of type ShareService may have dedicated LLMs attached
                                // continue
                            };
                            case (_) { 
                                D.print("GameState: addLlmCanisterToMainer - Unsupported mAIner type: " # debug_show(userMainerEntry.canisterType) );   
                                return #Err(#Other("Unsupported mAIner type: " # debug_show(userMainerEntry.canisterType))); }
                        };
                        // TODO: These checks are dangerous.
                        // for example, if something went wrong with setup of LLM before, the status may be set to #LlmSetupInProgress(#CanisterCreated)
                        // and we are not able to add an LLM canister -> the controller is stuck
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
                                return #Err(#Other("Unsupported userMainerEntry.status: " # debug_show(userMainerEntry.status))); }
                        };

                        let temporaryEntry : Types.OfficialMainerAgentCanister = {
                            address : Text = userMainerEntry.address;
                            subnet : Text = userMainerEntry.subnet;
                            canisterType: Types.ProtocolCanisterType = userMainerEntry.canisterType;
                            creationTimestamp : Nat64 = userMainerEntry.creationTimestamp; // for deduplication by putUserMainerAgent
                            createdBy : Principal = userMainerEntry.createdBy;
                            ownedBy : Principal = userMainerEntry.ownedBy;
                            status : Types.CanisterStatus = #LlmSetupInProgress(#CanisterCreated); //This is status of the controller -- createCanister updates status via callback
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

                                let cyclesCreateMainer : Types.CyclesCreateMainer = calculateCyclesCreateMainer(userMainerEntry.mainerConfig.cyclesForMainer, mainerAgentCanisterType);
                                
                                let canisterCreationInput : Types.CanisterCreationConfiguration = {
                                    canisterType : Types.ProtocolCanisterType = #MainerLlm;
                                    owner: Principal = userMainerEntry.ownedBy; // User
                                    associatedCanisterAddress : ?Types.CanisterAddress = ?userMainerEntry.address; // Controller address
                                    associatedCanisterSubnet : Text = userMainerEntry.subnet; // Controller subnet
                                    mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                    userMainerEntryCreationTimestamp : Nat64 = userMainerEntry.creationTimestamp; // for deduplication by putUserMainerAgent
                                    userMainerEntryCanisterType : Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                    cyclesCreateMainerctrlGsMc : Nat = cyclesCreateMainer.cyclesCreateMainerctrlGsMc;
                                    cyclesCreateMainerllmGsMc : Nat = cyclesCreateMainer.cyclesCreateMainerllmGsMc;
                                    cyclesCreateMainerctrlMcMainerctrl : Nat = cyclesCreateMainer.cyclesCreateMainerctrlMcMainerctrl;
                                    cyclesCreateMainerllmMcMainerllm : Nat = cyclesCreateMainer.cyclesCreateMainerllmMcMainerllm;
                                };
                                
                                let cyclesAdded = cyclesCreateMainer.cyclesCreateMainerllmGsMc;
                                D.print("GameState: addLlmCanisterToMainer - calling Cycles.add for = " # debug_show(cyclesAdded) # " Cycles");
                                Cycles.add<system>(cyclesAdded);
                                
                                D.print("GameState: addLlmCanisterToMainer - calling creatorCanisterActor.createCanister with canisterCreationInput: " # debug_show(canisterCreationInput));
                                // This only creates the LLM canister and returns
                                let result : Types.CanisterCreationResult = await creatorCanisterActor.createCanister(canisterCreationInput);
                                D.print("GameState: addLlmCanisterToMainer - createCanister returned " # debug_show(result) );

                                switch (result) {
                                    case (#Ok(canisterCreationRecord)) {
                                        
                                        // Setup the LLM canister (install code & configurations)
                                        let setupCanisterInput : Types.SetupCanisterInput = {
                                            newCanisterId : Text = canisterCreationRecord.newCanisterId;
                                            subnet : Text = canisterCreationRecord.subnet;
                                            configurationInput : Types.CanisterCreationConfiguration = canisterCreationInput;
                                        };
                                        D.print("GameState: addLlmCanisterToMainer - calling creatorCanisterActor.setupCanister with setupCanisterInput: " # debug_show(setupCanisterInput) );
                                        ignore creatorCanisterActor.setupCanister(setupCanisterInput);

                                        let canisterEntryToAdd : Types.OfficialMainerAgentCanister = {
                                            address : Text = userMainerEntry.address; // Controller 
                                            subnet : Text = userMainerEntry.subnet;
                                            canisterType: Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                            creationTimestamp : Nat64 = userMainerEntry.creationTimestamp;
                                            createdBy : Principal = Principal.fromText(mainerCreatorEntry.address); // mAIner Creator
                                            ownedBy : Principal = userMainerEntry.ownedBy; // User
                                            status : Types.CanisterStatus = #LlmSetupInProgress(#CanisterCreated); //This is status of the controller
                                            mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                        };
                                        D.print("GameState: addLlmCanisterToMainer - returning canisterEntryToAdd: " # debug_show(canisterEntryToAdd) );  
                                        ignore increaseTotalProtocolCyclesBurnt(CYCLES_BURNT_LLM_CREATION);
                                        let _ = addMainerAgentCanister_(canisterEntryToAdd);
                                        return #Ok(
                                            {
                                            llmCanisterId : Text = canisterCreationRecord.newCanisterId;
                                            controllerCanisterEntry : Types.OfficialMainerAgentCanister = canisterEntryToAdd;
                                            }
                                        );
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

    // Public Function for mAIner Agent Creator canister to add new mAIner agent for user
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
                addMainerAgentCanister_(canisterEntryToAdd);
            };
        };
    };

    // Internal function to to add new mAIner agent for user
    private func addMainerAgentCanister_(canisterEntryToAdd : Types.OfficialMainerAgentCanister) : Types.MainerAgentCanisterResult {
        switch (canisterEntryToAdd.canisterType) {
            case (#MainerAgent(_)) {
                // continue
            };
            case (_) { 
                D.print("GameState: addMainerAgentCanister_ - Unsupported canisterEntryToAdd.canisterType: " # debug_show(canisterEntryToAdd.canisterType) );
                return #Err(#Other("Unsupported")); 
            }
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
        let _ = putUserMainerAgent(canisterEntry);
        let _ = putMainerAgentCanister(canisterEntryToAdd.address, canisterEntry);
        D.print("GameState: addMainerAgentCanister - putMainerAgentCanister for canisterEntry: " # debug_show(canisterEntry) );
        return #Ok(canisterEntry);
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
            subnet : Text = canisterEntryToAdd.subnet;
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

        // TODO - Implementation: ensure this transaction block hasn't been redeemed yet (no double spending)     
        let transactionToVerify = mainerTopUpInfo.paymentTransactionBlockId;
        switch (checkExistingTransactionBlock(transactionToVerify)) {
            case (false) {
                // new transaction, continue
            };
            case (true) {
                // already redeem transaction
                return #Err(#Other("Already redeemd this transaction block")); // no double spending
            };
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
            case (#LlmSetupInProgress(_)) {
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

                        // TODO - Implementation: verify user's payment for this agent via the TransactionBlockId
                        var verifiedPayment : Bool = false;
                        var amountPaid : Nat = 0;
                        let redeemedFor : Types.RedeemedForOptions = #MainerTopUp(userMainerEntry.address);
                        let creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                        let transactionEntryToVerify : Types.RedeemedTransactionBlock = {
                            paymentTransactionBlockId : Nat64 = mainerTopUpInfo.paymentTransactionBlockId;
                            creationTimestamp : Nat64 = creationTimestamp;
                            redeemedBy : Principal = msg.caller;
                            redeemedFor : Types.RedeemedForOptions = redeemedFor;
                            amount : Nat = amountPaid; // to be updated
                        };
                        let verificationResponse = await verifyIncomingPayment(transactionEntryToVerify);
                        switch (verificationResponse) {
                            case (#Ok(verificationResult)) {
                                verifiedPayment := verificationResult.verified;
                                amountPaid := verificationResult.amountPaid;
                            };
                            case (_) {
                                return #Err(#Other("Payment verification failed"));                      
                            };
                        };
                        if (not verifiedPayment) {
                            return #Err(#Other("Payment couldn't be verified"));
                        };

                        let newTransactionEntry : Types.RedeemedTransactionBlock = {
                            paymentTransactionBlockId : Nat64 = mainerTopUpInfo.paymentTransactionBlockId;
                            creationTimestamp : Nat64 = creationTimestamp;
                            redeemedBy : Principal = msg.caller;
                            redeemedFor : Types.RedeemedForOptions = redeemedFor;
                            amount : Nat = amountPaid;
                        };
                        let handleResponse : Types.HandleIncomingFundsResult = await handleIncomingFunds(newTransactionEntry);
                        D.print("GameState: topUpCyclesForMainerAgent - handleResponse: " # debug_show(handleResponse));
                        switch (handleResponse) {
                            case (#Err(error)) {
                                D.print("GameState: topUpCyclesForMainerAgent - handleResponse FailedOperation: " # debug_show(error));
                                return #Err(#FailedOperation);
                            };
                            case (#Ok(handleResult)) {
                                D.print("GameState: topUpCyclesForMainerAgent - handleResult: " # debug_show(handleResult));
                                // TODO - Implementation: credit mAIner agent with cycles (the user paid for)
                                try {
                                    let Mainer_Actor : Types.MainerAgentCtrlbCanister = actor (userMainerEntry.address);
                                    D.print("GameState: topUpCyclesForMainerAgent - calling Cycles.add for = " # debug_show(handleResult.cyclesForMainer) # " Cycles");
                                    Cycles.add<system>(handleResult.cyclesForMainer);
                                    
                                    D.print("GameState: topUpCyclesForMainerAgent - calling Mainer_Actor.addCycles");
                                    let addCyclesResponse = await Mainer_Actor.addCycles();
                                    D.print("GameState: topUpCyclesForMainerAgent - addCyclesResponse: " # debug_show(addCyclesResponse));
                                    switch (addCyclesResponse) {
                                        case (#Err(error)) {
                                            D.print("GameState: topUpCyclesForMainerAgent - addCyclesResponse FailedOperation: " # debug_show(error));
                                            return #Err(#FailedOperation);
                                        };
                                        case (#Ok(addCyclesResult)) {
                                            D.print("GameState: topUpCyclesForMainerAgent - addCyclesResult: " # debug_show(addCyclesResult));
                                            //TODO - Design: decide whether a top up history should be kept
                                            // TODO - Implementation: track redeemed transaction blocks to ensure no double spending
                                            switch (putRedeemedTransactionBlock(newTransactionEntry)) {
                                                case (false) {
                                                    // TODO - Error Handling: likely retry
                                                };
                                                case (true) {
                                                    // continue
                                                };
                                            };
                                            return #Ok(userMainerEntry);
                                        };
                                    };
                                } catch (e) {
                                    D.print("GameState: topUpCyclesForMainerAgent - Failed to credit cycles to mAIner: " # debug_show(mainerTopUpInfo) # Error.message(e));      
                                    return #Err(#Other("GameState: topUpCyclesForMainerAgent - Failed to credit cycles to mAIner: " # debug_show(mainerTopUpInfo) # Error.message(e)));
                                };
                            };
                        };                       
                    };
                };
            };
        };
    };

    // Function for user to get their mAIner agent canisters
    public shared query (msg) func getMainerAgentCanistersForUser() : async Types.MainerAgentCanistersResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };

        switch (getUserMainerAgents(msg.caller)) {
            case (null) { return #Err(#Other("No canisters for this caller")); };
            case (?userCanistersList) {
                return #Ok(List.toArray<Types.OfficialMainerAgentCanister>(userCanistersList));                              
            };
        };
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
                let openSubmissions : [Types.ChallengeResponseSubmission] = getOpenSubmissionsForOpenChallenges();
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
            let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
            D.print("GameState: submitChallengeResponse - 01 - kept cycles for failed submission: " # debug_show(_cyclesKeptForFailedSubmission) # " from caller " # Principal.toText(msg.caller));
            return #Err(#Unauthorized);
        };
        // Only official mAIner agent canisters may call this
        switch (getMainerAgentCanister(Principal.toText(msg.caller))) {
            case (null) {
                let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
                D.print("GameState: submitChallengeResponse - 03- kept cycles for failed submission: " # debug_show(_cyclesKeptForFailedSubmission) # " from caller " # Principal.toText(msg.caller));
                return #Err(#Unauthorized);
            };
            case (?_mainerAgentEntry) {
                // Check that submission record looks correct
                if (challengeResponseSubmissionInput.submittedBy != msg.caller) {
                    let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
                    D.print("GameState: submitChallengeResponse - 04 - kept cycles for failed submission: " # debug_show(_cyclesKeptForFailedSubmission) # " from caller " # Principal.toText(msg.caller));
                    return #Err(#Unauthorized);
                };

                // Verify that the mAIner is running the official wasm code (untampered)
                // Retrieve mAIner agent canister's info
                D.print("GameState: submitChallengeResponse - Verify agent canister's wasm module hash#####################################################################################################################################################################################");
                try {
                    let agentCanisterInfo = await IC0.canister_info({
                        canister_id = challengeResponseSubmissionInput.submittedBy;
                        num_requested_changes = ?0;
                    });   
                    // Verify agent canister's wasm module hash
                    switch (agentCanisterInfo.module_hash) {
                        case (null) {
                            let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
                            D.print("GameState: submitChallengeResponse - kept cycles for failed submission: " # debug_show(_cyclesKeptForFailedSubmission) # " from caller " # Principal.toText(msg.caller));
                            D.print("GameState: submitChallengeResponse - agentCanisterInfo with null as module hash: " # debug_show(agentCanisterInfo)); 
                            // TODO - Design: further measurements?
                            return #Err(#Unauthorized);
                        };
                        case (?agentModuleHash) {
                            if (Blob.equal(agentModuleHash, officialMainerAgentCanisterWasmHashRecord.wasmHash)) {
                                D.print("GameState: testMainerCodeIntegrityAdmin - agentCanisterInfo with official module hash: " # debug_show(agentCanisterInfo));
                                // continue as check passed
                            } else {
                                let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
                                D.print("GameState: submitChallengeResponse - kept cycles for failed submission: " # debug_show(_cyclesKeptForFailedSubmission) # " from caller " # Principal.toText(msg.caller));
                                D.print("GameState: submitChallengeResponse - agentCanisterInfo didn't pass verification: " # debug_show(agentCanisterInfo) # " - expected wasm hash = " # debug_show(officialMainerAgentCanisterWasmHash));
                                 
                                // TODO - Design: further measurements?
                                return #Err(#Unauthorized);
                            };
                        };
                    };
                } catch (e) {
                    let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
                    D.print("GameState: submitChallengeResponse - kept cycles for failed submission: " # debug_show(_cyclesKeptForFailedSubmission) # " from caller " # Principal.toText(msg.caller));
                    D.print("GameState: submitChallengeResponse - Failed to retrieve info for mAIner: " # debug_show(challengeResponseSubmissionInput) # Error.message(e));      
                    return #Err(#Other("GameState: testMainerCodeIntegrityAdmin - Failed to retrieve info for mAIner: " # debug_show(challengeResponseSubmissionInput) # Error.message(e)));
                };

                // Verify that challenge is open
                // Verify the cyclesSubmitResponse for this Challenge
                switch (getOpenChallenge(challengeResponseSubmissionInput.challengeId)) {
                    case (null) { 
                        let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
                        D.print("GameState: submitChallengeResponse - 05 - kept cycles for failed submission: " # debug_show(_cyclesKeptForFailedSubmission) # " from caller " # Principal.toText(msg.caller));
                        return #Err(#InvalidId);
                    };
                    case (?challengeEntry) {
                        // Verify that submission is charged with sufficient cycles for this Challenge
                        D.print("GameState: submitChallengeResponse - challengeEntry.cyclesSubmitResponse: " # debug_show(challengeEntry.cyclesSubmitResponse) # " Cycles");
                        D.print("GameState: submitChallengeResponse - Cycles available: " # debug_show(Cycles.available()));

                        if (Cycles.available() < challengeEntry.cyclesSubmitResponse) {
                            let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
                            D.print("GameState: submitChallengeResponse - 02- kept cycles for failed submission: " # debug_show(_cyclesKeptForFailedSubmission) # " from caller " # Principal.toText(msg.caller));
                            D.print("GameState: submitChallengeResponse - cycles available: " # debug_show(Cycles.available()));
                            D.print("GameState: submitChallengeResponse - cycles required : " # debug_show(challengeEntry.cyclesSubmitResponse));
                            return #Err(#InsuffientCycles(challengeEntry.cyclesSubmitResponse));                    
                        };

                        // Accept cycles for submission (submission fee plus any outstanding fees, e.g. cuts from unofficial top ups for Protocol's operational expenses)
                        let cyclesAcceptedForSubmission = Cycles.accept<system>(Cycles.available());
                        D.print("GameState: submitChallengeResponse - Accepting cycles for successful submission: " # debug_show(cyclesAcceptedForSubmission) # " from caller " # Principal.toText(msg.caller));
                        if (cyclesAcceptedForSubmission < challengeEntry.cyclesSubmitResponse) {
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
                            submissionId : Text = submissionId;
                            submittedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                            submissionStatus: Types.ChallengeResponseSubmissionStatus = #Submitted;
                            cyclesGenerateScoreGsJuctrl : Nat = cyclesGenerateScoreGsJuctrl;
                            cyclesGenerateScoreJuctrlJullm : Nat = cyclesGenerateScoreJuctrlJullm;
                        };

                        let putResult = putSubmission(submissionId, submissionAdded);
                        let submissionMetada : Types.ChallengeResponseSubmissionMetadata = {
                            submissionId : Text = submissionId;
                            submittedTimestamp : Nat64 = submissionAdded.submittedTimestamp;
                            submissionStatus: Types.ChallengeResponseSubmissionStatus = submissionAdded.submissionStatus;
                            cyclesGenerateScoreGsJuctrl : Nat = cyclesGenerateScoreGsJuctrl;
                            cyclesGenerateScoreJuctrlJullm : Nat = cyclesGenerateScoreJuctrlJullm;
                        };
                        D.print("GameState: submitChallengeResponse - submitted!");
                        // TODO - Implementation: adapt cycles burnt stats
                        ignore increaseTotalProtocolCyclesBurnt(CYCLES_BURNT_RESPONSE_GENERATION);
                        return #Ok(submissionMetada);       
                    };
                };    
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
                    // Check if the challenge for this submission still exists and is still open
                    // If not, skip it & check the next submission
                    // TODO - We need to do a regular cleanup of the submissionsStorage
                    if (verifyChallenge(#Open, submission.challengeId)) {
                        switch (submission.submissionStatus) {
                            case (#Submitted) {
                                D.print("GameState: getNextSubmissionToJudge - found a submission to judge");
                                foundKey := ?key;
                                foundSubmission := ?submission;

                                switch (foundKey, foundSubmission) {
                                    case (?key, ?submission) {
                                        // Found a submission with submissionStatus #Submitted

                                        // First send cycles to the Judge to pay for the score generation
                                        let cyclesAdded = submission.cyclesGenerateScoreGsJuctrl;
                                        D.print("GameState: getNextSubmissionToJudge - calling Cycles.add for = " # debug_show(cyclesAdded) # " Cycles");
                                        Cycles.add<system>(cyclesAdded);
                                        try {
                                            let deposit_cycles_args = { canister_id : Principal = msg.caller; };
                                            let _ = await IC0.deposit_cycles(deposit_cycles_args);

                                            D.print("GameState: getNextSubmissionToJudge - Successfully deposited " # debug_show(cyclesAdded) # " cycles to Judge canister " # Principal.toText(msg.caller) );

                                        } catch (e) {
                                            D.print("GameState: getNextSubmissionToJudge - Failed to deposit " # debug_show(cyclesAdded) # " cycles to Judge canister " # Principal.toText(msg.caller));
                                            D.print("GameState: getNextSubmissionToJudge - Failed to deposit error is" # Error.message(e));

                                            return #Err(#FailedOperation);
                                        };  

                                        // (-) Change submissionStatus to #Judging
                                        // (-) Return it to the Judge
                                        let updatedSubmission : Types.ChallengeResponseSubmission = {
                                            challengeTopic : Text = submission.challengeTopic;
                                            challengeTopicId : Text = submission.challengeTopicId;
                                            challengeTopicCreationTimestamp : Nat64 = submission.challengeTopicCreationTimestamp;
                                            challengeTopicStatus : Types.ChallengeTopicStatus = submission.challengeTopicStatus;
                                            cyclesGenerateChallengeGsChctrl : Nat = submission.cyclesGenerateChallengeGsChctrl;
                                            cyclesGenerateChallengeChctrlChllm : Nat = submission.cyclesGenerateChallengeChctrlChllm;
                                            challengeQuestion : Text = submission.challengeQuestion;
                                            challengeQuestionSeed : Nat32 = submission.challengeQuestionSeed;
                                            mainerPromptId : Text = submission.mainerPromptId;
                                            mainerMaxContinueLoopCount : Nat = submission.mainerMaxContinueLoopCount;
                                            mainerNumTokens : Nat64 = submission.mainerNumTokens;
                                            mainerTemp : Float = submission.mainerTemp;
                                            judgePromptId : Text = submission.judgePromptId;
                                            challengeId : Text = submission.challengeId;
                                            challengeCreationTimestamp : Nat64 = submission.challengeCreationTimestamp;
                                            challengeCreatedBy : Types.CanisterAddress = submission.challengeCreatedBy;
                                            challengeStatus : Types.ChallengeStatus = submission.challengeStatus;
                                            challengeClosedTimestamp : ?Nat64 = submission.challengeClosedTimestamp;
                                            cyclesSubmitResponse : Nat = submission.cyclesSubmitResponse;
                                            protocolOperationFeesCut : Nat = submission.protocolOperationFeesCut;
                                            cyclesGenerateResponseSactrlSsctrl : Nat = submission.cyclesGenerateResponseSactrlSsctrl;
                                            cyclesGenerateResponseSsctrlGs : Nat = submission.cyclesGenerateResponseSsctrlGs;
                                            cyclesGenerateResponseSsctrlSsllm : Nat = submission.cyclesGenerateResponseSsctrlSsllm;
                                            cyclesGenerateResponseOwnctrlGs : Nat = submission.cyclesGenerateResponseOwnctrlGs;
                                            cyclesGenerateResponseOwnctrlOwnllmLOW : Nat = submission.cyclesGenerateResponseOwnctrlOwnllmLOW;
                                            cyclesGenerateResponseOwnctrlOwnllmMEDIUM : Nat = submission.cyclesGenerateResponseOwnctrlOwnllmMEDIUM;
                                            cyclesGenerateResponseOwnctrlOwnllmHIGH : Nat = submission.cyclesGenerateResponseOwnctrlOwnllmHIGH;
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
                                            cyclesGenerateScoreGsJuctrl : Nat = submission.cyclesGenerateScoreGsJuctrl;
                                            cyclesGenerateScoreJuctrlJullm : Nat = submission.cyclesGenerateScoreJuctrlJullm;
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
                };
                D.print("GameState: getNextSubmissionToJudge - There are no submissions for open challenges to judge");
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
                owner = participantEntryToReward.ownedBy;
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
                    D.print("GameState: mintRewardOnTokenLedger - sending tokens successful: " # debug_show(blockIndex));
                    return true;
                };
                case (#Err(err)) {
                    D.print("GameState: mintRewardOnTokenLedger - Transfer error: " # debug_show(err));
                    // TODO - Error Handling (e.g. put into queue and try again later)
                    return false;
                };
            };
        } catch (e) {
            D.print("GameState: mintRewardOnTokenLedger - Failed to call ledger: " # Error.message(e));
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
                                // TODO - Implementation: adapt cycles burnt stats
                                ignore increaseTotalProtocolCyclesBurnt(CYCLES_BURNT_WINNER_DECLARATION);
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
                    cyclesGenerateChallengeGsChctrl : Nat = scoredResponseInput.cyclesGenerateChallengeGsChctrl;
                    cyclesGenerateChallengeChctrlChllm : Nat = scoredResponseInput.cyclesGenerateChallengeChctrlChllm;
                    challengeQuestion : Text = scoredResponseInput.challengeQuestion;
                    challengeQuestionSeed : Nat32 = scoredResponseInput.challengeQuestionSeed;
                    mainerPromptId : Text = scoredResponseInput.mainerPromptId;
                    mainerMaxContinueLoopCount : Nat = scoredResponseInput.mainerMaxContinueLoopCount;
                    mainerNumTokens : Nat64 = scoredResponseInput.mainerNumTokens;
                    mainerTemp : Float = scoredResponseInput.mainerTemp;
                    judgePromptId : Text = scoredResponseInput.judgePromptId;
                    challengeId : Text = scoredResponseInput.challengeId;
                    challengeCreationTimestamp : Nat64 = scoredResponseInput.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = scoredResponseInput.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = scoredResponseInput.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = scoredResponseInput.challengeClosedTimestamp;
                    cyclesSubmitResponse : Nat = scoredResponseInput.cyclesSubmitResponse;
                    protocolOperationFeesCut : Nat = scoredResponseInput.protocolOperationFeesCut;
                    cyclesGenerateResponseSactrlSsctrl : Nat = scoredResponseInput.cyclesGenerateResponseSactrlSsctrl;
                    cyclesGenerateResponseSsctrlGs : Nat = scoredResponseInput.cyclesGenerateResponseSsctrlGs;
                    cyclesGenerateResponseSsctrlSsllm : Nat = scoredResponseInput.cyclesGenerateResponseSsctrlSsllm;
                    cyclesGenerateResponseOwnctrlGs : Nat = scoredResponseInput.cyclesGenerateResponseOwnctrlGs;
                    cyclesGenerateResponseOwnctrlOwnllmLOW : Nat = scoredResponseInput.cyclesGenerateResponseOwnctrlOwnllmLOW;
                    cyclesGenerateResponseOwnctrlOwnllmMEDIUM : Nat = scoredResponseInput.cyclesGenerateResponseOwnctrlOwnllmMEDIUM;
                    cyclesGenerateResponseOwnctrlOwnllmHIGH : Nat = scoredResponseInput.cyclesGenerateResponseOwnctrlOwnllmHIGH;
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
                    cyclesGenerateScoreGsJuctrl : Nat = scoredResponseInput.cyclesGenerateScoreGsJuctrl;
                    cyclesGenerateScoreJuctrlJullm : Nat = scoredResponseInput.cyclesGenerateScoreJuctrlJullm;
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
                    cyclesGenerateChallengeGsChctrl : Nat = scoredResponseInput.cyclesGenerateChallengeGsChctrl;
                    cyclesGenerateChallengeChctrlChllm : Nat = scoredResponseInput.cyclesGenerateChallengeChctrlChllm;
                    challengeQuestion : Text = scoredResponseInput.challengeQuestion;
                    challengeQuestionSeed : Nat32 = scoredResponseInput.challengeQuestionSeed;
                    mainerPromptId : Text = scoredResponseInput.mainerPromptId;
                    mainerMaxContinueLoopCount : Nat = scoredResponseInput.mainerMaxContinueLoopCount;
                    mainerNumTokens : Nat64 = scoredResponseInput.mainerNumTokens;
                    mainerTemp : Float = scoredResponseInput.mainerTemp;
                    judgePromptId : Text = scoredResponseInput.judgePromptId;
                    challengeId : Text = scoredResponseInput.challengeId;
                    challengeCreationTimestamp : Nat64 = scoredResponseInput.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = scoredResponseInput.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = scoredResponseInput.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = scoredResponseInput.challengeClosedTimestamp;
                    cyclesSubmitResponse : Nat = scoredResponseInput.cyclesSubmitResponse;
                    protocolOperationFeesCut : Nat = scoredResponseInput.protocolOperationFeesCut;
                    cyclesGenerateResponseSactrlSsctrl : Nat = scoredResponseInput.cyclesGenerateResponseSactrlSsctrl;
                    cyclesGenerateResponseSsctrlGs : Nat = scoredResponseInput.cyclesGenerateResponseSsctrlGs;
                    cyclesGenerateResponseSsctrlSsllm : Nat = scoredResponseInput.cyclesGenerateResponseSsctrlSsllm;
                    cyclesGenerateResponseOwnctrlGs : Nat = scoredResponseInput.cyclesGenerateResponseOwnctrlGs;
                    cyclesGenerateResponseOwnctrlOwnllmLOW : Nat = scoredResponseInput.cyclesGenerateResponseOwnctrlOwnllmLOW;
                    cyclesGenerateResponseOwnctrlOwnllmMEDIUM : Nat = scoredResponseInput.cyclesGenerateResponseOwnctrlOwnllmMEDIUM;
                    cyclesGenerateResponseOwnctrlOwnllmHIGH : Nat = scoredResponseInput.cyclesGenerateResponseOwnctrlOwnllmHIGH;
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
                    cyclesGenerateScoreGsJuctrl : Nat = scoredResponseInput.cyclesGenerateScoreGsJuctrl;
                    cyclesGenerateScoreJuctrlJullm : Nat = scoredResponseInput.cyclesGenerateScoreJuctrlJullm;
                    judgedBy: Principal = scoredResponseInput.judgedBy;
                    score: Nat = scoredResponseInput.score;
                    scoreSeed: Nat32 = scoredResponseInput.scoreSeed;
                    judgedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                };
                D.print("GameState: addScoredResponse - All Good - calling putScoredResponseForChallenge");
                D.print("GameState: addScoredResponse - scoredResponseEntry = " # debug_show(scoredResponseEntry));
                // TODO - Implementation: adapt cycles burnt stats
                ignore increaseTotalProtocolCyclesBurnt(CYCLES_BURNT_JUDGE_SCORING);
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

    // TODO - Security: decide if kept in production
    public shared query (msg) func getOfficialCanistersAdmin() : async [Types.OfficialProtocolCanister] {
        if (not Principal.isController(msg.caller)) {
            return [];
        };
        var officialCanisters : List.List<Types.OfficialProtocolCanister> = List.nil<Types.OfficialProtocolCanister>();
        for (canisterEntry in mainerCreatorCanistersStorage.vals()) {
            officialCanisters := List.push<Types.OfficialProtocolCanister>(canisterEntry, officialCanisters);    
        };
        for (canisterEntry in judgeCanistersStorage.vals()) {
            officialCanisters := List.push<Types.OfficialProtocolCanister>(canisterEntry, officialCanisters);    
        };
        for (canisterEntry in challengerCanistersStorage.vals()) {
            officialCanisters := List.push<Types.OfficialProtocolCanister>(canisterEntry, officialCanisters);    
        };
        return List.toArray(officialCanisters);        
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
                    cyclesGenerateChallengeGsChctrl : Nat = openChallenge.cyclesGenerateChallengeGsChctrl;
                    cyclesGenerateChallengeChctrlChllm : Nat = openChallenge.cyclesGenerateChallengeChctrlChllm;
                    challengeQuestion : Text = openChallenge.challengeQuestion;
                    challengeQuestionSeed : Nat32 = openChallenge.challengeQuestionSeed;
                    mainerPromptId : Text = openChallenge.mainerPromptId;
                    mainerMaxContinueLoopCount : Nat = openChallenge.mainerMaxContinueLoopCount;
                    mainerNumTokens : Nat64 = openChallenge.mainerNumTokens;
                    mainerTemp : Float = openChallenge.mainerTemp;
                    judgePromptId : Text = openChallenge.judgePromptId;
                    challengeId : Text = openChallenge.challengeId;
                    challengeCreationTimestamp : Nat64 = openChallenge.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = openChallenge.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = openChallenge.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = openChallenge.challengeClosedTimestamp;
                    cyclesSubmitResponse : Nat = openChallenge.cyclesSubmitResponse;
                    protocolOperationFeesCut : Nat = openChallenge.protocolOperationFeesCut;
                    cyclesGenerateResponseSactrlSsctrl : Nat = openChallenge.cyclesGenerateResponseSactrlSsctrl;
                    cyclesGenerateResponseSsctrlGs : Nat = openChallenge.cyclesGenerateResponseSsctrlGs;
                    cyclesGenerateResponseSsctrlSsllm : Nat = openChallenge.cyclesGenerateResponseSsctrlSsllm;
                    cyclesGenerateResponseOwnctrlGs : Nat = openChallenge.cyclesGenerateResponseOwnctrlGs;
                    cyclesGenerateResponseOwnctrlOwnllmLOW : Nat = openChallenge.cyclesGenerateResponseOwnctrlOwnllmLOW;
                    cyclesGenerateResponseOwnctrlOwnllmMEDIUM : Nat = openChallenge.cyclesGenerateResponseOwnctrlOwnllmMEDIUM;
                    cyclesGenerateResponseOwnctrlOwnllmHIGH : Nat = openChallenge.cyclesGenerateResponseOwnctrlOwnllmHIGH;
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
                    cyclesGenerateScoreGsJuctrl : Nat = cyclesGenerateScoreGsJuctrl;
                    cyclesGenerateScoreJuctrlJullm : Nat = cyclesGenerateScoreJuctrlJullm;
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
                            cyclesGenerateChallengeGsChctrl : Nat = closedChallenge.cyclesGenerateChallengeGsChctrl;
                            cyclesGenerateChallengeChctrlChllm : Nat = closedChallenge.cyclesGenerateChallengeChctrlChllm;
                            challengeQuestion : Text = closedChallenge.challengeQuestion;
                            challengeQuestionSeed : Nat32 = closedChallenge.challengeQuestionSeed;
                            mainerPromptId : Text = closedChallenge.mainerPromptId;
                            mainerMaxContinueLoopCount : Nat = closedChallenge.mainerMaxContinueLoopCount;
                            mainerNumTokens : Nat64 = closedChallenge.mainerNumTokens;
                            mainerTemp : Float = closedChallenge.mainerTemp;
                            judgePromptId : Text = closedChallenge.judgePromptId;
                            challengeId : Text = closedChallenge.challengeId;
                            challengeCreationTimestamp : Nat64 = closedChallenge.challengeCreationTimestamp;
                            challengeCreatedBy : Types.CanisterAddress = closedChallenge.challengeCreatedBy;
                            challengeStatus : Types.ChallengeStatus = closedChallenge.challengeStatus;
                            challengeClosedTimestamp : ?Nat64 = closedChallenge.challengeClosedTimestamp;
                            cyclesSubmitResponse : Nat = closedChallenge.cyclesSubmitResponse;
                            protocolOperationFeesCut : Nat = closedChallenge.protocolOperationFeesCut;
                            cyclesGenerateResponseSactrlSsctrl : Nat = closedChallenge.cyclesGenerateResponseSactrlSsctrl;
                            cyclesGenerateResponseSsctrlGs : Nat = closedChallenge.cyclesGenerateResponseSsctrlGs;
                            cyclesGenerateResponseSsctrlSsllm : Nat = closedChallenge.cyclesGenerateResponseSsctrlSsllm;
                            cyclesGenerateResponseOwnctrlGs : Nat = closedChallenge.cyclesGenerateResponseOwnctrlGs;
                            cyclesGenerateResponseOwnctrlOwnllmLOW : Nat = closedChallenge.cyclesGenerateResponseOwnctrlOwnllmLOW;
                            cyclesGenerateResponseOwnctrlOwnllmMEDIUM : Nat = closedChallenge.cyclesGenerateResponseOwnctrlOwnllmMEDIUM;
                            cyclesGenerateResponseOwnctrlOwnllmHIGH : Nat = closedChallenge.cyclesGenerateResponseOwnctrlOwnllmHIGH;
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
                            cyclesGenerateScoreGsJuctrl : Nat = cyclesGenerateScoreGsJuctrl;
                            cyclesGenerateScoreJuctrlJullm : Nat = cyclesGenerateScoreJuctrlJullm;
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
                            cyclesGenerateChallengeGsChctrl : Nat = cyclesGenerateChallengeGsChctrl;
                            cyclesGenerateChallengeChctrlChllm : Nat = cyclesGenerateChallengeChctrlChllm;
                            challengeQuestion : Text = "";
                            challengeQuestionSeed : Nat32 = 0;
                            mainerPromptId : Text = "submissionInput.mainerPromptId";
                            mainerMaxContinueLoopCount : Nat = 3;
                            mainerNumTokens : Nat64 = 1024;
                            mainerTemp : Float = 0.8;
                            judgePromptId : Text = "submissionInput.judgePromptId";
                            challengeId : Text = submissionInput.challengeId;
                            challengeCreationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                            challengeCreatedBy : Types.CanisterAddress = "";
                            challengeStatus : Types.ChallengeStatus = #Archived;
                            challengeClosedTimestamp : ?Nat64 = ?Nat64.fromNat(Int.abs(Time.now()));
                            cyclesSubmitResponse : Nat = cyclesSubmitResponse;
                            protocolOperationFeesCut : Nat = protocolOperationFeesCut;
                            cyclesGenerateResponseSactrlSsctrl : Nat = cyclesGenerateResponseSactrlSsctrl;
                            cyclesGenerateResponseSsctrlGs : Nat = cyclesGenerateResponseSsctrlGs;
                            cyclesGenerateResponseSsctrlSsllm : Nat = cyclesGenerateResponseSsctrlSsllm;
                            cyclesGenerateResponseOwnctrlGs : Nat = cyclesGenerateResponseOwnctrlGs;
                            cyclesGenerateResponseOwnctrlOwnllmLOW : Nat = cyclesGenerateResponseOwnctrlOwnllmLOW;
                            cyclesGenerateResponseOwnctrlOwnllmMEDIUM : Nat = cyclesGenerateResponseOwnctrlOwnllmMEDIUM;
                            cyclesGenerateResponseOwnctrlOwnllmHIGH : Nat = cyclesGenerateResponseOwnctrlOwnllmHIGH;
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
                            cyclesGenerateScoreGsJuctrl : Nat = cyclesGenerateScoreGsJuctrl;
                            cyclesGenerateScoreJuctrlJullm : Nat = cyclesGenerateScoreJuctrlJullm;
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
                rewardType : Types.RewardType = rewardPerChallenge.rewardType;
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
                rewardType : Types.RewardType = rewardPerChallenge.rewardType;
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
                rewardType : Types.RewardType = rewardPerChallenge.rewardType;
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
        mainerPromptsStable := Iter.toArray(mainerPrompts.entries());
        judgePromptsStable := Iter.toArray(judgePrompts.entries());
        submissionsStorageStable := Iter.toArray(submissionsStorage.entries());
        scoredResponsesPerChallengeStable := Iter.toArray(scoredResponsesPerChallenge.entries());
        winnerDeclarationForChallengeStable := Iter.toArray(winnerDeclarationForChallenge.entries());
        sharedServiceCanistersStorageStable := Iter.toArray(sharedServiceCanistersStorage.entries());
        redeemedTransactionBlocksStorageStable := Iter.toArray(redeemedTransactionBlocksStorage.entries());
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
        mainerPrompts := HashMap.fromIter(Iter.fromArray(mainerPromptsStable), mainerPromptsStable.size(), Text.equal, Text.hash);
        mainerPromptsStable := [];
        judgePrompts := HashMap.fromIter(Iter.fromArray(judgePromptsStable), judgePromptsStable.size(), Text.equal, Text.hash);
        judgePromptsStable := [];
        submissionsStorage := HashMap.fromIter(Iter.fromArray(submissionsStorageStable), submissionsStorageStable.size(), Text.equal, Text.hash);
        submissionsStorageStable := [];
        scoredResponsesPerChallenge := HashMap.fromIter(Iter.fromArray(scoredResponsesPerChallengeStable), scoredResponsesPerChallengeStable.size(), Text.equal, Text.hash);
        scoredResponsesPerChallengeStable := [];
        winnerDeclarationForChallenge := HashMap.fromIter(Iter.fromArray(winnerDeclarationForChallengeStable), winnerDeclarationForChallengeStable.size(), Text.equal, Text.hash);
        winnerDeclarationForChallengeStable := [];
        sharedServiceCanistersStorage := HashMap.fromIter(Iter.fromArray(sharedServiceCanistersStorageStable), sharedServiceCanistersStorageStable.size(), Text.equal, Text.hash);
        sharedServiceCanistersStorageStable := [];
        redeemedTransactionBlocksStorage := HashMap.fromIter(Iter.fromArray(redeemedTransactionBlocksStorageStable), redeemedTransactionBlocksStorageStable.size(), Nat.equal, Hash.hash);
        redeemedTransactionBlocksStorageStable := [];
    };
};
