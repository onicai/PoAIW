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
import Sha256 "mo:sha2/Sha256";

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