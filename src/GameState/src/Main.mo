// import IcpLedger "canister:icp_ledger_canister"; https://github.com/dfinity/examples/blob/master/motoko/icp_transfer/src/icp_transfer_backend/main.mo
import D "mo:base/Debug";
import Buffer "mo:base/Buffer";
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
import Order "mo:base/Order";
import Error "mo:base/Error";
import Float "mo:base/Float";

import Types "../../common/Types";
import ICManagementCanister "../../common/ICManagementCanister";
import TokenLedger "../../common/icp-ledger-interface";
import Constants "../../common/Constants";
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
    let officialMainerAgentCanisterWasmHash : Blob = "\5B\CA\BD\C2\0A\41\F8\6C\11\5D\14\EE\ED\94\35\CC\5A\2A\87\C9\57\F8\D9\FC\4C\6E\B3\6A\1B\D3\DD\AD";
    
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

    // Cycles for ShareAgent mAIner Creation
    stable var ICP_FOR_SHARE_AGENT : Nat  = 10                  ; // TODO: Set to cost of a ShareAgent, in ICP
    public shared (msg) func setIcpForShareAgentAdmin(icpForShareAgent : Nat) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        ICP_FOR_SHARE_AGENT := icpForShareAgent;
        return #Ok({ status_code = 200 });
    };
    stable var cyclesCreateSactrlUserGs   : Nat  = 0;
    stable var cyclesCreateSactrlMarginGs : Nat  = 2_000_000_000  ; // Margin kept in GameState canister for the creation of the ShareAgent
    stable var cyclesCreateSactrlMarginMc : Nat  = 2_000_000_000  ; // Margin kept in mAIner Creator canister for the creation of the ShareAgent
    stable var cyclesCreateSactrlGsMc     : Nat  = 0;               // Cycles that will be sent to the mAIner Creator canister
    stable var cyclesCreateSactrlMcSactrl : Nat  = 0;               // Cycles that will be sent to the mAIner agent canister
    private func setCyclesCreateShareAgentMainer(cyclesFromUser : Nat) {
        // Call this at start of every mAIner creation
        cyclesCreateSactrlUserGs   := cyclesFromUser  ;
        cyclesCreateSactrlGsMc     := cyclesCreateSactrlUserGs - cyclesCreateSactrlMarginGs;   
        cyclesCreateSactrlMcSactrl := cyclesCreateSactrlGsMc - cyclesCreateSactrlMarginMc; 
        D.print("GameState: setCyclesCreateShareAgent - cyclesCreateSactrlUserGs  : " # debug_show(cyclesCreateSactrlUserGs));
        D.print("GameState: setCyclesCreateShareAgent - cyclesCreateSactrlMarginGs: " # debug_show(cyclesCreateSactrlMarginGs));
        D.print("GameState: setCyclesCreateShareAgent - cyclesCreateSactrlMarginMc: " # debug_show(cyclesCreateSactrlMarginMc));
        D.print("GameState: setCyclesCreateShareAgent - cyclesCreateSactrlGsMc    : " # debug_show(cyclesCreateSactrlGsMc));
        D.print("GameState: setCyclesCreateShareAgent - cyclesCreateSactrlMcSactrl: " # debug_show(cyclesCreateSactrlMcSactrl));
    };

    // Cycles for Own mAIner Creation 
    // Note: the ShareService mAIner will also use these values
    stable var ICP_FOR_OWN_MAINER : Nat  = 10                  ; // TODO: Set to cost of a Own mAIner, in ICP
    public shared (msg) func setIcpForOwnMainerAdmin(icpForOwnMainer : Nat) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        ICP_FOR_OWN_MAINER := icpForOwnMainer;
        return #Ok({ status_code = 200 });
    };

    // Protocol parameters used in the mAIner Creation Cycles Flow calculations      
    let DEFAULT_CYCLES_CREATE_MAINER_MARGIN_GS          : Nat  =     2_000_000_000; // Margin kept in GameState canister 
    let DEFAULT_CYCLES_CREATE_MAINER_MARGIN_MC          : Nat  =   300_000_000_000; // Margin kept in mAIner Creator canister
    let DEFAULT_CYCLES_CREATE_MAINER_LLM_TARGET_BALANCE : Nat  = 2_000_000_000_000; // Target balance for the Own LLM canister after creation
    let DEFAULT_COST_CREATE_MAINER_LLM                  : Nat  =   813_798_796_586; // Cost of an LLM canister for it's creation

    stable var cyclesCreateMainerMarginGs         : Nat  = DEFAULT_CYCLES_CREATE_MAINER_MARGIN_GS;
    stable var cyclesCreatemMainerMarginMc        : Nat  = DEFAULT_CYCLES_CREATE_MAINER_MARGIN_MC;
    stable var cyclesCreateMainerLlmTargetBalance : Nat  = DEFAULT_CYCLES_CREATE_MAINER_LLM_TARGET_BALANCE;
    stable var costCreateMainerLlm                : Nat  = DEFAULT_COST_CREATE_MAINER_LLM;

    // Calculate the cycles that will be sent to the mAIner Creator
    
    private func setCyclesCreateMainer(cyclesFromUser : Nat, mainerAgentCanisterType : Types.MainerAgentCanisterType) : Types.CyclesCreateMainer {
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
                cyclesCreateMainerllmMcMainerllm  := cyclesCreateMainerLlmTargetBalance + costCreateMainerLlm - cyclesCreatemMainerMarginMc;
                cyclesCreateMainerllmGsMc         := cyclesCreateMainerllmMcMainerllm + cyclesCreatemMainerMarginMc;
            };
        };
        cyclesCreateMainerctrlGsMc     := cyclesFromUser - cyclesCreateMainerllmGsMc - cyclesCreateMainerMarginGs;         
        cyclesCreateMainerctrlMcMainerctrl := cyclesCreateMainerctrlGsMc - cyclesCreatemMainerMarginMc;

        D.print("GameState: setCyclesCreateMainer - cyclesFromUser                     : " # debug_show(cyclesFromUser));
        D.print("GameState: setCyclesCreateMainer - cyclesCreateMainerMarginGs         : " # debug_show(cyclesCreateMainerMarginGs));
        D.print("GameState: setCyclesCreateMainer - cyclesCreatemMainerMarginMc        : " # debug_show(cyclesCreatemMainerMarginMc));
        D.print("GameState: setCyclesCreateMainer - cyclesCreateMainerLlmTargetBalance : " # debug_show(cyclesCreateMainerLlmTargetBalance));
        D.print("GameState: setCyclesCreateMainer - costCreateMainerLlm                : " # debug_show(costCreateMainerLlm));
        D.print("GameState: setCyclesCreateMainer - cyclesCreateMainerctrlGsMc         : " # debug_show(cyclesCreateMainerctrlGsMc));
        D.print("GameState: setCyclesCreateMainer - cyclesCreateMainerllmGsMc          : " # debug_show(cyclesCreateMainerllmGsMc));
        D.print("GameState: setCyclesCreateMainer - cyclesCreateMainerctrlMcMainerctrl : " # debug_show(cyclesCreateMainerctrlMcMainerctrl));
        D.print("GameState: setCyclesCreateMainer - cyclesCreateMainerllmMcMainerllm   : " # debug_show(cyclesCreateMainerllmMcMainerllm));
        
        let cyclesCreateMainer : Types.CyclesCreateMainer = {
            cyclesCreateMainerctrlGsMc = cyclesCreateMainerctrlGsMc;
            cyclesCreateMainerllmGsMc  = cyclesCreateMainerllmGsMc;
            cyclesCreateMainerctrlMcMainerctrl = cyclesCreateMainerctrlMcMainerctrl;
            cyclesCreateMainerllmMcMainerllm   = cyclesCreateMainerllmMcMainerllm;
        };
        return cyclesCreateMainer;
    };

    // Protocol parameters used in the Generation Cycles Flow calculations
    let DEFAULT_DAILY_CHALLENGES                : Nat = 5;                      // TODO: set the actual value or let the GameState automatically update this on a daily basis
    stable var dailyChallenges                  : Nat = DEFAULT_DAILY_CHALLENGES; // The lower the value, the more cycles are send with each challenge to the Challenger

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
    
    let DEFAULT_DAILY_SUBMISSIONS_ALL_OWN          : Nat =   0; // TODO = GameState automatically updates this on a daily basis
    stable var dailySubmissionsAllOwn              : Nat = DEFAULT_DAILY_SUBMISSIONS_ALL_OWN;
    let DEFAULT_DAILY_SUBMISSIONS_ALL_SHARE        : Nat = 100; // TODO = GameState automatically updates this on a daily basis
    stable var dailySubmissionsAllShare            : Nat = DEFAULT_DAILY_SUBMISSIONS_ALL_SHARE;

    let DEFAULT_MARGIN_FAILED_SUBMISSION_CUT       : Nat =  20; // % Margin for a Failed Submission Cut
    stable var marginFailedSubmissionCut           : Nat = DEFAULT_MARGIN_FAILED_SUBMISSION_CUT;
    let DEFAULT_MARGIN_COST                        : Nat =  10; // % Margin for all the cycles send to cover costs
    stable var marginCost                          : Nat = DEFAULT_MARGIN_COST;
    let DEFAULT_SUBMISSION_FEE                     : Nat =  75_187_969_924; // $0.10 Fee for the submission of a response to GameState
    stable var submissionFee                       : Nat = DEFAULT_SUBMISSION_FEE;

    // Number of protocol LLMs
    let DEFAULT_NUM_CHALLENGER_LLMS                : Nat =   1; // Number of Challenger   LLMs     - TODO: update to actual value
    stable var numChallengerLlms                   : Nat = DEFAULT_NUM_CHALLENGER_LLMS;
    let DEFAULT_NUM_JUDGE_LLMS                     : Nat =  24; // Number of Judge        LLMs     - TODO: update to actual value
    stable var numJudgeLlms                        : Nat = DEFAULT_NUM_JUDGE_LLMS;
    let DEFAULT_NUM_SHARE_SERVICE_LLMS             : Nat =  16; // Number of ShareService LLMs     - TODO: update to actual value
    stable var numShareServiceLlms                 : Nat = DEFAULT_NUM_SHARE_SERVICE_LLMS;
    
    // Cost of the idle burn rates for protocol canisters
    let DEFAULT_COST_IDLE_BURN_RATE_GS             : Nat =     201_492_636; // GameState                cost for idle burn rate
    stable var costIdleBurnRateGs                  : Nat = DEFAULT_COST_IDLE_BURN_RATE_GS;
    let DEFAULT_COST_IDLE_BURN_RATE_MC             : Nat =  28_202_512_112; // mAIner Creator           cost for idle burn rate
    stable var costIdleBurnRateMc                  : Nat = DEFAULT_COST_IDLE_BURN_RATE_MC;
    let DEFAULT_COST_IDLE_BURN_RATE_CHCTRL         : Nat =     114_749_311; // Challenger Controller    cost for idle burn rate
    stable var costIdleBurnRateChctrl              : Nat = DEFAULT_COST_IDLE_BURN_RATE_CHCTRL;
    let DEFAULT_COST_IDLE_BURN_RATE_CHLLM          : Nat =  23_769_539_345; // One Challenger LLM       cost for idle burn rate
    stable var costIdleBurnRateChllm               : Nat = DEFAULT_COST_IDLE_BURN_RATE_CHLLM;
    let DEFAULT_COST_IDLE_BURN_RATE_JUCTRL         : Nat =     114_749_311; // Judge Controller         cost for idle burn rate
    stable var costIdleBurnRateJuctrl              : Nat = DEFAULT_COST_IDLE_BURN_RATE_JUCTRL;
    let DEFAULT_COST_IDLE_BURN_RATE_JULLM          : Nat =  23_769_539_345; // One Judge LLM            cost for idle burn rate
    stable var costIdleBurnRateJullm               : Nat = DEFAULT_COST_IDLE_BURN_RATE_JULLM;
    let DEFAULT_COST_IDLE_BURN_RATE_SSCTRL         : Nat =     156_736_586; // ShareService Controller  cost for idle burn rate
    stable var costIdleBurnRateSsctrl              : Nat = DEFAULT_COST_IDLE_BURN_RATE_SSCTRL;
    let DEFAULT_COST_IDLE_BURN_RATE_SSLLM          : Nat =  23_769_539_345; // One ShareService LLM     cost for idle burn rate
    stable var costIdleBurnRateSsllm               : Nat = DEFAULT_COST_IDLE_BURN_RATE_SSLLM;

    // Cost of the idle burn rates for user canisters
    let DEFAULT_COST_IDLE_BURN_RATE_SACTRL         : Nat =     156_736_586; // ShareAgent Controller    cost for idle burn rate
    stable var costIdleBurnRateSactrl              : Nat = DEFAULT_COST_IDLE_BURN_RATE_SACTRL;
    let DEFAULT_COST_IDLE_BURN_RATE_SALLM          : Nat =  23_769_539_345; // One Share Service LLM    cost for idle burn rate
    stable var costIdleBurnRateSallm               : Nat = DEFAULT_COST_IDLE_BURN_RATE_SALLM;
    let DEFAULT_COST_IDLE_BURN_RATE_OWNCTRL        : Nat =     156_736_586; // Own Controller           cost for idle burn rate
    stable var costIdleBurnRateOwnctrl             : Nat = DEFAULT_COST_IDLE_BURN_RATE_OWNCTRL;
    let DEFAULT_COST_IDLE_BURN_RATE_OWNLLM         : Nat =  23_769_539_345; // Own LLM                  cost for idle burn rate
    stable var costIdleBurnRateOwnllm              : Nat = DEFAULT_COST_IDLE_BURN_RATE_OWNLLM;
    
    // Cost of the generations
    let DEFAULT_COST_GENERATE_CHALLENGE_GS         : Nat =     221_000_000; // GameState                cost for challenge generation
    stable var costGenerateChallengeGs             : Nat = DEFAULT_COST_GENERATE_CHALLENGE_GS;
    let DEFAULT_COST_GENERATE_CHALLENGE_CHCTRL     : Nat =  12_052_000_000; // Challenge Controller     cost for challenge generation
    stable var costGenerateChallengeChctrl         : Nat = DEFAULT_COST_GENERATE_CHALLENGE_CHCTRL;
    let DEFAULT_COST_GENERATE_CHALLENGE_CHLLM      : Nat = 305_810_000_000; // Challenge LLM            cost for challenge creation
    stable var costGenerateChallengeChllm          : Nat = DEFAULT_COST_GENERATE_CHALLENGE_CHLLM;

    let DEFAULT_COST_GENERATE_SCORE_GS             : Nat =     111_000_000; // GameState                cost for Score generation
    stable var costGenerateScoreGs                 : Nat = DEFAULT_COST_GENERATE_SCORE_GS;
    let DEFAULT_COST_GENERATE_SCORE_JUCTRL         : Nat =   5_702_000_000; // Judge Controller         cost for Score generation
    stable var costGenerateScoreJuctrl             : Nat = DEFAULT_COST_GENERATE_SCORE_JUCTRL;
    let DEFAULT_COST_GENERATE_SCORE_JULLM          : Nat = 115_615_000_000; // Judge LLM                cost for Score generation
    stable var costGenerateScoreJullm              : Nat = DEFAULT_COST_GENERATE_SCORE_JULLM;

    let DEFAULT_COST_GENERATE_RESPONSE_OWN_GS      : Nat =     150_000_000; // GameState                cost for Own response generation
    stable var costGenerateResponseOwnGs           : Nat = DEFAULT_COST_GENERATE_RESPONSE_OWN_GS;
    let DEFAULT_COST_GENERATE_RESPONSE_OWNCTRL     : Nat =   3_947_000_000; // Own Controller           cost for Own response generation
    stable var costGenerateResponseOwnctrl         : Nat = DEFAULT_COST_GENERATE_RESPONSE_OWNCTRL;
    let DEFAULT_COST_GENERATE_RESPONSE_OWNLLM      : Nat = 115_615_000_000; // Own LLM                  cost for Own response generation
    stable var costGenerateResponseOwnllm          : Nat = DEFAULT_COST_GENERATE_RESPONSE_OWNLLM;

    let DEFAULT_COST_GENERATE_RESPONSE_SHARE_GS    : Nat =     150_000_000; // GameState                cost for Share response generation
    stable var costGenerateResponseShareGs         : Nat = DEFAULT_COST_GENERATE_RESPONSE_SHARE_GS;
    let DEFAULT_COST_GENERATE_RESPONSE_SACTRL      : Nat =     100_000_000; // Share Agent   Controller cost for Share response generation
    stable var costGenerateResponseSactrl          : Nat = DEFAULT_COST_GENERATE_RESPONSE_SACTRL;
    let DEFAULT_COST_GENERATE_RESPONSE_SSCTRL      : Nat =   3_947_000_000; // Share Service Controller cost for Share response generation
    stable var costGenerateResponseSsctrl          : Nat = DEFAULT_COST_GENERATE_RESPONSE_SSCTRL;
    let DEFAULT_COST_GENERATE_RESPONSE_SSLLM       : Nat = 115_615_000_000; // Share Service LLM        cost for Share response generation
    stable var costGenerateResponseSsllm           : Nat = DEFAULT_COST_GENERATE_RESPONSE_SSLLM;

    // Calculate Cycles Flows for Challenge generation by Challenger
    stable var cyclesGenerateChallengeGsChctrl     : Nat = 0;
    stable var cyclesGenerateChallengeChctrlChllm  : Nat = 0;
    stable var cyclesBurntChallengeGeneration        : Nat = 0;
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

        // Total burnt cycles for response generation (excludes idle burn)
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
        costCreateMainerLlm       := DEFAULT_COST_CREATE_MAINER_LLM;

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
        setCyclesGenerateChallenge();
        setCyclesGenerateScore();
        setCyclesGenerateResponse();
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
            costCreateMainerLlm = costCreateMainerLlm;

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

    // Statistics
    stable var TOTAL_PROTOCOL_CYCLES_BURNT : Nat = 0;

    // TODO: once a day, add the dailyIdleBurnRate using getDailyIdleBurnRate()
    private func increaseTotalProtocolCyclesBurnt(cyclesBurntToAdd : Nat) : Bool {
        TOTAL_PROTOCOL_CYCLES_BURNT := TOTAL_PROTOCOL_CYCLES_BURNT + cyclesBurntToAdd;
        return true;
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

        ignore increaseTotalProtocolCyclesBurnt(cyclesBurntChallengeGeneration);

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
                    mainerPromptId : Text = newChallenge.mainerPromptId;
                    judgePromptId : Text = newChallenge.judgePromptId;
                    challengeCreationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                    challengeCreatedBy : Types.CanisterAddress = challengerEntry.address;
                    challengeStatus : Types.ChallengeStatus = #Open;
                    challengeClosedTimestamp : ?Nat64 = null;
                    cyclesSubmitResponse : Nat = cyclesSubmitResponse;
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

                                var associatedCanisterAddress : ?Types.CanisterAddress = null;
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
                                                D.print("GameState: spinUpMainerControllerCanister - 08 ");
                                                return #Err(#Unauthorized);
                                            };
                                            case (?sharedServiceEntry) {
                                                associatedCanisterAddress := ?sharedServiceEntry.address;
                                            };
                                        };
                                    };
                                    case (_) { return #Err(#Other("Unsupported")); }
                                };

                                let cyclesFromUser : Nat = 10_000_000_000_000; // TODO - get from user payment
                                let cyclesCreateMainer : Types.CyclesCreateMainer = setCyclesCreateMainer(cyclesFromUser, mainerAgentCanisterType);
                                
                                let canisterCreationInput : Types.CanisterCreationConfiguration = {
                                    canisterType : Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                    owner: Principal = userMainerEntry.ownedBy; // User
                                    associatedCanisterAddress : ?Types.CanisterAddress = associatedCanisterAddress; // null for #Own, shareServiceCanisterAddress for ShareAgent
                                    mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                    userMainerEntryCreationTimestamp : Nat64 = userMainerEntry.creationTimestamp;
                                    userMainerEntryCanisterType : Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                    cyclesCreateMainerctrlGsMc : Nat = cyclesCreateMainer.cyclesCreateMainerctrlGsMc;
                                    cyclesCreateMainerllmGsMc : Nat = cyclesCreateMainer.cyclesCreateMainerllmGsMc;
                                    cyclesCreateMainerctrlMcMainerctrl : Nat = cyclesCreateMainer.cyclesCreateMainerctrlMcMainerctrl;
                                    cyclesCreateMainerllmMcMainerllm : Nat = cyclesCreateMainer.cyclesCreateMainerllmMcMainerllm;
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

                                let cyclesAdded = cyclesCreateMainer.cyclesCreateMainerctrlGsMc;
                                Cycles.add<system>(cyclesAdded);
                                D.print("GameState: spinUpMainerControllerCanister - cycles sent to mAInerCreator = " # debug_show(cyclesAdded) );

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
                                        let setupCanisterInput : Types.SetupCanisterInput = {
                                            newCanisterId : Text = canisterCreationRecord.newCanisterId;
                                            configurationInput : Types.CanisterCreationConfiguration = canisterCreationInput;
                                        };
                                        ignore creatorCanisterActor.setupCanister(setupCanisterInput);

                                        let canisterEntryToAdd : Types.OfficialMainerAgentCanister = {
                                            address : Text = canisterCreationRecord.newCanisterId; // New mAIner Controller canister's id
                                            canisterType: Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                            creationTimestamp : Nat64 = userMainerEntry.creationTimestamp;
                                            createdBy : Principal = Principal.fromText(mainerCreatorEntry.address); // mAIner Creator
                                            ownedBy : Principal = userMainerEntry.ownedBy; // User
                                            status : Types.CanisterStatus = #ControllerCreationInProgress;
                                            mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                        };
                                        D.print("GameState: spinUpMainerControllerCanister - canisterEntryToAdd: " # debug_show(canisterEntryToAdd) );
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
                                
                                let cyclesFromUser : Nat = 10_000_000_000_000; // TODO - get from user payment
                                let cyclesCreateMainer : Types.CyclesCreateMainer = setCyclesCreateMainer(cyclesFromUser, mainerAgentCanisterType);
                                
                                let canisterCreationInput : Types.CanisterCreationConfiguration = {
                                    canisterType : Types.ProtocolCanisterType = #MainerLlm;
                                    owner: Principal = userMainerEntry.ownedBy; // User
                                    associatedCanisterAddress : ?Types.CanisterAddress = ?userMainerEntry.address; // Controller address
                                    mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                    userMainerEntryCreationTimestamp : Nat64 = userMainerEntry.creationTimestamp; // Controller
                                    userMainerEntryCanisterType : Types.ProtocolCanisterType = userMainerEntry.canisterType; // Controller
                                    cyclesCreateMainerctrlGsMc : Nat = cyclesCreateMainer.cyclesCreateMainerctrlGsMc;
                                    cyclesCreateMainerllmGsMc : Nat = cyclesCreateMainer.cyclesCreateMainerllmGsMc;
                                    cyclesCreateMainerctrlMcMainerctrl : Nat = cyclesCreateMainer.cyclesCreateMainerctrlMcMainerctrl;
                                    cyclesCreateMainerllmMcMainerllm : Nat = cyclesCreateMainer.cyclesCreateMainerllmMcMainerllm;
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

                                let cyclesAdded = cyclesCreateMainer.cyclesCreateMainerllmGsMc; 
                                Cycles.add<system>(cyclesAdded);
                                D.print("GameState: setUpMainerLlmCanister - cycles sent to mAInerCreator = " # debug_show(cyclesAdded) );

                                // This only creates the LLM canister and returns
                                let result : Types.CanisterCreationResult = await creatorCanisterActor.createCanister(canisterCreationInput);
                                D.print("GameState: setUpMainerLlmCanister - createCanister returned " # debug_show(result) );

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
                                        D.print("GameState: setUpMainerLlmCanister - Setting up LLM Canister ID = " # debug_show(canisterCreationRecord.newCanisterId) );
                                        // Setup the LLM canister (install code & configurations)
                                        let setupCanisterInput : Types.SetupCanisterInput = {
                                            newCanisterId : Text = canisterCreationRecord.newCanisterId;
                                            configurationInput : Types.CanisterCreationConfiguration = canisterCreationInput;
                                        };
                                        ignore creatorCanisterActor.setupCanister(setupCanisterInput);

                                        let canisterEntryToAdd : Types.OfficialMainerAgentCanister = {
                                            address : Text = userMainerEntry.address; // Controller 
                                            canisterType: Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                            creationTimestamp : Nat64 = userMainerEntry.creationTimestamp;
                                            createdBy : Principal = Principal.fromText(mainerCreatorEntry.address); // mAIner Creator
                                            ownedBy : Principal = userMainerEntry.ownedBy; // User
                                            status : Types.CanisterStatus = #LlmSetupInProgress(#CanisterCreated); //This is status of the controller
                                            mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                        };
                                        D.print("GameState: setUpMainerLlmCanister - returning canisterEntryToAdd: " # debug_show(canisterEntryToAdd) );  
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

                                let cyclesFromUser : Nat = 10_000_000_000_000; // TODO - get from user payment
                                let cyclesCreateMainer : Types.CyclesCreateMainer = setCyclesCreateMainer(cyclesFromUser, mainerAgentCanisterType);
                                
                                let canisterCreationInput : Types.CanisterCreationConfiguration = {
                                    canisterType : Types.ProtocolCanisterType = #MainerLlm;
                                    owner: Principal = userMainerEntry.ownedBy; // User
                                    associatedCanisterAddress : ?Types.CanisterAddress = ?userMainerEntry.address; // Controller address
                                    mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                    userMainerEntryCreationTimestamp : Nat64 = userMainerEntry.creationTimestamp; // for deduplication by putUserMainerAgent
                                    userMainerEntryCanisterType : Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                    cyclesCreateMainerctrlGsMc : Nat = cyclesCreateMainer.cyclesCreateMainerctrlGsMc;
                                    cyclesCreateMainerllmGsMc : Nat = cyclesCreateMainer.cyclesCreateMainerllmGsMc;
                                    cyclesCreateMainerctrlMcMainerctrl : Nat = cyclesCreateMainer.cyclesCreateMainerctrlMcMainerctrl;
                                    cyclesCreateMainerllmMcMainerllm : Nat = cyclesCreateMainer.cyclesCreateMainerllmMcMainerllm;
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

                                let cyclesAdded = cyclesCreateMainer.cyclesCreateMainerllmGsMc;
                                Cycles.add<system>(cyclesAdded);
                                D.print("GameState: addLlmCanisterToMainer - cycles sent to mAInerCreator = " # debug_show(cyclesAdded) );

                                // This only creates the LLM canister and returns
                                let result : Types.CanisterCreationResult = await creatorCanisterActor.createCanister(canisterCreationInput);
                                D.print("GameState: addLlmCanisterToMainer - createCanister returned " # debug_show(result) );

                                D.print("GameState: addLlmCanisterToMainer - Get cycles balance of mAInerCreator ()"# debug_show(mainerCreatorEntry.address) #  ") after calling createCanister.");
                                var cyclesAfter : Nat = 0;
                                try {
                                    let canisterStatus = await IC_Management_Actor.canister_status({canister_id = Principal.fromText(mainerCreatorEntry.address);});
                                    cyclesAfter := canisterStatus.cycles;
                                } catch (e) {
                                    D.print("GameState: addLlmCanisterToMainer - Failed to retrieve info for mAInerCreator: " # debug_show(mainerCreatorEntry.address)  # Error.message(e) );
                                    return #Err(#Other("GameState: addLlmCanisterToMainer - Failed to retrieve info for mAInerCreator: " # debug_show(mainerCreatorEntry.address) # Error.message(e)));
                                };
                                let cyclesUsed : Nat = cyclesBefore + cyclesAdded - cyclesAfter;
                                D.print("GameState: setUpMainerLaddLlmCanisterToMainerlmCanister - cycles balance of mAInerCreator " # debug_show(mainerCreatorEntry.address) # "after calling createCanister = " # debug_show(cyclesAfter) );  
                                D.print("GameState: addLlmCanisterToMainer - cyclesUsed by mAInerCreator: " # debug_show(cyclesUsed) );

                                switch (result) {
                                    case (#Ok(canisterCreationRecord)) {
                                        D.print("GameState: addLlmCanisterToMainer - Setting up LLM Canister ID = " # debug_show(canisterCreationRecord.newCanisterId) );
                                        // Setup the LLM canister (install code & configurations)
                                        let setupCanisterInput : Types.SetupCanisterInput = {
                                            newCanisterId : Text = canisterCreationRecord.newCanisterId;
                                            configurationInput : Types.CanisterCreationConfiguration = canisterCreationInput;
                                        };
                                        ignore creatorCanisterActor.setupCanister(setupCanisterInput);

                                        let canisterEntryToAdd : Types.OfficialMainerAgentCanister = {
                                            address : Text = userMainerEntry.address; // Controller 
                                            canisterType: Types.ProtocolCanisterType = userMainerEntry.canisterType;
                                            creationTimestamp : Nat64 = userMainerEntry.creationTimestamp;
                                            createdBy : Principal = Principal.fromText(mainerCreatorEntry.address); // mAIner Creator
                                            ownedBy : Principal = userMainerEntry.ownedBy; // User
                                            status : Types.CanisterStatus = #LlmSetupInProgress(#CanisterCreated); //This is status of the controller
                                            mainerConfig : Types.MainerConfigurationInput = userMainerEntry.mainerConfig;
                                        };
                                        D.print("GameState: addLlmCanisterToMainer - returning canisterEntryToAdd: " # debug_show(canisterEntryToAdd) );  
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
            D.print("GameState: submitChallengeResponse - 01");
            return #Err(#Unauthorized);
        };
        // Verify that submission is charged with cycles
        if (Cycles.available() < cyclesSubmitResponse) {
            let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
            D.print("GameState: submitChallengeResponse - 02");
            D.print("GameState: submitChallengeResponse - cycles available: " # debug_show(Cycles.available()));
            D.print("GameState: submitChallengeResponse - cycles required : " # debug_show(cyclesSubmitResponse));
            return #Err(#InsuffientCycles(cyclesSubmitResponse));                    
        };
        // TODO - Implementation: adapt cycles burnt stats based on the mAIner Type.
        ignore increaseTotalProtocolCyclesBurnt(cyclesBurntResponseGenerationShare);
        // Only official mAIner agent canisters may call this
        switch (getMainerAgentCanister(Principal.toText(msg.caller))) {
            case (null) {
                let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
                D.print("GameState: submitChallengeResponse - 03");
                return #Err(#Unauthorized);
            };
            case (?_mainerAgentEntry) {
                // Check that submission record looks correct
                if (challengeResponseSubmissionInput.submittedBy != msg.caller) {
                    let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
                    D.print("GameState: submitChallengeResponse - 04");
                    return #Err(#Unauthorized);
                };

                // Verify that challenge is open
                if (not verifyChallenge(#Open, challengeResponseSubmissionInput.challengeId)) {
                    let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
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
                            let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
                            D.print("GameState: submitChallengeResponse - agentCanisterInfo with null as module hash: " # debug_show(agentCanisterInfo)); 
                            // TODO - Design: further measurements?
                            return #Err(#Unauthorized);
                        };
                        case (?agentModuleHash) {
                            if (Blob.equal(agentModuleHash, officialMainerAgentCanisterWasmHash)) {
                                D.print("GameState: testMainerCodeIntegrityAdmin - agentCanisterInfo with official module hash: " # debug_show(agentCanisterInfo));
                                // continue as check passed
                            } else {
                                let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
                                D.print("GameState: submitChallengeResponse - agentCanisterInfo didn't pass verification: " # debug_show(agentCanisterInfo) # " - expected wasm hash = " # debug_show(officialMainerAgentCanisterWasmHash));
                                 
                                // TODO - Design: further measurements?
                                return #Err(#Unauthorized);
                            };
                        };
                    };
                } catch (e) {
                    let _cyclesKeptForFailedSubmission = Cycles.accept<system>(cyclesFailedSubmissionCut);
                    D.print("GameState: submitChallengeResponse - Failed to retrieve info for mAIner: " # debug_show(challengeResponseSubmissionInput) # Error.message(e));      
                    return #Err(#Other("GameState: testMainerCodeIntegrityAdmin - Failed to retrieve info for mAIner: " # debug_show(challengeResponseSubmissionInput) # Error.message(e)));
                };

                // Accept required cycles for submission
                let cyclesAcceptedForSubmission = Cycles.accept<system>(cyclesSubmitResponse);
                if (cyclesAcceptedForSubmission != cyclesSubmitResponse) {
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
                    mainerPromptId : Text = challengeResponseSubmissionInput.mainerPromptId;
                    judgePromptId : Text = challengeResponseSubmissionInput.judgePromptId;
                    challengeId : Text = challengeResponseSubmissionInput.challengeId;
                    challengeCreationTimestamp : Nat64 = challengeResponseSubmissionInput.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = challengeResponseSubmissionInput.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = challengeResponseSubmissionInput.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = challengeResponseSubmissionInput.challengeClosedTimestamp;
                    cyclesSubmitResponse : Nat = challengeResponseSubmissionInput.cyclesSubmitResponse;
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
                                            mainerPromptId : Text = submission.mainerPromptId;
                                            judgePromptId : Text = submission.judgePromptId;
                                            challengeId : Text = submission.challengeId;
                                            challengeCreationTimestamp : Nat64 = submission.challengeCreationTimestamp;
                                            challengeCreatedBy : Types.CanisterAddress = submission.challengeCreatedBy;
                                            challengeStatus : Types.ChallengeStatus = submission.challengeStatus;
                                            challengeClosedTimestamp : ?Nat64 = submission.challengeClosedTimestamp;
                                            cyclesSubmitResponse : Nat = submission.cyclesSubmitResponse;
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
        ignore increaseTotalProtocolCyclesBurnt(cyclesBurntJudgeScoring);
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
                    mainerPromptId : Text = scoredResponseInput.mainerPromptId;
                    judgePromptId : Text = scoredResponseInput.judgePromptId;
                    challengeId : Text = scoredResponseInput.challengeId;
                    challengeCreationTimestamp : Nat64 = scoredResponseInput.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = scoredResponseInput.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = scoredResponseInput.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = scoredResponseInput.challengeClosedTimestamp;
                    cyclesSubmitResponse : Nat = scoredResponseInput.cyclesSubmitResponse;
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
                    mainerPromptId : Text = scoredResponseInput.mainerPromptId;
                    judgePromptId : Text = scoredResponseInput.judgePromptId;
                    challengeId : Text = scoredResponseInput.challengeId;
                    challengeCreationTimestamp : Nat64 = scoredResponseInput.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = scoredResponseInput.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = scoredResponseInput.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = scoredResponseInput.challengeClosedTimestamp;
                    cyclesSubmitResponse : Nat = scoredResponseInput.cyclesSubmitResponse;
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
                    mainerPromptId : Text = openChallenge.mainerPromptId;
                    judgePromptId : Text = openChallenge.judgePromptId;
                    challengeId : Text = openChallenge.challengeId;
                    challengeCreationTimestamp : Nat64 = openChallenge.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = openChallenge.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = openChallenge.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = openChallenge.challengeClosedTimestamp;
                    cyclesSubmitResponse : Nat = openChallenge.cyclesSubmitResponse;
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
                            mainerPromptId : Text = closedChallenge.mainerPromptId;
                            judgePromptId : Text = closedChallenge.judgePromptId;
                            challengeId : Text = closedChallenge.challengeId;
                            challengeCreationTimestamp : Nat64 = closedChallenge.challengeCreationTimestamp;
                            challengeCreatedBy : Types.CanisterAddress = closedChallenge.challengeCreatedBy;
                            challengeStatus : Types.ChallengeStatus = closedChallenge.challengeStatus;
                            challengeClosedTimestamp : ?Nat64 = closedChallenge.challengeClosedTimestamp;
                            cyclesSubmitResponse : Nat = closedChallenge.cyclesSubmitResponse;
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
                            mainerPromptId : Text = "submissionInput.mainerPromptId";
                            judgePromptId : Text = "submissionInput.judgePromptId";
                            challengeId : Text = submissionInput.challengeId;
                            challengeCreationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                            challengeCreatedBy : Types.CanisterAddress = "";
                            challengeStatus : Types.ChallengeStatus = #Archived;
                            challengeClosedTimestamp : ?Nat64 = ?Nat64.fromNat(Int.abs(Time.now()));
                            cyclesSubmitResponse : Nat = cyclesSubmitResponse;
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
        mainerPromptsStable := Iter.toArray(mainerPrompts.entries());
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
        mainerPrompts := HashMap.fromIter(Iter.fromArray(mainerPromptsStable), openChallengeTopicsStorageStable.size(), Text.equal, Text.hash);
        mainerPromptsStable := [];
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
