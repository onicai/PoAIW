//import D "mo:base/Debug";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Cycles "mo:base/ExperimentalCycles";

import Types "./Types";

actor class CanisterCreationCanister() = this {

    stable var MASTER_CANISTER_ID : Text = "be2us-64aaa-aaaaa-qaabq-cai"; // Corresponds to Game State canister

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

    // Admin function to upload mainer agent controller canister wasm
    private stable var mainerControllerCanisterWasm : [Nat8] = [];

    public shared (msg) func upload_mainer_controller_canister_wasm_bytes_chunk(bytesChunk : [Nat8]) : async Types.FileUploadResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        mainerControllerCanisterWasm := Array.append(mainerControllerCanisterWasm, bytesChunk);

        return #Ok({ creationResult = "Success" });
    };

    // Admin function to upload mainer agent LLM canister wasm
    private stable var mainerLlmCanisterWasm : [Nat8] = [];

    public shared (msg) func upload_mainer_llm_canister_wasm_bytes_chunk(bytesChunk : [Nat8]) : async Types.FileUploadResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        mainerLlmCanisterWasm := Array.append(mainerLlmCanisterWasm, bytesChunk);

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

        // TODO: split up functionality and have frontend make several calls (also allows UI to provide feedback to user)
        switch (configurationInput.canisterType) {
            case (#MainerAgent) {
                // Create canisters for new mAIner agent
                // First, mAIner controller
                Cycles.add(700_000_000_000); // TODO: determine exact cycles amount

                let createdControllerCanister = await IC0.create_canister({
                    settings = ?{
                        freezing_threshold = null;
                        controllers = ?[Principal.fromActor(this), configurationInput.owner];
                        memory_allocation = null;
                        compute_allocation = null;
                    };
                });

                let installControllerWasm = await IC0.install_code({
                    arg = "";
                    wasm_module = Blob.fromArray(mainerControllerCanisterWasm);
                    mode = #install;
                    canister_id = createdControllerCanister.canister_id;
                });

                // Verify new canister is working
                let readyControllerResult = await createdControllerCanister.health();
                switch (readyControllerResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                // Set Game State canister address
                let setControllerGameStateResult = await createdControllerCanister.setGameStateCanisterId(MASTER_CANISTER_ID);
                switch (setControllerGameStateResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                // then create mAIner LLM
                Cycles.add(700_000_000_000); // TODO: determine exact cycles amount

                let createdLlmCanister = await IC0.create_canister({
                    settings = ?{
                        freezing_threshold = null;
                        controllers = ?[createdControllerCanister.canister_id, Principal.fromActor(this), configurationInput.owner];
                        memory_allocation = null;
                        compute_allocation = null;
                    };
                });

                let installLlmWasm = await IC0.install_code({
                    arg = "";
                    wasm_module = Blob.fromArray(mainerLlmCanisterWasm);
                    mode = #install;
                    canister_id = createdLlmCanister.canister_id;
                });

                // Verify new canister is working
                let readyLlmResult = await createdLlmCanister.health();
                switch (readyLlmResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                // TODO: Make LLM functional



                // connect LLM and controller canisters
                // Register LLM with controller
                let addLlmToControllerResult = await createdControllerCanister.set_llm_canister_id(Principal.toText(createdLlmCanister.canister_id));
                switch (addLlmToControllerResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                let setControllerRoundRobinResult = await createdControllerCanister.setRoundRobinLLMs(1);
                switch (setControllerRoundRobinResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                // --------------------------------------------------------------------
                let creationRecord = {
                    creationResult = "Success";
                    newCanisterId = Principal.toText(createdControllerCanister.canister_id);
                };
                return #Ok(creationRecord);
            };
            case (#MainerLlm) {

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
            canisterType : Types.ProtocolCanisterType = #MainerAgent;
            owner : Principal = msg.caller;
        };
        let result = await createCanister(config);
        return result;
    };

    // Use with caution: Admin functions to reset the canister wasm
    public shared (msg) func reset_mainer_controller_canister_wasm() : async Types.FileUploadResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        mainerControllerCanisterWasm := [];

        return #Ok({ creationResult = "Success" });
    };

    public shared (msg) func reset_mainer_llm_canister_wasm() : async Types.FileUploadResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        mainerLlmCanisterWasm := [];

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
