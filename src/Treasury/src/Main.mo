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

import Types "../../common/Types";

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
        
        return #Ok({
            disbursementHandled : Bool = true;
        });
    };
};