//import D "mo:base/Debug";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Cycles "mo:base/ExperimentalCycles";

import Types "./Types";

actor class CanisterCreationCanister() = this {

    stable var MASTER_CANISTER_ID : Text = ""; // Corresponds to Game State canister

    public shared (msg) func setMasterCanisterId(_master_canister_id : Text) : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        MASTER_CANISTER_ID := _master_canister_id;
        let authRecord = { auth = "You set the master canister for this canister." };
        return #Ok(authRecord);
    };

    // -------------------------------------------------------------------------------
    // Canister Endpoints

    public shared query (msg) func whoami() : async Principal {
        return msg.caller;
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

    let IC0 : Types.IC_Management = actor ("aaaaa-aa");

    // Admin function to upload mainer agent canister wasm
    private stable var mainerCanisterWasm : [Nat8] = [];

    public shared (msg) func upload_mainer_canister_wasm_bytes_chunk(bytesChunk : [Nat8]) : async Types.FileUploadResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        mainerCanisterWasm := Array.append(mainerCanisterWasm, bytesChunk);

        return #Ok({ creationResult = "Success" });
    };

    // Spin up a new canister as specified by the input parameters
    public shared (msg) func createCanister(configurationInput : Types.CanisterCreationConfiguration) : async Types.CanisterCreationResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // Only Controllers and the Master canister may call this (plus the cansiter itself for testing functionality)
        if (not (Principal.isController(msg.caller) or Principal.equal(msg.caller, Principal.fromText(MASTER_CANISTER_ID)) or Principal.equal(msg.caller, Principal.fromActor(this)))) {
            return #Err(#Unauthorized);
        };

        switch (configurationInput.canisterType) {
            case (#Mainer) {
                // Create canister
                Cycles.add(700_000_000_000); // TODO: determine exact cycles amount

                let createdCanister = await IC0.create_canister({
                    settings = ?{
                        freezing_threshold = null;
                        controllers = ?[Principal.fromActor(this), configurationInput.owner];
                        memory_allocation = null;
                        compute_allocation = null;
                    };
                });

                let installControlWasm = await IC0.install_code({
                    arg = "";
                    wasm_module = Blob.fromArray(mainerCanisterWasm);
                    mode = #install;
                    canister_id = createdCanister.canister_id;
                });

                // TODO: verify new canister is working?
                /* let readyResult = await knowledgebaseCanister.ready();
                switch (readyResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {};
                }; */

                // --------------------------------------------------------------------
                let creationRecord = {
                    creationResult = "Success";
                    newCanisterId = Principal.toText(createdCanister.canister_id);
                };
                return #Ok(creationRecord);
            };
            case _ { 
                return #Err(#Other("canisterType not supported"));
            };
        };
    };

// Admin 
    public shared (msg) func testCreateMainerCanister() : async Types.CanisterCreationResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let config = {
            canisterType : Types.CanisterType = #Mainer;
            owner : Principal = msg.caller;
        };
        let result = await createCanister(config);
        return result;
    };

    // Use with caution: Admin function to reset the canister wasm
    public shared (msg) func reset_mainer_canister_wasm() : async Types.FileUploadResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        mainerCanisterWasm := [];

        return #Ok({ creationResult = "Success" });
    };

    // -------------------------------------------------------------------------------
    // Canister upgrades

    // System-provided lifecycle method called before an upgrade.
   /*  system func preupgrade() {
        // Copy the runtime state back into the stable variable before upgrade.
    };

    // System-provided lifecycle method called after an upgrade or on initial deploy.
    system func postupgrade() {
        // After upgrade, reload the runtime state from the stable variable.
    }; */
    // -------------------------------------------------------------------------------
};
