import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Cycles "mo:base/ExperimentalCycles";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import D "mo:base/Debug";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Error "mo:base/Error";
import List "mo:base/List";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Random "mo:base/Random";

import Types "../../common/Types";
import TokenLedger "../../common/icp-ledger-interface";
import LiquidityPool "../../common/icpswap-liquidity-pool-interface";

actor class TreasuryCanister() = this {

    stable var MASTER_CANISTER_ID : Text = "r5m5y-diaaa-aaaaa-qanaa-cai"; // prd

    public shared (msg) func setMasterCanisterId(_master_canister_id : Text) : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        MASTER_CANISTER_ID := _master_canister_id;
        let authRecord = { auth = "You set the master canister for this canister." };
        return #Ok(authRecord);
    };

    public shared (msg) func getMasterCanisterId() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = { auth = "Master canister id: " # MASTER_CANISTER_ID };
        return #Ok(authRecord);
    };

    var TOKEN_LEDGER_CANISTER_ID : Text = "vpyot-zqaaa-aaaaa-qavaq-cai";

    let ICP_LEDGER_ACTOR : TokenLedger.TOKEN_LEDGER = Types.IcpLedger_Actor;

    let LIQUIDITY_POOL_ACTOR : LiquidityPool.LIQUIDITY_POOL = Types.FunnaiIcpLiquidityPool_Actor;

    let thisAccount : TokenLedger.Account = {
        owner : Principal = Principal.fromActor(this);
        subaccount : ?Blob = null;
    };

    let TREASURY_PRINCIPAL_BLOB : Blob = Principal.toLedgerAccount(Principal.fromActor(this), null);
    // Construct subaccount for the canister principal
    private func principalToSubaccount(principal : Principal) : Blob {
        let sub = Buffer.Buffer<Nat8>(32);
        let subaccount_blob = Principal.toBlob(principal);

        sub.add(Nat8.fromNat(subaccount_blob.size()));
        sub.append(Buffer.fromArray<Nat8>(Blob.toArray(subaccount_blob)));
        while (sub.size() < 32) {
            sub.add(0);
        };

        Blob.fromArray(Buffer.toArray(sub));
    };
    let TREASURY_SUBACCOUNT : Blob = principalToSubaccount(Principal.fromActor(this));

