//import D "mo:base/Debug";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Cycles "mo:base/ExperimentalCycles";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import D "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";

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

    // Admin function to upload artefacts for mainer agent LLM canister 
    // Map each AI model id to a record with the artefacts needed to create a new canister
    private var creationArtefactsByModel = HashMap.HashMap<Text, Types.ModelCreationArtefacts>(0, Text.equal, Text.hash);
    stable var creationArtefactsByModelStable : [(Text, Types.ModelCreationArtefacts)] = [];

    private func getModelCreationArtefacts(selectedModel : Types.AvailableModels) : ?Types.ModelCreationArtefacts {
        switch (selectedModel) {
            case (#Qwen2_5_500M) {
                let creationArtefacts : ?Types.ModelCreationArtefacts = creationArtefactsByModel.get("Qwen2_5_500M");
                return creationArtefacts;
            };
            case _ { return null };
        };
    };

    private func putModelCreationArtefacts(selectedModel : Types.AvailableModels, creationArtefacts : Types.ModelCreationArtefacts) : Bool {
        switch (selectedModel) {
            case (#Qwen2_5_500M) {
                let putArtefacts = creationArtefactsByModel.put("Qwen2_5_500M", creationArtefacts);
                return true;
            };
            case _ { return false; };
        };
    };

    // Admin function to insert needed artefacts to create canisters for a new model type
    public shared (msg) func addModelCreationArtefactsEntry(selectedModel : Types.AvailableModels, creationArtefacts : Types.ModelCreationArtefacts) : async Types.InsertArtefactsResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let creationArtefactsResult = putModelCreationArtefacts(selectedModel, creationArtefacts);
        let result = getModelCreationArtefacts(selectedModel);
        switch (result) {
            case (?newArtefacts) {
                return #Ok(newArtefacts);
            };
            case _ { return #Err(#Other("Adding the artefacts failed.")) };
        };
    };

    // Admin function to upload an LLM canister wasm file
    public shared (msg) func upload_mainer_llm_canister_wasm_bytes_chunk(selectedModel : Types.AvailableModels, bytesChunk : [Nat8]) : async Types.FileUploadResult {
        D.print("upload_mainer_llm_canister_wasm_bytes_chunk");
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        switch (getModelCreationArtefacts(selectedModel)) {
            case (?existingArtefacts) {
                let updatedArtefacts : Types.ModelCreationArtefacts = {
                    canisterWasm = Array.append(existingArtefacts.canisterWasm, bytesChunk);
                    modelFile : [Nat8] = existingArtefacts.modelFile;
                };

                let updateArtefactsResult = putModelCreationArtefacts(selectedModel, updatedArtefacts);

                return #Ok({ creationResult = "Success" });
            };
            case _ {
                // new entry
                let newArtefacts : Types.ModelCreationArtefacts = {
                    canisterWasm : [Nat8] = bytesChunk;
                    modelFile : [Nat8] = [];
                };

                let updateArtefactsResult = putModelCreationArtefacts(selectedModel, newArtefacts);
                return #Ok({ creationResult = "New entry created" });
            };
        };
    };

    // Admin function to upload a model file
    stable var nextChunkID : Nat = 0;
    stable var lastChunkIndex : Nat = 400;
    //stable let innerInitArray : [Nat8] = Array.freeze<Nat8>(Array.init<Nat8>(2000000, 1));
    stable let innerInitArray : [Nat8] = Array.freeze<Nat8>(Array.init<Nat8>(1, 1));
    stable var chunks : [var [Nat8]] = Array.init<[Nat8]>(400, innerInitArray);

    public shared (msg) func upload_mainer_llm_bytes_chunk(bytesChunk : [Nat8]) : async Types.FileUploadResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        //chunks[nextChunkID] := bytesChunk;
        nextChunkID := nextChunkID + 1;
        chunks[lastChunkIndex - nextChunkID] := bytesChunk; // decrementing index
        return #Ok({ creationResult = "Success" });
    };

    /* private var modelFileUploadBuffer = Buffer.Buffer<Nat8>(1024 * 1024 * 100);

    public shared (msg) func upload_mainer_llm_bytes_chunk(bytesChunk : [Nat8]) : async Types.FileUploadResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let result = modelFileUploadBuffer.add(Blob.fromArray(bytesChunk));
        return #Ok({ creationResult = "Success" });
    }; */

    // Admin function to finish the upload of a model file
    public shared (msg) func finish_upload_mainer_llm(selectedModel : Types.AvailableModels) : async Types.FileUploadResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        switch (getModelCreationArtefacts(selectedModel)) {
            case (?existingArtefacts) {
                let updatedArtefacts : Types.ModelCreationArtefacts = {
                    canisterWasm = existingArtefacts.canisterWasm;
                    modelFile : [Nat8] = []; //TODO
                    //modelFile : [Nat8] = Blob.toArray(modelFileUploadBuffer);
                    //modelFile = modelFileUploadBuffer;
                };

                let updateArtefactsResult = putModelCreationArtefacts(selectedModel, updatedArtefacts);

                return #Ok({ creationResult = "Success" });
            };
            case _ { return #Err(#Other("Add the canisterWasm first.")) };
        };
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
            case (#MainerAgent) {
                // Create mAIner controller canister for new mAIner agent
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
                let controllerCanisterActor = actor (Principal.toText(createdControllerCanister.canister_id)) : Types.MainerAgentCtrlbCanister;

                let readyControllerResult = await controllerCanisterActor.health();
                switch (readyControllerResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                // Set Game State canister address
                let setControllerGameStateResult = await controllerCanisterActor.setGameStateCanisterId(MASTER_CANISTER_ID);
                switch (setControllerGameStateResult) {
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
                // Sanity check
                switch (configurationInput.associatedCanisterAddress) {
                    case (null) {
                        return #Err(#Other("Please provide the canister address of the associated mAIner controller canister"));
                    };
                    case (?associatedCanisterAddress) {
                        let isValidPrincipal = Principal.fromText(associatedCanisterAddress); // this will throw an error if it's not a valid canister address
                        // all good, continue
                        switch (getModelCreationArtefacts(configurationInput.selectedModel)) {
                            case (null) {
                                return #Err(#Other("Cannot find creation artefacts for the selected model"));
                            };
                            case (?modelCreationArtefacts) {
                                // Create mAIner LLM (and add it to a mAIner controller)
                                Cycles.add(700_000_000_000); // TODO: determine exact cycles amount

                                let createdLlmCanister = await IC0.create_canister({
                                    settings = ?{
                                        freezing_threshold = null;
                                        controllers = ?[Principal.fromText(associatedCanisterAddress), Principal.fromActor(this), configurationInput.owner];
                                        memory_allocation = null;
                                        compute_allocation = null;
                                    };
                                });

                                let installLlmWasm = await IC0.install_code({
                                    arg = "";
                                    wasm_module = Blob.fromArray(modelCreationArtefacts.canisterWasm);
                                    mode = #install;
                                    canister_id = createdLlmCanister.canister_id;
                                });

                                // Verify new canister is working
                                let llmCanisterActor = actor (Principal.toText(createdLlmCanister.canister_id)) : Types.LLMCanister;

                                let readyLlmResult = await llmCanisterActor.health();
                                switch (readyLlmResult) {
                                    case (#Err(error)) {
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };

                                // TODO: Make LLM functional
                                // Upload model file
                                // let chunkSize = 42000; // ~0.01 MB for testing
                                let chunkSize = 9 * 1024 * 1024; // 9 MB

                                let bufferModelFile = Buffer.fromArray<Nat8>(modelCreationArtefacts.modelFile);
                                let chunksModelFile = Buffer.chunk<Nat8>(bufferModelFile, chunkSize);
                                var offset = 0;
                                for (chunk in chunksModelFile.vals()) {
                                    D.print("Uploading another chunk of the model file...");
                                    let uploadChunk = {
                                        filename = "models/model.gguf";
                                        chunk = Buffer.toArray<Nat8>(chunk);
                                        chunksize = Nat64.fromNat(chunkSize);
                                        offset = Nat64.fromNat(offset);
                                    };
                                    let uploadModelFileResult = await llmCanisterActor.file_upload_chunk(uploadChunk);
                                    offset := offset + chunkSize;
                                };

                                // load model file in LLM
                                let inputRecord : Types.InputRecord = {
                                    args : [Text] = ["--model", "models/model.gguf"];
                                };
                                let loadModelResult = await llmCanisterActor.load_model(inputRecord);
                                switch (loadModelResult) {
                                    case (#Err(error)) {
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };
        

                                // set max tokens
                                let MAX_TOKENS : Nat64 = 10;
                                let maxTokensRecord : Types.MaxTokensRecord = {
                                    max_tokens_update : Nat64 = MAX_TOKENS;
                                    max_tokens_query : Nat64 = MAX_TOKENS;
                                };
                                let setMaxTokensResult = await llmCanisterActor.set_max_tokens(maxTokensRecord);
                                switch (setMaxTokensResult) {
                                    case (#Err(error)) {
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };                                

                                // connect LLM and controller canisters
                                // Register LLM with controller
                                let associatedControllerCanisterActor = actor (associatedCanisterAddress) : Types.MainerAgentCtrlbCanister;

                                let addLlmToControllerResult = await associatedControllerCanisterActor.add_llm_canister_id({ canister_id = Principal.toText(createdLlmCanister.canister_id); });
                                switch (addLlmToControllerResult) {
                                    case (#Err(error)) {
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };
                                // TODO: which number? Should this be done here or via an additional call?
                                let roundRobinSetting : Nat = 1;
                                let setControllerRoundRobinResult = await associatedControllerCanisterActor.setRoundRobinLLMs(roundRobinSetting);
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
                                    newCanisterId = Principal.toText(createdLlmCanister.canister_id);
                                };
                                return #Ok(creationRecord);
                            };
                        };
                    };
                };
            };
            case _ { 
                return #Err(#Other("canisterType not supported"));
            };
        };
    };

// Admin 
    public shared (msg) func testCreateMainerControllerCanister() : async Types.CanisterCreationResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let config : Types.CanisterCreationConfiguration = {
            canisterType : Types.ProtocolCanisterType = #MainerAgent;
            selectedModel : Types.AvailableModels = #Qwen2_5_500M;
            associatedCanisterAddress : ?Types.CanisterAddress = null;
            owner : Principal = msg.caller;
        };
        let result = await createCanister(config);
        return result;
    };

    public shared (msg) func testCreateMainerLlmCanister(controllerCanisterAddress : Text) : async Types.CanisterCreationResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let config : Types.CanisterCreationConfiguration = {
            canisterType : Types.ProtocolCanisterType = #MainerLlm;
            selectedModel : Types.AvailableModels = #Qwen2_5_500M;
            associatedCanisterAddress : ?Types.CanisterAddress = ?controllerCanisterAddress;
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

    // Use with caution: Admin functions to reset the model file buffer
    /* public shared (msg) func reset_mainer_llm_model_file_buffer() : async Types.FileUploadResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        modelFileUploadBuffer := SB.StableBuffer( SB.State.init({size=122; capacity=1000}) );

        return #Ok({ creationResult = "Success" });
    }; */

    // -------------------------------------------------------------------------------
    // Canister upgrades

    // System-provided lifecycle method called before an upgrade.
    system func preupgrade() {
        // Copy the runtime state back into the stable variable before upgrade.
        creationArtefactsByModelStable := Iter.toArray(creationArtefactsByModel.entries());
    };

    // System-provided lifecycle method called after an upgrade or on initial deploy.
    system func postupgrade() {
        // After upgrade, reload the runtime state from the stable variable.
        creationArtefactsByModel := HashMap.fromIter(Iter.fromArray(creationArtefactsByModelStable), creationArtefactsByModelStable.size(), Text.equal, Text.hash);
        creationArtefactsByModelStable := [];
    };
    // -------------------------------------------------------------------------------
};
