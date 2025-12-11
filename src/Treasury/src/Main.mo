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
import Buffer "mo:base/Buffer";

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
        let authRecord = {
            auth = "You set the master canister for this canister.";
        };
        return #Ok(authRecord);
    };

    public query (msg) func getMasterCanisterId() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = { auth = "Master canister id: " # MASTER_CANISTER_ID };
        return #Ok(authRecord);
    };

    let ICP_LEDGER_ACTOR : TokenLedger.TOKEN_LEDGER = Types.IcpLedger_Actor;

    let LIQUIDITY_POOL_ACTOR : LiquidityPool.LIQUIDITY_POOL = Types.FunnaiIcpLiquidityPool_Actor;

    let thisAccount : TokenLedger.Account = {
        owner : Principal = Principal.fromActor(this);
        subaccount : ?Blob = null;
    };

    let liquidityPoolAccount : TokenLedger.Account = {
        owner : Principal = Principal.fromActor(LIQUIDITY_POOL_ACTOR);
        subaccount : ?Blob = null;
    };

    let TOKEN_LEDGER_CANISTER_ID : Text = "vpyot-zqaaa-aaaaa-qavaq-cai";

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

    let TokenLedger_Actor : TokenLedger.TOKEN_LEDGER = actor (TOKEN_LEDGER_CANISTER_ID);

    let liquidityPoolAccountWithTreasurySubaccount : TokenLedger.Account = {
        owner : Principal = Principal.fromActor(LIQUIDITY_POOL_ACTOR);
        subaccount : ?Blob = ?TREASURY_SUBACCOUNT;
    };

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
        let authRecord = {
            auth = "You set the flag to " # debug_show (CONVERT_ICP_TO_FUNNAI);
        };
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

    public query (msg) func getIcpBaseAmount() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = {
            auth = "ICP base amount: " # debug_show (ICP_BASE_AMOUNT);
        };
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
        let authRecord = {
            auth = "You set the flag to " # debug_show (DISBURSE_FUNDS_TO_DEVELOPERS);
        };
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
        let authRecord = {
            auth = "You set the flag to " # debug_show (DISBURSE_CYCLES_TO_DEVELOPERS);
        };
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

    public query (msg) func getDeveloperShareIcp() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = {
            auth = "ICP developer share: " # debug_show (DEVELOPER_SHARE_ICP);
        };
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
        let authRecord = {
            auth = "You set the flag to " # debug_show (BURN_INCOMING_FUNNAI);
        };
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

    public query (msg) func getBurnShareFunnai() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = {
            auth = "FUNNAI burn share: " # debug_show (BURN_SHARE_FUNNAI);
        };
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
        let authRecord = {
            auth = "You set the flag to " # debug_show (LIQUIDITY_ADDITION_INCOMING_FUNNAI);
        };
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

    public query (msg) func getLiquidityShareFunnai() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = {
            auth = "FUNNAI liquidity share: " # debug_show (LIQUIDITY_SHARE_FUNNAI);
        };
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
        let authRecord = {
            auth = "You set the flag to " # debug_show (MATCH_LIQUIDITY_ADDITION_ICP);
        };
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
        tokenomicsActionsStorage := List.push<Types.TokenomicsAction>(actionEntry, tokenomicsActionsStorage);
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
        D.print("treasury notifyDisbursement disbursementInfo: " # debug_show (disbursementInfo));

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
        D.print("treasury handleDisbursement disbursementEntry: " # debug_show (disbursementEntry));

        // Only continue if the treasury currently has more than then minumim ICP balance
        try {
            let currentBalance : Nat = await ICP_LEDGER_ACTOR.icrc1_balance_of(thisAccount);
            icpBalance := currentBalance; // Reset official balance
            if (currentBalance < MINIMUM_ICP_BALANCE * E8S_PER_ICP) {
                return #Err(#Other("Below minimum ICP balance"));
            };
            D.print("treasury handleDisbursement icpBalance: " # debug_show (icpBalance));
        } catch (error : Error) {
            D.print("Treasury: handleDisbursement error: " # Error.message(error));
            return #Err(#FailedOperation);
        };

        // Disbursement to developers
        if (DISBURSE_FUNDS_TO_DEVELOPERS) {
            // TODO: disburse DEVELOPER_SHARE_ICP (and adapt logic beyond accordingly as ICP for tokenomics is reduced)
        };

        if (DISBURSE_CYCLES_TO_DEVELOPERS) {
            // TODO: call Game State to disburse cycles
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
        D.print("treasury handleTokenomicsActions disbursementEntry: " # debug_show (disbursementEntry));

        if (not CONVERT_ICP_TO_FUNNAI) {
            return #Err(#Other("Conversions aren't enabled"));
        };

        // Convert ICP to FUNNAI
        try {
            // Verify block
            let getBlocksArgs : TokenLedger.GetBlocksArgs = {
                start : Nat64 = disbursementEntry.transactionId;
                length : Nat64 = 1;
            };
            D.print("Treasury: handleTokenomicsActions - getBlocksArgs: " # debug_show (getBlocksArgs));
            let queryBlocksResponse : TokenLedger.QueryBlocksResponse = await ICP_LEDGER_ACTOR.query_blocks(getBlocksArgs);
            D.print("Treasury: handleTokenomicsActions - queryBlocksResponse.blocks: " # debug_show (queryBlocksResponse.blocks));
            // Verify transaction exists
            if (queryBlocksResponse.blocks.size() < 1) {
                return #Err(#InvalidId);
            };
            let retrievedTransaction : TokenLedger.CandidTransaction = queryBlocksResponse.blocks[0].transaction;
            D.print("Treasury: handleTokenomicsActions - retrievedTransaction: " # debug_show (retrievedTransaction));
            // Verify transaction went to Treasury's account
            D.print("Treasury: handleTokenomicsActions - retrievedTransaction.operation: " # debug_show (retrievedTransaction.operation));
            switch (retrievedTransaction.operation) {
                case (null) {
                    D.print("Treasury: handleTokenomicsActions - retrievedTransaction.operation: null");
                    return #Err(#Other("Couldn't verify transaction operation details"));
                };
                case (?transactionOperation) {
                    D.print("Treasury: handleTokenomicsActions - transactionOperation: " # debug_show (transactionOperation));
                    switch (transactionOperation) {
                        case (#Transfer(transferDetails)) {
                            D.print("Treasury: handleTokenomicsActions - #Transfer transferDetails: " # debug_show (transferDetails));
                            D.print("Treasury: handleTokenomicsActions - transferDetails.to: " # debug_show (transferDetails.to));
                            D.print("Treasury: handleTokenomicsActions - TREASURY_PRINCIPAL_BLOB: " # debug_show (TREASURY_PRINCIPAL_BLOB));
                            D.print("Treasury: handleTokenomicsActions - toLedgerAccount: " # debug_show (Principal.toLedgerAccount(Principal.fromActor(this), null)));
                            if (Blob.notEqual(transferDetails.to, TREASURY_PRINCIPAL_BLOB)) {
                                return #Err(#Other("Transaction didn't go to Treasury's address"));
                            };

                            let amountReceived = Nat64.toNat(transferDetails.amount.e8s);
                            D.print("Treasury: handleTokenomicsActions - amountReceived: " # debug_show (amountReceived));

                            // Determine how much extra ICP (from Treasury's balance) to convert as well
                            var randomExtraIcpToConvert = ICP_BASE_AMOUNT;
                            if (amountReceived + 16 * randomExtraIcpToConvert >= icpBalance) {
                                // balance is too low to handle extra ICP
                                randomExtraIcpToConvert := 0;
                            } else {
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
                            };
                            
                            D.print("Treasury: handleTokenomicsActions - randomExtraIcpToConvert: " # debug_show (randomExtraIcpToConvert));

                            let totalIcpToConvert = amountReceived + randomExtraIcpToConvert; // in e8s
                            D.print("Treasury: handleTokenomicsActions - totalIcpToConvert: " # debug_show (totalIcpToConvert));

                            // Convert ICP to FUNNAI via swap
                            let swapResult : Types.TokenSwapResult = await swapIcpToFunnai(totalIcpToConvert, disbursementEntry);
                            D.print("Treasury: handleTokenomicsActions - swapResult: " # debug_show (swapResult));

                            switch (swapResult) {
                                case (#Ok(swapRecord)) {
                                    D.print("Treasury: handleTokenomicsActions - swapRecord: " # debug_show (swapRecord));
                                    // Handle received FUNNAI
                                    ignore handleReceivedFunnai(swapRecord.additionalTokenAmount, disbursementEntry);

                                    return #Ok({
                                        disbursementHandled : Bool = true;
                                    });
                                };
                                case (#Err(err)) {
                                    D.print("Treasury: handleTokenomicsActions swapResult Err: " # debug_show (err));
                                    return #Err(#Other("Swap error: " # debug_show (err)));
                                };
                            };
                        };
                        case (_) { return #Err(#Other("Transaction wasn't sent correctly")); }
                    };
                };
            };
        } catch (error : Error) {
            D.print("Treasury: handleTokenomicsActions error: " # Error.message(error));
            return #Err(#FailedOperation);
        };
    };

    // Helper function to burn FUNNAI tokens on the token ledger (by sending them to Game State)
    private func burnFunnaiTransaction(funnaiToBurn : Nat) : async Nat {
        D.print("Treasury: burnFunnaiTransaction funnaiToBurn: " # debug_show (funnaiToBurn));
        let args : TokenLedger.TransferArg = {
            from_subaccount = null;
            to = {
                owner = Principal.fromText(MASTER_CANISTER_ID); // Game State is the minting account, sending tokens to it thus burns them
                subaccount = null;
            };
            amount = funnaiToBurn;
            fee = null;
            memo = null;
            created_at_time = null;
        };
        D.print("Treasury: burnFunnaiTransaction args: " # debug_show (args));

        try {
            // Call the ledger's icrc1_transfer function
            let result = await TokenLedger_Actor.icrc1_transfer(args);
            D.print("Treasury: burnFunnaiTransaction result: " # debug_show (result));

            switch (result) {
                case (#Ok(blockIndex)) {
                    D.print("Treasury: burnFunnaiTransaction - sending tokens successful: " # debug_show (blockIndex));
                    D.print("Treasury: burnFunnaiTransaction funnaiBalance initial: " # debug_show (funnaiBalance));
                    if (funnaiBalance > funnaiToBurn) {
                        funnaiBalance := funnaiBalance - funnaiToBurn;
                    } else {
                        funnaiBalance := 0;
                    };
                    D.print("Treasury: burnFunnaiTransaction funnaiBalance after update: " # debug_show (funnaiBalance));
                    return blockIndex;
                };
                case (#Err(err)) {
                    D.print("Treasury: burnFunnaiTransaction - Transfer error: " # debug_show (err));
                    // TODO - Error Handling (e.g. put into queue and try again later)
                    return 0;
                };
            };
        } catch (e) {
            D.print("Treasury: burnFunnaiTransaction - Failed to call ledger: " # Error.message(e));
            // TODO - Error Handling (e.g. put into queue and try again later)
            return 0;
        };
    };

    private func handleReceivedFunnai(funnaiReceived : Nat, disbursementEntry : Types.TokenDisbursement) : async Types.TokenomicsActionResult {
        D.print("Treasury: handleReceivedFunnai - funnaiReceived: " # debug_show (funnaiReceived));
        D.print("Treasury: handleReceivedFunnai - disbursementEntry: " # debug_show (disbursementEntry));
        D.print("Treasury: handleReceivedFunnai - BURN_INCOMING_FUNNAI: " # debug_show (BURN_INCOMING_FUNNAI));
        D.print("Treasury: handleReceivedFunnai - LIQUIDITY_ADDITION_INCOMING_FUNNAI: " # debug_show (LIQUIDITY_ADDITION_INCOMING_FUNNAI));
        var result : Types.TokenomicsActionResult = #Err(#Other("No action taken"));
        if (BURN_INCOMING_FUNNAI) {
            D.print("Treasury: handleReceivedFunnai - BURN_SHARE_FUNNAI: " # debug_show (BURN_SHARE_FUNNAI));
            let funnaiToBurn : Nat = funnaiReceived * BURN_SHARE_FUNNAI / 10000; // Share is defined as part of 10000 (i.e. 10000 is 100%, 1 is 0.01%)
            D.print("Treasury: handleReceivedFunnai - funnaiToBurn: " # debug_show (funnaiToBurn));
            let burnResult = await burnFunnaiTransaction(funnaiToBurn);
            D.print("Treasury: handleReceivedFunnai - burnResult: " # debug_show (burnResult));
            if (burnResult > 0) {
                // Store tokenomics action
                let creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                let newEntry : Types.TokenomicsAction = {
                    token : Types.TokenomicsActionTokens = #FUNNAI;
                    amount : Nat = funnaiToBurn;
                    creationTimestamp : Nat64 = creationTimestamp;
                    additionalToken : ?Types.TokenomicsActionTokens = null;
                    additionalTokenAmount : Nat = 0;
                    actionId : Nat64 = tokenomicsActionCounter;
                    actionType : Types.TokenomicsActionType = #Burn;
                    associatedTransactionId : ?Nat64 = ?Nat64.fromNat(burnResult);
                    transactionIdDisbursement : ?Nat64 = ?disbursementEntry.transactionId;
                    newIcpBalance : Nat = disbursementEntry.newIcpBalance;
                };

                let _ = putTokenomicsAction(newEntry);
                D.print("Treasury: handleReceivedFunnai - newEntry: " # debug_show (newEntry));

                result := #Ok(newEntry);
            };
        };

        if (LIQUIDITY_ADDITION_INCOMING_FUNNAI) {
            let funnaiForLiquidity : Nat = funnaiReceived * LIQUIDITY_SHARE_FUNNAI / 10000; // Share is defined as part of 10000 (i.e. 10000 is 100%, 1 is 0.01%)
            D.print("Treasury: handleReceivedFunnai - funnaiForLiquidity: " # debug_show (funnaiForLiquidity));
            let (liquidityAdditionResult, matchedIcpAmount) = await addLiquidity(funnaiForLiquidity);
            D.print("Treasury: handleReceivedFunnai - liquidityAdditionResult: " # debug_show (liquidityAdditionResult));
            if (liquidityAdditionResult > 0) {
                // Store tokenomics action
                let creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                let newEntry : Types.TokenomicsAction = {
                    token : Types.TokenomicsActionTokens = #ICP;
                    amount : Nat = matchedIcpAmount;
                    creationTimestamp : Nat64 = creationTimestamp;
                    additionalToken : ?Types.TokenomicsActionTokens = ?#FUNNAI;
                    additionalTokenAmount : Nat = funnaiForLiquidity;
                    actionId : Nat64 = tokenomicsActionCounter;
                    actionType : Types.TokenomicsActionType = #LiquidityProvision;
                    associatedTransactionId : ?Nat64 = ?Nat64.fromNat(liquidityAdditionResult);
                    transactionIdDisbursement : ?Nat64 = ?disbursementEntry.transactionId;
                    newIcpBalance : Nat = disbursementEntry.newIcpBalance;
                };

                let _ = putTokenomicsAction(newEntry);
                D.print("Treasury: handleReceivedFunnai - newEntry: " # debug_show (newEntry));

                result := #Ok(newEntry);
            };
        };

        // Remaining FUNNAI is kept in Treasury's balance
        return result;
    };

    private func swapIcpToFunnai(icpToConvert : Nat, disbursementEntry : Types.TokenDisbursement) : async Types.TokenSwapResult {
        D.print("Treasury: swapIcpToFunnai icpToConvert " # debug_show (icpToConvert));
        D.print("Treasury: swapIcpToFunnai disbursementEntry " # debug_show (disbursementEntry));
        if (icpToConvert >= icpBalance) {
            D.print("Treasury: swapIcpToFunnai ICP Balance is too low: " # debug_show (icpToConvert) # " Balance: " # debug_show (icpBalance));
            return #Err(#Other("ICP Balance is too low: " # debug_show (icpToConvert) # " Balance: " # debug_show (icpBalance)));
        };
        // Get a quote, then swap (https://github.com/ICPSwap-Labs/docs/blob/main/02.SwapPool/Swap/03.Executing_DepositAndSwap.md)
        let amountToConvert : Text = Nat.toText(icpToConvert);
        let swapArgs : LiquidityPool.SwapArgs = {
            amountIn : Text = amountToConvert;
            zeroForOne : Bool = true; // ICP for FUNNAI
            amountOutMinimum : Text = "0"; // not used in quote
        };
        D.print("Treasury: swapIcpToFunnai swapArgs " # debug_show (swapArgs));
        try {
            let quoteResult : LiquidityPool.Result = await LIQUIDITY_POOL_ACTOR.quote(swapArgs);
            D.print("Treasury: swapIcpToFunnai quoteResult " # debug_show (quoteResult));
            switch (quoteResult) {
                case (#ok(quotedReceivedAmount)) {
                    D.print("Treasury: swapIcpToFunnai quotedReceivedAmount: " # debug_show (quotedReceivedAmount));
                    // Transfer ICP to SwapPool
                    let transferArg : TokenLedger.TransferArg = {
                        memo : ?Blob = null;
                        amount : Nat = icpToConvert;
                        // the ICP ledger charges 10_000 e8s for a transfer
                        fee : ?Nat = null;
                        // we are transferring from the canisters default subaccount, therefore we don't need to specify it
                        from_subaccount : ?Blob = null;
                        // we hardcode the receiver info as an account identifier where the swap pool is the owner and the treasury canister the subaccount
                        to : TokenLedger.Account = liquidityPoolAccountWithTreasurySubaccount;
                        // a timestamp indicating when the transaction was created by the caller; if it is not specified by the caller then this is set to the current ICP time
                        created_at_time : ?Nat64 = null;
                    };
                    D.print("Treasury: swapIcpToFunnai transferArg " # debug_show (transferArg));      
                    let transferResult : TokenLedger.Result = await ICP_LEDGER_ACTOR.icrc1_transfer(transferArg);
                    D.print("Treasury: swapIcpToFunnai transferResult " # debug_show (transferResult));
                    switch (transferResult) {
                        case (#Err(transferError)) {
                            D.print("Treasury: swapIcpToFunnai transferError " # debug_show (transferError));
                            return #Err(#Other("Couldn't transfer ICP:\n" # debug_show (transferError)));
                        };
                        case (#Ok(blockIndex)) {
                            D.print("Treasury: swapIcpToFunnai blockIndex " # debug_show (blockIndex));
                            // Swap ICP for FUNNAI
                            try { 
                                let amountOutMinimum : Nat = quotedReceivedAmount * 9 / 10; // max 10% slippage
                                D.print("Treasury: swapIcpToFunnai amountOutMinimum " # debug_show (amountOutMinimum));
                                let depositAndSwapArgs : LiquidityPool.DepositAndSwapArgs = {
                                    amountIn : Text = amountToConvert;
                                    zeroForOne : Bool = true; // ICP for FUNNAI
                                    amountOutMinimum : Text = Nat.toText(amountOutMinimum);
                                    tokenInFee : Nat = 10000; // ICP
                                    tokenOutFee : Nat = 1; // FUNNAI
                                };
                                D.print("Treasury: swapIcpToFunnai depositAndSwapArgs " # debug_show (depositAndSwapArgs));

                                let depositAndSwapResult : LiquidityPool.Result = await LIQUIDITY_POOL_ACTOR.depositAndSwap(depositAndSwapArgs);
                                D.print("Treasury: swapIcpToFunnai depositAndSwapResult " # debug_show (depositAndSwapResult));
                                switch (depositAndSwapResult) {
                                    case (#ok(receivedAmount)) {
                                        D.print("Treasury: swapIcpToFunnai receivedAmount " # debug_show (receivedAmount));
                                        // Store Swap tokenomics action
                                        let creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                                        var newIcpBalance : Nat = 0;
                                        if (disbursementEntry.newIcpBalance > icpToConvert) {
                                            newIcpBalance := disbursementEntry.newIcpBalance - icpToConvert;
                                        };
                                        let newEntry : Types.TokenomicsAction = {
                                            token : Types.TokenomicsActionTokens = #ICP;
                                            amount : Nat = icpToConvert;
                                            creationTimestamp : Nat64 = creationTimestamp;
                                            additionalToken : ?Types.TokenomicsActionTokens = ?#FUNNAI;
                                            additionalTokenAmount : Nat = receivedAmount;
                                            actionId : Nat64 = tokenomicsActionCounter;
                                            actionType : Types.TokenomicsActionType = #Swap;
                                            associatedTransactionId : ?Nat64 = null;
                                            transactionIdDisbursement : ?Nat64 = ?disbursementEntry.transactionId;
                                            newIcpBalance : Nat = newIcpBalance;
                                        };

                                        let _ = putTokenomicsAction(newEntry);
                                        D.print("Treasury: swapIcpToFunnai newEntry " # debug_show (newEntry));
                                        if (icpBalance > icpToConvert) {
                                            icpBalance := icpBalance - icpToConvert;
                                        } else {
                                            icpBalance := 0;
                                        };
                                        funnaiBalance := funnaiBalance + receivedAmount;

                                        let result : Types.TokenSwapRecord = {
                                            token : Types.TokenomicsActionTokens = #ICP;
                                            amount : Nat = icpToConvert;
                                            creationTimestamp : Nat64 = creationTimestamp;
                                            additionalToken : Types.TokenomicsActionTokens = #FUNNAI;
                                            additionalTokenAmount : Nat = receivedAmount;
                                        };
                                        D.print("Treasury: swapIcpToFunnai result " # debug_show (result));
                                        return #Ok(result);
                                    };
                                    case (#err(err)) {
                                        D.print("Treasury: swapIcpToFunnai depositAndSwapResult Err: " # debug_show (err));
                                        return #Err(#Other("DepositAndSwap error: " # debug_show (err)));
                                    };
                                };
                            } catch (error : Error) {
                                D.print("Treasury: swapIcpToFunnai depositAndSwapResult error: " # Error.message(error));
                                // TODO: try again, otherwise transferred ICP need to be reclaimed
                                return #Err(#FailedOperation);
                            };
                        };
                    };
                };
                case (#err(err)) {
                    D.print("Treasury: swapIcpToFunnai quoteResult Err: " # debug_show (err));
                    return #Err(#Other("Quote error: " # debug_show (err)));
                };
            };
        } catch (error : Error) {
            D.print("Treasury: swapIcpToFunnai error: " # Error.message(error));
            return #Err(#FailedOperation);
        };
    };

// Treasury's liquidity positions
    stable var liquidityPositionsStorage : List.List<LiquidityPool.UserPositionInfoWithId> = List.nil<LiquidityPool.UserPositionInfoWithId>();

    public query (msg) func getLiquidityPositionsAdmin() : async Types.LiquidityPositionsResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        return #Ok({ liquidityPositions = List.toArray(liquidityPositionsStorage) });
    };

    // Helper function to create a new liquidity in the FUNNAI/ICP pool
    private func mintLiquidityPosition(funnaiForLiquidity : Nat) : async Nat {
        if (MATCH_LIQUIDITY_ADDITION_ICP) {
            // Add FUNNAI and ICP to liquidity pool
            try {
                // Retrieve the liquidity pool's metadata
                let metadataResult : LiquidityPool.Result_7 = await LIQUIDITY_POOL_ACTOR.metadata();
                switch (metadataResult) {
                    case (#err(err)) {
                        D.print("Treasury: mintLiquidityPosition metadataResult Err: " # debug_show (err));
                        return 0;
                    };
                    case (#ok(metadataLiquidityPool)) {
                        D.print("Treasury: mintLiquidityPosition metadataLiquidityPool: " # debug_show (metadataLiquidityPool));
                        // Get a quote first
                        let amountToConvert : Text = Nat.toText(funnaiForLiquidity);
                        let swapArgs : LiquidityPool.SwapArgs = {
                            amountIn : Text = amountToConvert;
                            zeroForOne : Bool = false; // FUNNAI for ICP
                            amountOutMinimum : Text = "0"; // not used in quote
                        };
                        D.print("Treasury: mintLiquidityPosition swapArgs: " # debug_show (swapArgs));
                        let quoteResult : LiquidityPool.Result = await LIQUIDITY_POOL_ACTOR.quote(swapArgs);
                        D.print("Treasury: mintLiquidityPosition quoteResult: " # debug_show (quoteResult));
                        switch (quoteResult) {
                            case (#err(err)) {
                                D.print("Treasury: mintLiquidityPosition quoteResult Err: " # debug_show (err));
                                return 0;
                            };
                            case (#ok(quotedReceivedAmount)) {
                                D.print("Treasury: mintLiquidityPosition quotedReceivedAmount: " # debug_show (quotedReceivedAmount));
                                let amountOutMinimum : Nat = quotedReceivedAmount * 9 / 10; // max 10% slippage
                                // Create liquidity position in several steps
                                // approveToken0 (ICP)
                                let approve0Args : TokenLedger.ApproveArgs = {
                                    fee : ?Nat = null;
                                    memo : ?Blob = null;
                                    from_subaccount : ?Blob = null;
                                    created_at_time : ?Nat64 = null;
                                    amount : Nat = quotedReceivedAmount * 2; // Higher allowance to ensure it works
                                    expected_allowance : ?Nat = null;
                                    expires_at : ?Nat64 = null;
                                    spender : TokenLedger.Account = liquidityPoolAccount;
                                };
                                D.print("Treasury: mintLiquidityPosition - approve0Args: " # debug_show (approve0Args));
                                let approve0Result : TokenLedger.Result_2 = await ICP_LEDGER_ACTOR.icrc2_approve(approve0Args);
                                D.print("Treasury: mintLiquidityPosition - approve0Result: " # debug_show (approve0Result));
                                switch (approve0Result) {
                                    case (#Err(err)) {
                                        D.print("Treasury: mintLiquidityPosition approve0Result Err: " # debug_show (err));
                                        return 0;
                                    };
                                    case (#Ok(approve0BlockIndex)) {
                                        // depositToken0 (ICP): depositFrom to SwapPool
                                        let depositToken0Args : LiquidityPool.DepositArgs = {
                                            amount : Nat = quotedReceivedAmount;
                                            token : Text = Principal.toText(Principal.fromActor(ICP_LEDGER_ACTOR));
                                            fee : Nat = 10000; // ICP
                                        };
                                        D.print("Treasury: mintLiquidityPosition - depositToken0Args: " # debug_show (depositToken0Args));
                                        let depositToken0Result : LiquidityPool.Result = await LIQUIDITY_POOL_ACTOR.depositFrom(depositToken0Args);
                                        D.print("Treasury: mintLiquidityPosition - depositToken0Result: " # debug_show (depositToken0Result));
                                        switch (depositToken0Result) {
                                            case (#err(err)) {
                                                D.print("Treasury: mintLiquidityPosition depositToken0Result Err: " # debug_show (err));
                                                return 0;
                                            };
                                            case (#ok(depositToken0BlockIndex)) {
                                                // approve token 1 (FUNNAI)
                                                let approve1Args : TokenLedger.ApproveArgs = {
                                                    fee : ?Nat = null;
                                                    memo : ?Blob = null;
                                                    from_subaccount : ?Blob = null;
                                                    created_at_time : ?Nat64 = null;
                                                    amount : Nat = funnaiForLiquidity * 2; // Higher allowance to ensure it works
                                                    expected_allowance : ?Nat = null;
                                                    expires_at : ?Nat64 = null;
                                                    spender : TokenLedger.Account = liquidityPoolAccount;
                                                };
                                                D.print("Treasury: mintLiquidityPosition - approve1Args: " # debug_show (approve1Args));
                                                let approve1Result : TokenLedger.Result_2 = await TokenLedger_Actor.icrc2_approve(approve1Args);
                                                D.print("Treasury: mintLiquidityPosition - approve1Result: " # debug_show (approve1Result));
                                                switch (approve1Result) {
                                                    case (#Err(approveToken1Error)) {
                                                        D.print("Treasury: mintLiquidityPosition approveToken1Error " # debug_show (approveToken1Error));
                                                        return 0;
                                                    };
                                                    case (#Ok(approveToken1BlockIndex)) {
                                                        D.print("Treasury: mintLiquidityPosition approveToken1BlockIndex " # debug_show (approveToken1BlockIndex));
                                                        // depositToken1 (FUNNAI)
                                                        let depositToken1Args : LiquidityPool.DepositArgs = {
                                                            amount : Nat = funnaiForLiquidity;
                                                            token : Text = TOKEN_LEDGER_CANISTER_ID;
                                                            fee : Nat = 1;
                                                        };
                                                        D.print("Treasury: mintLiquidityPosition depositToken1Args " # debug_show (depositToken1Args));
                                                        let depositToken1Result : LiquidityPool.Result = await LIQUIDITY_POOL_ACTOR.depositFrom(depositToken1Args);
                                                        D.print("Treasury: mintLiquidityPosition depositToken1Result " # debug_show (depositToken1Result));
                                                        switch (depositToken1Result) {
                                                            case (#err(depositToken1Error)) {
                                                                D.print("Treasury: mintLiquidityPosition depositToken1Error " # debug_show (depositToken1Error));
                                                                return 0;
                                                            };
                                                            case (#ok(depositToken1BlockIndex)) {
                                                                D.print("Treasury: mintLiquidityPosition depositToken1BlockIndex " # debug_show (depositToken1BlockIndex));
                                                                // Calculate ticks (for liquidity range) given current tick from metadata
                                                                let MIN_TICK : Int = -887_272;
                                                                let MAX_TICK : Int =  887_272;
                                                                // Fixed tick spacing for 0.3% fee tier
                                                                let tickSpacing : Int = 60;
                                                                /// Compute a ~50% price range around current tick
                                                                func computeRange(currentTick : Int) : (Int, Int) {
                                                                    // align current tick to spacing
                                                                    let alignedTick = currentTick - (currentTick % tickSpacing);
                                                                    // 50% price up/down roughly corresponds to about ±4000 ticks
                                                                    let lower = alignedTick - 4000;
                                                                    let upper = alignedTick + 4000;
                                                                    // clamp to valid range and align to spacing
                                                                    let tickLower = Int.max(MIN_TICK, lower - (lower % tickSpacing));
                                                                    let tickUpper = Int.min(MAX_TICK, upper - (upper % tickSpacing));
                                                                    (tickLower, tickUpper)
                                                                };
                                                                D.print("Treasury: mintLiquidityPosition metadataLiquidityPool.tick " # debug_show (metadataLiquidityPool.tick));
                                                                let (tickLower, tickUpper) = computeRange(metadataLiquidityPool.tick);
                                                                D.print("Treasury: mintLiquidityPosition tickLower " # debug_show (tickLower));
                                                                D.print("Treasury: mintLiquidityPosition tickUpper " # debug_show (tickUpper));
                                                                // Mint new liquidity position
                                                                let mintLPArgs : LiquidityPool.MintArgs = {
                                                                    fee : Nat = metadataLiquidityPool.fee;
                                                                    tickUpper : Int = tickUpper;
                                                                    token0 : Text = metadataLiquidityPool.token0.address;
                                                                    token1 : Text = metadataLiquidityPool.token1.address;
                                                                    amount0Desired : Text = Nat.toText(quotedReceivedAmount);
                                                                    amount1Desired : Text = Nat.toText(funnaiForLiquidity);
                                                                    tickLower : Int = tickLower;
                                                                };
                                                                D.print("Treasury: mintLiquidityPosition mintLPArgs " # debug_show (mintLPArgs));
                                                                let mintLPResult : LiquidityPool.Result = await LIQUIDITY_POOL_ACTOR.mint(mintLPArgs);
                                                                D.print("Treasury: mintLiquidityPosition mintLPResult " # debug_show (mintLPResult));
                                                                switch (mintLPResult) {
                                                                    case (#err(err)) {
                                                                        D.print("Treasury: mintLiquidityPosition mintLPResult Err: " # debug_show (err));
                                                                        return 0;
                                                                    };
                                                                    case (#ok(mintLPId)) {
                                                                        D.print("Treasury: mintLiquidityPosition mintLPId " # debug_show (mintLPId));
                                                                        if (icpBalance > quotedReceivedAmount) {
                                                                            icpBalance := icpBalance - quotedReceivedAmount;
                                                                        } else {
                                                                            icpBalance := 0;
                                                                        };
                                                                        D.print("Treasury: mintLiquidityPosition icpBalance " # debug_show (icpBalance));
                                                                        if (funnaiBalance > funnaiForLiquidity) {
                                                                            funnaiBalance := funnaiBalance - funnaiForLiquidity;
                                                                        } else {
                                                                            funnaiBalance := 0;
                                                                        };
                                                                        D.print("Treasury: mintLiquidityPosition funnaiBalance " # debug_show (funnaiBalance));
                                                                        return mintLPId;
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
                };
            } catch (error : Error) {
                D.print("Treasury: mintLiquidityPosition error: " # Error.message(error));
                return 0;
            };
        } else {
            // TODO: Decide if only FUNNAI should be added to liquidity pool
            D.print("Treasury: mintLiquidityPosition MATCH_LIQUIDITY_ADDITION_ICP is false");
            return 0;
        };
    };

    public shared (msg) func createLiquidityPositionAdmin() : async Types.LiquidityPositionResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let newPosition : Nat = await mintLiquidityPosition(1000000000); 
        D.print("Treasury: createLiquidityPositionAdmin newPosition " # debug_show (newPosition));
        let userLPResult : LiquidityPool.Result_14 = await LIQUIDITY_POOL_ACTOR.getUserPosition(newPosition);
        D.print("Treasury: createLiquidityPositionAdmin userLPResult " # debug_show (userLPResult));
        switch (userLPResult) {
            case (#err(err)) {
                D.print("Treasury: createLiquidityPositionAdmin userLPResult Err: " # debug_show (err));
                return #Err(#Other("Get new LP error: " # debug_show (err)));
            };
            case (#ok(userPositionInfo)) {
                D.print("Treasury: createLiquidityPositionAdmin userPositionInfo: " # debug_show (userPositionInfo));
                let userPositionInfoWithId : LiquidityPool.UserPositionInfoWithId = {
                    id : Nat = newPosition;
                    tickUpper : Int = userPositionInfo.tickUpper;
                    tokensOwed0 : Nat = userPositionInfo.tokensOwed0;
                    tokensOwed1 : Nat = userPositionInfo.tokensOwed1;
                    feeGrowthInside1LastX128 : Nat = userPositionInfo.feeGrowthInside1LastX128;
                    liquidity : Nat = userPositionInfo.liquidity;
                    feeGrowthInside0LastX128 : Nat = userPositionInfo.feeGrowthInside0LastX128;
                    tickLower : Int = userPositionInfo.tickLower;
                };
                D.print("Treasury: createLiquidityPositionAdmin userPositionInfoWithId: " # debug_show (userPositionInfoWithId));
                liquidityPositionsStorage := List.push<LiquidityPool.UserPositionInfoWithId>(userPositionInfoWithId, liquidityPositionsStorage);
                return #Ok(userPositionInfoWithId);
            };
        };
    };

    // Helper function to add liquidity to the FUNNAI/ICP pool
    private func addLiquidity(funnaiForLiquidity : Nat) : async (Nat, Nat) {
        if (MATCH_LIQUIDITY_ADDITION_ICP) {
            // Add FUNNAI and ICP to an existing liquidity position on the pool
            try {
                // Get the latest liquidity position
                let existingLPResult : ?LiquidityPool.UserPositionInfoWithId = List.get<LiquidityPool.UserPositionInfoWithId>(liquidityPositionsStorage, 0);
                switch (existingLPResult) {
                    case (null) {
                        D.print("Treasury: addLiquidity no liquidity position exists. Create one first.");
                        return (0, 0);
                    };
                    case (?existingLP) {
                        // Retrieve the liquidity pool's metadata
                        let metadataResult : LiquidityPool.Result_7 = await LIQUIDITY_POOL_ACTOR.metadata();
                        switch (metadataResult) {
                            case (#err(err)) {
                                D.print("Treasury: addLiquidity metadataResult Err: " # debug_show (err));
                                return (0, 0);
                            };
                            case (#ok(metadataLiquidityPool)) {
                                D.print("Treasury: addLiquidity metadataLiquidityPool: " # debug_show (metadataLiquidityPool));
                                // Get a quote first
                                let amountToConvert : Text = Nat.toText(funnaiForLiquidity);
                                let swapArgs : LiquidityPool.SwapArgs = {
                                    amountIn : Text = amountToConvert;
                                    zeroForOne : Bool = false; // FUNNAI for ICP
                                    amountOutMinimum : Text = "0"; // not used in quote
                                };
                                D.print("Treasury: addLiquidity swapArgs: " # debug_show (swapArgs));
                                let quoteResult : LiquidityPool.Result = await LIQUIDITY_POOL_ACTOR.quote(swapArgs);
                                D.print("Treasury: addLiquidity quoteResult: " # debug_show (quoteResult));
                                switch (quoteResult) {
                                    case (#err(err)) {
                                        D.print("Treasury: addLiquidity quoteResult Err: " # debug_show (err));
                                        return (0, 0);
                                    };
                                    case (#ok(quotedReceivedAmount)) {
                                        D.print("Treasury: addLiquidity quotedReceivedAmount: " # debug_show (quotedReceivedAmount));
                                        if (quotedReceivedAmount >= icpBalance) {
                                            D.print("Treasury: addLiquidity ICP Balance is too low: " # debug_show (quotedReceivedAmount) # " Balance: " # debug_show (icpBalance));
                                            return (0, 0);
                                        };
                                        if (quotedReceivedAmount < 1000000) {
                                            // Given there are fees involved, very small amounts are not worth processing, e.g. smaller than 0.01 ICP
                                            D.print("Treasury: addLiquidity transaction amount is too low, not worth it: " # debug_show (quotedReceivedAmount));
                                            return (0, 0);
                                        };
                                        let amountOutMinimum : Nat = quotedReceivedAmount * 9 / 10; // max 10% slippage
                                        // Add to liquidity position in several steps
                                        // approveToken0 (ICP)
                                        let approve0Args : TokenLedger.ApproveArgs = {
                                            fee : ?Nat = null;
                                            memo : ?Blob = null;
                                            from_subaccount : ?Blob = null;
                                            created_at_time : ?Nat64 = null;
                                            amount : Nat = quotedReceivedAmount * 2; // Higher allowance to ensure it works
                                            expected_allowance : ?Nat = null;
                                            expires_at : ?Nat64 = null;
                                            spender : TokenLedger.Account = liquidityPoolAccount;
                                        };
                                        D.print("Treasury: addLiquidity - approve0Args: " # debug_show (approve0Args));
                                        let approve0Result : TokenLedger.Result_2 = await ICP_LEDGER_ACTOR.icrc2_approve(approve0Args);
                                        D.print("Treasury: addLiquidity - approve0Result: " # debug_show (approve0Result));
                                        switch (approve0Result) {
                                            case (#Err(err)) {
                                                D.print("Treasury: addLiquidity approve0Result Err: " # debug_show (err));
                                                return (0, 0);
                                            };
                                            case (#Ok(approve0BlockIndex)) {
                                                // depositToken0 (ICP): depositFrom to SwapPool
                                                let depositToken0Args : LiquidityPool.DepositArgs = {
                                                    amount : Nat = quotedReceivedAmount;
                                                    token : Text = Principal.toText(Principal.fromActor(ICP_LEDGER_ACTOR));
                                                    fee : Nat = 10000; // ICP
                                                };
                                                D.print("Treasury: addLiquidity - depositToken0Args: " # debug_show (depositToken0Args));
                                                let depositToken0Result : LiquidityPool.Result = await LIQUIDITY_POOL_ACTOR.depositFrom(depositToken0Args);
                                                D.print("Treasury: addLiquidity - depositToken0Result: " # debug_show (depositToken0Result));
                                                switch (depositToken0Result) {
                                                    case (#err(err)) {
                                                        D.print("Treasury: addLiquidity depositToken0Result Err: " # debug_show (err));
                                                        return (0, 0);
                                                    };
                                                    case (#ok(depositToken0BlockIndex)) {
                                                        // approve token 1 (FUNNAI)
                                                        let approve1Args : TokenLedger.ApproveArgs = {
                                                            fee : ?Nat = null;
                                                            memo : ?Blob = null;
                                                            from_subaccount : ?Blob = null;
                                                            created_at_time : ?Nat64 = null;
                                                            amount : Nat = funnaiForLiquidity * 2; // Higher allowance to ensure it works
                                                            expected_allowance : ?Nat = null;
                                                            expires_at : ?Nat64 = null;
                                                            spender : TokenLedger.Account = liquidityPoolAccount;
                                                        };
                                                        D.print("Treasury: addLiquidity - approve1Args: " # debug_show (approve1Args));
                                                        let approve1Result : TokenLedger.Result_2 = await TokenLedger_Actor.icrc2_approve(approve1Args);
                                                        D.print("Treasury: addLiquidity - approve1Result: " # debug_show (approve1Result));
                                                        switch (approve1Result) {
                                                            case (#Err(approveToken1Error)) {
                                                                D.print("Treasury: addLiquidity approveToken1Error " # debug_show (approveToken1Error));
                                                                return (0, 0);
                                                            };
                                                            case (#Ok(approveToken1BlockIndex)) {
                                                                D.print("Treasury: addLiquidity approveToken1BlockIndex " # debug_show (approveToken1BlockIndex));
                                                                // depositToken1 (FUNNAI)
                                                                let depositToken1Args : LiquidityPool.DepositArgs = {
                                                                    amount : Nat = funnaiForLiquidity;
                                                                    token : Text = TOKEN_LEDGER_CANISTER_ID;
                                                                    fee : Nat = 1;
                                                                };
                                                                D.print("Treasury: addLiquidity depositToken1Args " # debug_show (depositToken1Args));
                                                                let depositToken1Result : LiquidityPool.Result = await LIQUIDITY_POOL_ACTOR.depositFrom(depositToken1Args);
                                                                D.print("Treasury: addLiquidity depositToken1Result " # debug_show (depositToken1Result));
                                                                switch (depositToken1Result) {
                                                                    case (#err(depositToken1Error)) {
                                                                        D.print("Treasury: addLiquidity depositToken1Error " # debug_show (depositToken1Error));
                                                                        return (0, 0);
                                                                    };
                                                                    case (#ok(depositToken1BlockIndex)) {
                                                                        D.print("Treasury: addLiquidity depositToken1BlockIndex " # debug_show (depositToken1BlockIndex));
                                                                        // Increase the liquidity position
                                                                        let increaseLPArgs : LiquidityPool.IncreaseLiquidityArgs = {
                                                                            positionId : Nat = existingLP.id;
                                                                            amount0Desired : Text = Nat.toText(quotedReceivedAmount);
                                                                            amount1Desired : Text = Nat.toText(funnaiForLiquidity);
                                                                        };
                                                                        D.print("Treasury: addLiquidity increaseLPArgs " # debug_show (increaseLPArgs));
                                                                        let increaseLPResult : LiquidityPool.Result = await LIQUIDITY_POOL_ACTOR.increaseLiquidity(increaseLPArgs);
                                                                        D.print("Treasury: addLiquidity increaseLPResult " # debug_show (increaseLPResult));
                                                                        switch (increaseLPResult) {
                                                                            case (#err(err)) {
                                                                                D.print("Treasury: addLiquidity increaseLPResult Err: " # debug_show (err));
                                                                                return (0, 0);
                                                                            };
                                                                            case (#ok(lpId)) {
                                                                                D.print("Treasury: addLiquidity lpId " # debug_show (lpId));
                                                                                if (icpBalance > quotedReceivedAmount) {
                                                                                    icpBalance := icpBalance - quotedReceivedAmount;
                                                                                } else {
                                                                                    icpBalance := 0;
                                                                                };
                                                                                D.print("Treasury: addLiquidity icpBalance " # debug_show (icpBalance));
                                                                                
                                                                                if (funnaiBalance > funnaiForLiquidity) {
                                                                                    funnaiBalance := funnaiBalance - funnaiForLiquidity;
                                                                                } else {
                                                                                    funnaiBalance := 0;
                                                                                };
                                                                                D.print("Treasury: addLiquidity funnaiBalance " # debug_show (funnaiBalance));
                                                                                return (lpId, quotedReceivedAmount);
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
                        };

                    };
                };
            } catch (error : Error) {
                D.print("Treasury: addLiquidity error: " # Error.message(error));
                return (0, 0);
            };
        } else {
            // TODO: Decide if only FUNNAI should be added to liquidity pool
            D.print("Treasury: addLiquidity MATCH_LIQUIDITY_ADDITION_ICP is false");
            return (0, 0);
        };
    };

    // Send FUNNAI to ICPSwap to create liquidity position farms and staking pools
    let addressToSendTo : Text = "s4bhi-2dn5o-cuy2i-yyczq-y7cjy-ndpgz-wh7yw-gszzn-isq2z-5frzl-nae"; // ICPSwap's address

    // Store all FUNNAI disbursements made
    stable var funnaiDisbursementsStorage : List.List<Types.TokenDisbursement> = List.nil<Types.TokenDisbursement>();

    // Amount of FUNNAI to send
    stable var AMOUNT_FUNNAI_TO_SEND : Nat = 20000; // in full FUNNAI

    public shared (msg) func setAmountFunnaiToSend(newAmount : Nat) : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (newAmount > 40000) {
            return #Err(#Unauthorized);
        };
        AMOUNT_FUNNAI_TO_SEND := newAmount;
        let authRecord = { auth = "You set the FUNNAI amount." };
        return #Ok(authRecord);
    };

    public query (msg) func getAmountFunnaiToSend() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let authRecord = {
            auth = "FUNNAI to send: " # debug_show (AMOUNT_FUNNAI_TO_SEND);
        };
        return #Ok(authRecord);
    };
    
    // Flag to toggle whether FUNNAI can be sent out
    stable var SEND_OUT_FUNNAI : Bool = false;

    public shared (msg) func toggleSendOutFunnaiFlagAdmin() : async Types.AuthRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        SEND_OUT_FUNNAI := not SEND_OUT_FUNNAI;
        let authRecord = {
            auth = "You set the flag to " # debug_show (SEND_OUT_FUNNAI);
        };
        return #Ok(authRecord);
    };

    public query (msg) func getSendOutFunnaiFlag() : async Types.FlagResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        return #Ok({ flag = SEND_OUT_FUNNAI });
    };

    public shared (msg) func sendFunnaiForPoolSetupAdmin() : async Types.NatResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        D.print("Treasury: sendFunnaiForPoolSetupAdmin caller by: " # debug_show (msg.caller));
        D.print("Treasury: sendFunnaiForPoolSetupAdmin AMOUNT_FUNNAI_TO_SEND: " # debug_show (AMOUNT_FUNNAI_TO_SEND));
        D.print("Treasury: sendFunnaiForPoolSetupAdmin SEND_OUT_FUNNAI: " # debug_show (SEND_OUT_FUNNAI));
        if (not SEND_OUT_FUNNAI) {
            return #Err(#Unauthorized);
        };
        let amountToSendE8s : Nat = AMOUNT_FUNNAI_TO_SEND * E8S_PER_ICP; // FUNNAI has 8 decimal places
        D.print("Treasury: sendFunnaiForPoolSetupAdmin amountToSendE8s: " # debug_show (amountToSendE8s));
        let args : TokenLedger.TransferArg = {
            from_subaccount = null;
            to = {
                owner = Principal.fromText(addressToSendTo);
                subaccount = null;
            };
            amount = amountToSendE8s;
            fee = null;
            memo = null;
            created_at_time = null;
        };
        D.print("Treasury: sendFunnaiForPoolSetupAdmin args: " # debug_show (args));
        try {
            // Call the ledger's icrc1_transfer function
            let result = await TokenLedger_Actor.icrc1_transfer(args);
            D.print("Treasury: sendFunnaiForPoolSetupAdmin result: " # debug_show (result));

            switch (result) {
                case (#Ok(blockIndex)) {
                    D.print("Treasury: sendFunnaiForPoolSetupAdmin - sending tokens successful: " # debug_show (blockIndex));
                    D.print("Treasury: sendFunnaiForPoolSetupAdmin funnaiBalance initial: " # debug_show (funnaiBalance));
                    if (funnaiBalance > amountToSendE8s) {
                        funnaiBalance := funnaiBalance - amountToSendE8s;
                    } else {
                        funnaiBalance := 0;
                    };
                    D.print("Treasury: sendFunnaiForPoolSetupAdmin funnaiBalance after update: " # debug_show (funnaiBalance));
                    // Store the disbursement record
                    let creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                    let disbursementEntry : Types.TokenDisbursement = {
                        transactionId : Nat64 = Nat64.fromNat(blockIndex);
                        disbursementAmount : Nat = amountToSendE8s;
                        newIcpBalance : Nat = funnaiBalance;
                        creationTimestamp : Nat64 = creationTimestamp;
                        sentBy : Principal = msg.caller;
                    };
                    funnaiDisbursementsStorage := List.push<Types.TokenDisbursement>(disbursementEntry, funnaiDisbursementsStorage);
                    // Store the tokenomics action
                    let newEntry : Types.TokenomicsAction = {
                        token : Types.TokenomicsActionTokens = #FUNNAI;
                        amount : Nat = amountToSendE8s;
                        creationTimestamp : Nat64 = creationTimestamp;
                        additionalToken : ?Types.TokenomicsActionTokens = null;
                        additionalTokenAmount : Nat = 0;
                        actionId : Nat64 = tokenomicsActionCounter;
                        actionType : Types.TokenomicsActionType = #Other("Sent FUNNAI for LP farm/staking pool setup");
                        associatedTransactionId : ?Nat64 = ?Nat64.fromNat(blockIndex);
                        transactionIdDisbursement : ?Nat64 = null;
                        newIcpBalance : Nat = icpBalance;
                    };

                    let _ = putTokenomicsAction(newEntry);

                    return #Ok(blockIndex);
                };
                case (#Err(err)) {
                    D.print("Treasury: sendFunnaiForPoolSetupAdmin - Transfer error: " # debug_show (err));
                    return #Err(#FailedOperation);
                };
            };
        } catch (e) {
            D.print("Treasury: sendFunnaiForPoolSetupAdmin - Failed to call ledger: " # Error.message(e));
            return #Err(#FailedOperation);
        };
    };
};