// Parameters
    // Flag to toggle whether incoming ICP should be converted to FUNNAI
    stable var CONVERT_ICP_TO_FUNNAI : Bool = true;

    public shared (msg) func toggleConvertIcpToFunnaiFlagAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        CONVERT_ICP_TO_FUNNAI := not CONVERT_ICP_TO_FUNNAI;
        let authRecord = { auth = "You set the flag to " # debug_show(CONVERT_ICP_TO_FUNNAI) };
        return #Ok(authRecord);
    };

    public query (msg) func getConvertIcpToFunnaiFlag() : async Types.FlagResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        return #Ok({ flag = CONVERT_ICP_TO_FUNNAI });
    };

    // Threshold of minimum ICP balance to keep
    stable var MINIMUM_ICP_BALANCE : Nat = 30; // in full ICP

    public shared (msg) func setMinimumIcpBalance(newBalance : Nat) : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        MINIMUM_ICP_BALANCE := newBalance;
        let authRecord = { auth = "You set the balance." };
        return #Ok(authRecord);
    };

    public query (msg) func getMinimumIcpBalance() : async Types.NatResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        return #Ok(MINIMUM_ICP_BALANCE);
    };

    // Parameter to set the smallest amount that will be added from the treasury to add to the incoming ICP to be converted
    let E8S_PER_ICP : Nat = 100_000_000; // 10^8 e8s per ICP

    stable var ICP_BASE_AMOUNT : Nat = 8_000_000; // 0.08 ICP

    public shared (msg) func setIcpBaseAmount(newIcpBaseAmount : Nat) : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        ICP_BASE_AMOUNT := newIcpBaseAmount;
        let authRecord = { auth = "You set the ICP base amount." };
        return #Ok(authRecord);
    };

    public shared (msg) func getIcpBaseAmount() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = { auth = "ICP base amount: " # debug_show(ICP_BASE_AMOUNT) };
        return #Ok(authRecord);
    };

    // Flag to toggle whether ICP should be disbursed to developers (as payment for their services)
    stable var DISBURSE_FUNDS_TO_DEVELOPERS : Bool = false;

    public shared (msg) func toggleDisburseFundsToDevelopersFlagAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        DISBURSE_FUNDS_TO_DEVELOPERS := not DISBURSE_FUNDS_TO_DEVELOPERS;
        let authRecord = { auth = "You set the flag to " # debug_show(DISBURSE_FUNDS_TO_DEVELOPERS) };
        return #Ok(authRecord);
    };

    public query (msg) func getDisburseFundsToDevelopersFlag() : async Types.FlagResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        return #Ok({ flag = DISBURSE_FUNDS_TO_DEVELOPERS });
    };

    // Flag to toggle whether cycles should be disbursed to developers (as payment for their services)
    stable var DISBURSE_CYCLES_TO_DEVELOPERS : Bool = false;

    public shared (msg) func toggleDisburseCyclesToDevelopersFlagAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        DISBURSE_CYCLES_TO_DEVELOPERS := not DISBURSE_CYCLES_TO_DEVELOPERS;
        let authRecord = { auth = "You set the flag to " # debug_show(DISBURSE_CYCLES_TO_DEVELOPERS) };
        return #Ok(authRecord);
    };

    public query (msg) func getDisburseCyclesToDevelopersFlag() : async Types.FlagResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        return #Ok({ flag = DISBURSE_CYCLES_TO_DEVELOPERS });
    };

    // Percentage of ICP to disburse to developers
    stable var DEVELOPER_SHARE_ICP : Nat = 1; // as parts of 10000, i.e. 100 are 1%, 10000 are 100%, etc

    public shared (msg) func setDeveloperShareIcp(newDeveloperShare : Nat) : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (newDeveloperShare > 3000) {
            return #Err(#Unauthorized);
        };
        DEVELOPER_SHARE_ICP := newDeveloperShare;
        let authRecord = { auth = "You set the ICP developer share." };
        return #Ok(authRecord);
    };

    public shared (msg) func getDeveloperShareIcp() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = { auth = "ICP developer share: " # debug_show(DEVELOPER_SHARE_ICP) };
        return #Ok(authRecord);
    };

    // Flag to toggle whether treasury should burn the specified percentage of incoming FUNNAI
    stable var BURN_INCOMING_FUNNAI : Bool = false;

    public shared (msg) func toggleBurnIncomingFunnaiFlagAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        BURN_INCOMING_FUNNAI := not BURN_INCOMING_FUNNAI;
        let authRecord = { auth = "You set the flag to " # debug_show(BURN_INCOMING_FUNNAI) };
        return #Ok(authRecord);
    };

    public query (msg) func getBurnIncomingFunnaiFlag() : async Types.FlagResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        return #Ok({ flag = BURN_INCOMING_FUNNAI });
    };

    // Percentage of incoming FUNNAI to burn (remainder will be kept)
    stable var BURN_SHARE_FUNNAI : Nat = 1; // as parts of 10000, i.e. 100 are 1%, 10000 are 100%, etc

    public shared (msg) func setBurnShareFunnai(newBurnShare : Nat) : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (newBurnShare > 10000) {
            return #Err(#Unauthorized);
        };
        BURN_SHARE_FUNNAI := newBurnShare;
        let authRecord = { auth = "You set the FUNNAI burn share." };
        return #Ok(authRecord);
    };

    public shared (msg) func getBurnShareFunnai() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = { auth = "FUNNAI burn share: " # debug_show(BURN_SHARE_FUNNAI) };
        return #Ok(authRecord);
    };

    // Flag to toggle whether treasury should add the specified percentage of incoming FUNNAI as liquidity
    stable var LIQUIDITY_ADDITION_INCOMING_FUNNAI : Bool = false;

    public shared (msg) func toggleLiquidityAdditionIncomingFunnaiFlagAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        LIQUIDITY_ADDITION_INCOMING_FUNNAI := not LIQUIDITY_ADDITION_INCOMING_FUNNAI;
        let authRecord = { auth = "You set the flag to " # debug_show(LIQUIDITY_ADDITION_INCOMING_FUNNAI) };
        return #Ok(authRecord);
    };

    public query (msg) func getLiquidityAdditionIncomingFunnaiFlag() : async Types.FlagResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        return #Ok({ flag = LIQUIDITY_ADDITION_INCOMING_FUNNAI });
    };

    // Percentage of incoming FUNNAI to add as liquidity (remainder is kept)
    stable var LIQUIDITY_SHARE_FUNNAI : Nat = 1; // as parts of 10000, i.e. 100 are 1%, 10000 are 100%, etc

    public shared (msg) func setLiquidityShareFunnai(newLiquidityShare : Nat) : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (newLiquidityShare > 10000) {
            return #Err(#Unauthorized);
        };
        LIQUIDITY_SHARE_FUNNAI := newLiquidityShare;
        let authRecord = { auth = "You set the FUNNAI liquidity share." };
        return #Ok(authRecord);
    };

    public shared (msg) func getLiquidityShareFunnai() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = { auth = "FUNNAI liquidity share: " # debug_show(LIQUIDITY_SHARE_FUNNAI) };
        return #Ok(authRecord);
    };

    // Flag to toggle whether treasury should match the FUNNAI to be added as liquidity with ICP
    stable var MATCH_LIQUIDITY_ADDITION_ICP : Bool = false;

    public shared (msg) func toggleMatchLiquidityAdditionIcpFlagAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        MATCH_LIQUIDITY_ADDITION_ICP := not MATCH_LIQUIDITY_ADDITION_ICP;
        let authRecord = { auth = "You set the flag to " # debug_show(MATCH_LIQUIDITY_ADDITION_ICP) };
        return #Ok(authRecord);
    };

    public query (msg) func getMatchLiquidityAdditionIcpFlag() : async Types.FlagResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        return #Ok({ flag = MATCH_LIQUIDITY_ADDITION_ICP });
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

    // Official balances // TODO - Implementation: decide if needed   
    stable var icpBalance : Nat = 0; 
    stable var funnaiBalance : Nat = 0;

    // Disbursements (received from Game State)
    stable var icpDisbursementsStorage : List.List<Types.TokenDisbursement> = List.nil<Types.TokenDisbursement>();

    // Tokenomics actions taken by this canister
    stable var tokenomicsActionsStorage : List.List<Types.TokenomicsAction> = List.nil<Types.TokenomicsAction>();
    stable var tokenomicsActionCounter : Nat64 = 0;

    private func putTokenomicsAction(actionEntry : Types.TokenomicsAction) : Types.TokenomicsAction {
        tokenomicsActionsStorage := List.push<Text>(actionEntry, tokenomicsActionsStorage);
        tokenomicsActionCounter := tokenomicsActionCounter + 1;
        return actionEntry;
    };

    // Function for Game State canister to notify treasury of a disbursement and kick off its handling
    public shared (msg) func notifyDisbursement(disbursementInfo : Types.NotifyDisbursementInput) : async Types.NotifyDisbursementResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.equal(msg.caller, Principal.fromText(MASTER_CANISTER_ID))) {
            return #Err(#Unauthorized);
        };
        D.print("treasury notifyDisbursement disbursementInfo: " # debug_show(disbursementInfo));

        // Game State can make official disbursements
        icpBalance := icpBalance + disbursementInfo.disbursementAmount;
        let disbursementEntry : Types.TokenDisbursement = {
            transactionId : Nat64 = disbursementInfo.transactionId;
            disbursementAmount : Nat = disbursementInfo.disbursementAmount;
            newIcpBalance : Nat = icpBalance;
            creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            sentBy : Principal = msg.caller;
        };
        icpDisbursementsStorage := List.push<Types.TokenDisbursement>(disbursementEntry, icpDisbursementsStorage);

        // TODO - Implementation: trigger tokenomics actions to handle disbursementAmount
        ignore handleDisbursement(disbursementEntry);
        
        return #Ok({
            disbursementHandled : Bool = true;
        });
    };

    private func handleDisbursement(disbursementEntry : Types.TokenDisbursement) : async Types.NotifyDisbursementResult {
        D.print("treasury handleDisbursement disbursementEntry: " # debug_show(disbursementEntry));

        // Only continue if the treasury currently has more than then minumim ICP balance
        let currentBalance : Nat = await ICP_LEDGER_ACTOR.icrc1_balance_of(thisAccount);
        if (currentBalance < MINIMUM_ICP_BALANCE * E8S_PER_ICP) {
            return #Err(#Other("Below minimum ICP balance"));
        };

        // Disbursement to developers
        if (DISBURSE_FUNDS_TO_DEVELOPERS) {
            // TODO: disburse DEVELOPER_SHARE_ICP (and adapt logic beyond accordingly as ICP for tokenomics is reduced)           
        };

        if (DISBURSE_CYCLES_TO_DEVELOPERS) {
            // TODO: call  Game State to disburse cycles            
        };

        if (CONVERT_ICP_TO_FUNNAI) {
            // Convert ICP to FUNNAI and then handle received FUNNAI
            ignore handleTokenomicsActions(disbursementEntry);
        };
        
        return #Ok({
            disbursementHandled : Bool = true;
        });
    };

    private func handleTokenomicsActions(disbursementEntry : Types.TokenDisbursement) : async Types.NotifyDisbursementResult {
        D.print("treasury handleTokenomicsActions disbursementEntry: " # debug_show(disbursementEntry));

        if (not CONVERT_ICP_TO_FUNNAI) {
            return #Err(#Other("Conversions aren't enabled"));
        }; 

        // Convert ICP to FUNNAI
        // Verify block
        let getBlocksArgs : TokenLedger.GetBlocksArgs = {
            start : Nat64 = disbursementEntry.transactionId;
            length : Nat64 = 1;
        };
        D.print("Treasury: handleTokenomicsActions - getBlocksArgs: "# debug_show(getBlocksArgs));
        let queryBlocksResponse : TokenLedger.QueryBlocksResponse = await ICP_LEDGER_ACTOR.query_blocks(getBlocksArgs);
        D.print("Treasury: handleTokenomicsActions - queryBlocksResponse.blocks: "# debug_show(queryBlocksResponse.blocks));
        // Verify transaction exists
        if (queryBlocksResponse.blocks.size() < 1) {
            return #Err(#InvalidId);
        };
        let retrievedTransaction : TokenLedger.CandidTransaction = queryBlocksResponse.blocks[0].transaction;
        D.print("Treasury: handleTokenomicsActions - retrievedTransaction: "# debug_show(retrievedTransaction));        
        // Verify transaction went to Treasury's account
        D.print("Treasury: handleTokenomicsActions - retrievedTransaction.operation: "# debug_show(retrievedTransaction.operation));
        switch (retrievedTransaction.operation) {
            case (null) {
                D.print("Treasury: handleTokenomicsActions - retrievedTransaction.operation: null");
                return #Err(#Other("Couldn't verify transaction operation details"));  
            };
            case (?transactionOperation) {
                D.print("Treasury: handleTokenomicsActions - transactionOperation: "# debug_show(transactionOperation));
                switch (transactionOperation) {
                    case (#Transfer(transferDetails)) {
                        D.print("Treasury: handleTokenomicsActions - #Transfer transferDetails: "# debug_show(transferDetails));
                        D.print("Treasury: handleTokenomicsActions - transferDetails.to: "# debug_show(transferDetails.to));
                        D.print("Treasury: handleTokenomicsActions - TREASURY_PRINCIPAL_BLOB: "# debug_show(TREASURY_PRINCIPAL_BLOB));
                        D.print("Treasury: handleTokenomicsActions - toLedgerAccount: "# debug_show(Principal.toLedgerAccount(Principal.fromActor(this), null)));
                        if (Blob.notEqual(transferDetails.to, TREASURY_PRINCIPAL_BLOB)) {
                            return #Err(#Other("Transaction didn't go to Treasury's address")); 
                        };

                        let amountReceived = Nat64.toNat(transferDetails.amount.e8s);
                        D.print("Treasury: handleTokenomicsActions - amountReceived: "# debug_show(amountReceived));

                        // Determine how much extra ICP (from Treasury's balance) to convert as well
                        let randomExtraIcpToConvert = ICP_BASE_AMOUNT;
                        try {
                            let random = Random.Finite(await Random.blob());
                            let randomValueResult = random.range(4); // Uniformly distributes outcomes in the numeric range [0 .. 2^4 - 1] = [0 .. 15]
                            switch (randomValueResult) {
                                case (?randomValue) {
                                    randomExtraIcpToConvert := (randomValue + 1) * randomExtraIcpToConvert; // i.e. range is between ICP_BASE_AMOUNT and 16 times ICP_BASE_AMOUNT (e.g. 0.08 and 1.28 ICP)                
                                };
                                case (_) {
                                    // Something went wrong with the random generation, use default
                                };
                            };
                        } catch (error : Error) {
                            D.print("Treasury: handleTokenomicsActions error in generating randomExtraIcpToConvert: " # Error.message(error));
                            // Some error occurred, use default
                        };

                        let totalIcpToConvert = amountReceived + randomExtraIcpToConvert; // in e8s

                        // Convert ICP to FUNNAI via swap
                        let swapResult = await swapIcpToFunnai(totalIcpToConvert, disbursementEntry);

                        // Handle received FUNNAI

                        BURN_INCOMING_FUNNAI

                        BURN_SHARE_FUNNAI

                        LIQUIDITY_ADDITION_INCOMING_FUNNAI

                        LIQUIDITY_SHARE_FUNNAI

                        MATCH_LIQUIDITY_ADDITION_ICP
                        

                        
                        return #Ok({
                            disbursementHandled : Bool = true;
                        });
                    };
                };
            };
        };
    };

    private func swapIcpToFunnai(icpToConvert : Nat, disbursementEntry : Types.TokenDisbursement) : async Types.TokenSwapResult {
        // Get a quote, then swap (https://github.com/ICPSwap-Labs/docs/blob/main/02.SwapPool/Swap/03.Executing_DepositAndSwap.md)
        let amountToConvert : Text = Nat.toText(icpToConvert);
        let amountOutMinimum : Nat = icpToConvert * 9 / 10; // max 10% slippage
        let swapArgs : LiquidityPool.SwapArgs = {
            amountIn : Text = amountToConvert;
            zeroForOne : Bool = true; // ICP for FUNNAI
            amountOutMinimum : Text = "0"; // not used in quote
        };
        try {
            let quoteResult : LiquidityPool.Result = await LIQUIDITY_POOL_ACTOR.quote(swapArgs);
            switch (quoteResult) {
                case (#ok(quotedReceivedAmount)) {
                    D.print("Treasury: swapIcpToFunnai quotedReceivedAmount: " # debug_show(quotedReceivedAmount));
                    if (quotedReceivedAmount < amountOutMinimum) {
                        D.print("Treasury: swapIcpToFunnai Slippage is too high: " # debug_show(quotedReceivedAmount)  # debug_show(amountOutMinimum));
                        return #Err(#Other("Slippage is too high: " # debug_show(quotedReceivedAmount)  # debug_show(amountOutMinimum)));
                    };

                    let depositAndSwapArgs : LiquidityPool.DepositAndSwapArgs = {
                        amountIn : Text = amountToConvert;
                        zeroForOne : Bool = true; // ICP for FUNNAI
                        amountOutMinimum : Text = Nat.toText(amountOutMinimum);
                        tokenInFee : Nat = 10000; // ICP
                        tokenOutFee : Nat = 1; // FUNNAI
                    };

                    let depositAndSwapResult : LiquidityPool.Result = await LIQUIDITY_POOL_ACTOR.depositAndSwap(depositAndSwapArgs);
                    switch (depositAndSwapResult) {
                        case (#ok(receivedAmount)) {
                            // Store Swap tokenomics action
                            let creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                            let newEntry : Types.TokenomicsAction = {
                                token : Types.TokenomicsActionTokens = #ICP;
                                amount : Nat = icpToConvert;
                                creationTimestamp : Nat64 = creationTimestamp;
                                additionalToken : ?Types.TokenomicsActionTokens = ?#FUNNAI;
                                additionalTokenAmount : Nat = receivedAmount;
                                actionId : Nat64 = tokenomicsActionCounter;
                                actionType : TokenomicsActionType = #Swap;
                                associatedTransactionId : ?Nat64 = null;
                                transactionIdDisbursement : ?Nat64 = ?disbursementEntry.transactionId;
                                newIcpBalance : Nat = disbursementEntry.newIcpBalance;
                            };                           

                            _ = putTokenomicsAction(newEntry);

                            let result : Types.TokenSwapRecord = {
                                token : Types.TokenomicsActionTokens = #ICP;
                                amount : Nat = icpToConvert;
                                creationTimestamp : Nat64 = creationTimestamp;
                                additionalToken : Types.TokenomicsActionTokens = #FUNNAI;
                                additionalTokenAmount : Nat = receivedAmount;
                            };
                            return #Ok(result);
                        };
                        case (#err(err)) {
                            D.print("Treasury: swapIcpToFunnai depositAndSwapResult Err: " # debug_show(err));
                            return #Err(#Other("DepositAndSwap error: " # debug_show(err)));
                        };
                    };
                };
                case (#err(err)) {
                    D.print("Treasury: swapIcpToFunnai quoteResult Err: " # debug_show(err));
                    return #Err(#Other("Quote error: " # debug_show(err)));
                };
            };
        } catch (error : Error) {
            D.print("Treasury: swapIcpToFunnai error: " # Error.message(error));
            return #Err(#FailedOperation);         
        };
    };
};