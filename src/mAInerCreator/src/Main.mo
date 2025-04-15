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
import Time "mo:base/Time";
import Error "mo:base/Error";

import Types "../../common/Types";

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

    let IC0 : Types.IC_Management = actor ("aaaaa-aa");

    // Admin function to upload mainer agent controller canister wasm
    private stable var mainerControllerCanisterWasm : [Nat8] = [];

    public shared (msg) func start_upload_mainer_controller_canister_wasm() : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        mainerControllerCanisterWasm := [];
        return #Ok({ status_code = 200 });
    };

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

    private func getModelCreationArtefacts(selectedModel : Types.SelectableMainerLLMs) : ?Types.ModelCreationArtefacts {
        switch (selectedModel) {
            case (#Qwen2_5_500M) {
                let creationArtefacts : ?Types.ModelCreationArtefacts = creationArtefactsByModel.get("Qwen2_5_500M");
                return creationArtefacts;
            };
            case _ { return null };
        };
    };

    private func putModelCreationArtefacts(selectedModel : Types.SelectableMainerLLMs, creationArtefacts : Types.ModelCreationArtefacts) : Bool {
        switch (selectedModel) {
            case (#Qwen2_5_500M) {
                let putArtefacts = creationArtefactsByModel.put("Qwen2_5_500M", creationArtefacts);
                return true;
            };
            case _ { return false; };
        };
    };

    // Admin function to insert needed artefacts to create canisters for a new model type
    public shared (msg) func addModelCreationArtefactsEntry(selectedModel : Types.SelectableMainerLLMs, creationArtefacts : Types.ModelCreationArtefacts) : async Types.InsertArtefactsResult {
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

    // Admin function to start upload of the mainer LLM canister wasm
    public shared (msg) func start_upload_mainer_llm_canister_wasm(selectedModel : Types.SelectableMainerLLMs) : async Types.StatusCodeRecordResult {
        D.print("mAInerCreator: start_upload_mainer_llm_canister_wasm");
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        switch (getModelCreationArtefacts(selectedModel)) {
            case (?existingArtefacts) {
                let updatedArtefacts : Types.ModelCreationArtefacts = {
                    canisterWasm = []; // Resetting the wasm storage array
                    modelFile : [Blob] = existingArtefacts.modelFile; // Leave the llm model file as is
                    modelFileSha256 : Text = existingArtefacts.modelFileSha256;
                };

                let updateArtefactsResult = putModelCreationArtefacts(selectedModel, updatedArtefacts);

                return #Ok({ status_code = 200 });
            };
            case _ {
                // new entry - nothing to reset
                return #Ok({ status_code = 200 });
            };
        };
    };

    // Admin function to upload an LLM canister wasm file
    public shared (msg) func upload_mainer_llm_canister_wasm_bytes_chunk(selectedModel : Types.SelectableMainerLLMs, bytesChunk : [Nat8]) : async Types.FileUploadResult {
        D.print("mAInerCreator: upload_mainer_llm_canister_wasm_bytes_chunk");
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
                    modelFile : [Blob] = existingArtefacts.modelFile;
                    modelFileSha256 : Text = existingArtefacts.modelFileSha256;
                };

                let updateArtefactsResult = putModelCreationArtefacts(selectedModel, updatedArtefacts);

                return #Ok({ creationResult = "Success" });
            };
            case _ {
                // new entry
                let newArtefacts : Types.ModelCreationArtefacts = {
                    canisterWasm : [Nat8] = bytesChunk;
                    modelFile : [Blob] = [];
                    modelFileSha256 : Text = "";
                };

                let updateArtefactsResult = putModelCreationArtefacts(selectedModel, newArtefacts);
                return #Ok({ creationResult = "New entry created" });
            };
        };
    };

    // Data structure for the model file
    stable var nextChunkID : Nat = 0;
    stable let innerInitArray : [Nat8] = Array.freeze<Nat8>(Array.init<Nat8>(1, 1));
    stable let initBlob : Blob = Blob.fromArray(innerInitArray);
    stable var modelFileChunks : [var Blob] = Array.init<Blob>(1, initBlob);

    // Admin function to start upload of the mainer LLM model file
    public shared (msg) func start_upload_mainer_llm() : async Types.StatusCodeRecordResult {
        D.print("mAInerCreator: reset_mainer_llm_model_file");
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // By setting nextChunkID to zero, we effectively reset the model file upload process
        // The first call to upload_mainer_llm_bytes_chunk will initialize the data structure
        nextChunkID := 0;
        return #Ok({ status_code = 200 });
    };

    // Admin function to upload a model file chunk
    public shared (msg) func upload_mainer_llm_bytes_chunk(bytesChunk : Blob, chunkID : Nat) : async Types.FileUploadResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (chunkID == 0 and nextChunkID == 0) {
            // initialize data structure only on the first chunk
            modelFileChunks := Array.init<Blob>(400, initBlob);
        };

        // Only process if this is the expected next chunk or a retry of a previous chunk
        if (chunkID < nextChunkID) {
            // This is a retry of a chunk we've already processed
            return #Ok({ creationResult = "Success" });
        } else if (chunkID == nextChunkID) {
            // This is the expected next chunk, so process it
            ignore modelFileChunks[chunkID] := bytesChunk;
            nextChunkID := nextChunkID + 1;
            return #Ok({ creationResult = "Success" });
        } else {
            // This is a chunk ahead of what we expect (gap in sequence)
            return #Err(#Other("Chunk ID " # Nat.toText(chunkID) # " is ahead of the expected chunk ID " # Nat.toText(nextChunkID)));
        };
    };

    // Admin function to finish the upload of a model file
    public shared (msg) func finish_upload_mainer_llm(selectedModel : Types.SelectableMainerLLMs, modelFileSha256 : Text) : async Types.FileUploadResult {
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
                    modelFile : [Blob] = Array.subArray<Blob>(Array.freeze<Blob>(modelFileChunks), 0, nextChunkID);
                    modelFileSha256 : Text = modelFileSha256;
                };

                let updateArtefactsResult = putModelCreationArtefacts(selectedModel, updatedArtefacts);

                switch (updateArtefactsResult) {
                    case (true) {
                        modelFileChunks := Array.init<Blob>(1, initBlob); // reset model file upload data structure (to save memory)
                        nextChunkID := 0;
                        return #Ok({ creationResult = "Success" });
                    };
                    case (false) {
                        return #Err(#Other("Error storing the model artefact"));
                    };
                };                
            };
            case _ { return #Err(#Other("Add the canisterWasm first.")) };
        };
    };

    private func retryLlmChunkUploadWithDelay(llmCanisterActor : Types.LLMCanister, uploadChunk : Types.FileUploadInputRecord, attempts : Nat, delay : Nat) : async Types.FileUploadRecordResult {
        if (attempts > 0) {
            try {
                D.print("mAInerCreator: retryLlmChunkUploadWithDelay calling file_upload_chunk for chunksize, offset = " # debug_show (uploadChunk.chunksize) # ", " # debug_show (uploadChunk.offset));
                let uploadModelFileResult : Types.FileUploadRecordResult = await llmCanisterActor.file_upload_chunk(uploadChunk);
                return uploadModelFileResult;
                
            } catch (e) {
                D.print("LLM file_upload_chunk failed with catch error " # Error.message(e) # ", retrying in " # debug_show(delay) # " nanoseconds");
                
                // TODO: introduce a delay using a timer...
                // Just retry immediately with decremented attempts
                return await retryLlmChunkUploadWithDelay(llmCanisterActor, uploadChunk, attempts - 1, delay);
            };
        } else {
            D.print("Max retry attempts reached");
            return #Err(#Other("Max retry attempts reached"));
        };
    };

    // Spin up a new canister as specified by the input parameters
    public shared (msg) func createCanister(configurationInput : Types.CanisterCreationConfiguration) : async Types.CanisterCreationResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        // Only Controllers and the Master canister may call this (plus the canister itself for testing functionality)
        D.print("mAInerCreator: createCanister - msg.caller = " # debug_show(msg.caller));
        D.print("mAInerCreator: createCanister - MASTER_CANISTER_ID = " # debug_show(MASTER_CANISTER_ID));
        D.print("mAInerCreator: createCanister - Principal.isController(msg.caller) = " # debug_show(Principal.isController(msg.caller)));
        D.print("mAInerCreator: createCanister - Principal.fromText(MASTER_CANISTER_ID) = " # debug_show(Principal.fromText(MASTER_CANISTER_ID)));
        D.print("mAInerCreator: createCanister - Principal.fromActor(this) = " # debug_show(Principal.fromActor(this)));
        if (not (Principal.isController(msg.caller) or Principal.equal(msg.caller, Principal.fromText(MASTER_CANISTER_ID)) or Principal.equal(msg.caller, Principal.fromActor(this)))) {
            return #Err(#Unauthorized);
        };
        D.print("mAInerCreator: createCanister - configurationInput = " # debug_show (configurationInput));

        switch (configurationInput.canisterType) {
            case (#MainerAgent(_)) {
                // Create mAIner controller canister for new mAIner agent
                Cycles.add(1_000_000_000_000);  // 1T cycles (800B was the minimum required) TODO: adjust based on actual cycles user paid for during creation

                let mainerAgentCanisterType = configurationInput.mainerConfig.mainerAgentCanisterType;
                D.print("mAInerCreator: createCanister - mainerAgentCanisterType = " # debug_show (mainerAgentCanisterType));
                var shareServiceCanisterAddress : Types.CanisterAddress = ""; // TODO: determine if this should be provided or whether Creator stores this info and fills it in here
                if (mainerAgentCanisterType == #ShareAgent) {
                    switch (configurationInput.associatedCanisterAddress) {
                        case (null) {
                            return #Err(#Other("mAInerCreator: createCanister - a #ShareAgent canister requires the shareServiceCanisterAddress to be provided in the onfigurationInput.associatedCanisterAddress."));
                        };
                        case (?associatedCanisterAddress) {
                            shareServiceCanisterAddress := associatedCanisterAddress;
                            D.print("mAInerCreator: createCanister shareServiceCanisterAddress = " # debug_show (shareServiceCanisterAddress));
                            let isValidPrincipal = Principal.fromText(associatedCanisterAddress); // this will throw an error if it's not a valid canister address
                            D.print("mAInerCreator: createCanister isValidPrincipal " # debug_show (isValidPrincipal));
                        };
                    };
                };

                let createdControllerCanister = await IC0.create_canister({
                    settings = ?{
                        freezing_threshold = null;
                        controllers = ?[Principal.fromActor(this), configurationInput.owner];
                        memory_allocation = null;
                        compute_allocation = null;
                    };
                });

                D.print("mAInerCreator: createCanister - createdControllerCanister = " # debug_show (createdControllerCanister));

                let installControllerWasm = await IC0.install_code({
                    arg = "";
                    wasm_module = Blob.fromArray(mainerControllerCanisterWasm);
                    mode = #install;
                    canister_id = createdControllerCanister.canister_id;
                });
                D.print("mAInerCreator: createCanister - installControllerWasm "# debug_show (installControllerWasm));

                // Verify new canister is working
                let controllerCanisterActor = actor (Principal.toText(createdControllerCanister.canister_id)) : Types.MainerAgentCtrlbCanister;
                D.print("mAInerCreator: createCanister - calling createdControllerCanister.health()");
                let readyControllerResult = await controllerCanisterActor.health();
                D.print("mAInerCreator: createCanister - readyControllerResult " # debug_show (readyControllerResult));
                switch (readyControllerResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                // Set Game State canister address
                D.print("mAInerCreator: createCanister - calling createdControllerCanister.setGameStateCanisterId(MASTER_CANISTER_ID)");
                let setControllerGameStateResult = await controllerCanisterActor.setGameStateCanisterId(MASTER_CANISTER_ID);
                D.print("mAInerCreator: createCanister setControllerGameStateResult " # debug_show (setControllerGameStateResult));
                switch (setControllerGameStateResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };
                

                // Set the setMainerCanisterType
                D.print("mAInerCreator: createCanister - calling createdControllerCanister.setMainerCanisterType(mainerAgentCanisterType)");
                let statusCodeRecordResult = await controllerCanisterActor.setMainerCanisterType(mainerAgentCanisterType);
                D.print("mAInerCreator: createCanister setControllerGameStateResult " # debug_show (setControllerGameStateResult));
                switch (statusCodeRecordResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                let mainerAgentCanisterInput : Types.MainerAgentCanisterInput = {
                    address = Principal.toText(createdControllerCanister.canister_id);
                    canisterType = configurationInput.canisterType;
                    ownedBy = configurationInput.owner;
                    mainerAgentCanisterType = mainerAgentCanisterType; 
                    status = #ControllerCreated;
                    mainerConfig = configurationInput.mainerConfig;
                };
                // This should not be needed as the Game State makes this call to the Creator and thus the returned response will be used to Register the mAIner Agent with the GameState canister
                if (MASTER_CANISTER_ID != Principal.toText(msg.caller)) {
                    // TODO: decide whether this block should be kept in production
                    let gameStateCanisterActor = actor (MASTER_CANISTER_ID) : Types.GameStateCanister_Actor;
                    D.print("mAInerCreator: createCanister - calling gameStateCanisterActor.addMainerAgentCanister with mainerAgentCanisterInput = " # debug_show (mainerAgentCanisterInput));
                    let addMainerAgentCanisterResult = await gameStateCanisterActor.addMainerAgentCanister(mainerAgentCanisterInput);
                    D.print("mAInerCreator: createCanister addMainerAgentCanisterResult" # debug_show (addMainerAgentCanisterResult));
                    switch (addMainerAgentCanisterResult) {
                        case (#Err(error)) {
                            return #Err(error);
                        };
                        case _ {
                            // all good, continue
                        };
                    };
                };

                // Link up the ShareAgent & ShareService canisters 
                if (mainerAgentCanisterType == #ShareAgent) {
                    // Set the Share Service canister id for the Share Agent canister
                    D.print("mAInerCreator: createCanister - calling controllerCanisterActor.setShareServiceCanisterId(shareServiceCanisterAddress)");
                    let statusCodeRecordResult = await controllerCanisterActor.setShareServiceCanisterId(shareServiceCanisterAddress);
                    D.print("mAInerCreator: createCanister statusCodeRecordResult " # debug_show (statusCodeRecordResult));
                    switch (statusCodeRecordResult) {
                        case (#Err(error)) {
                            return #Err(error);
                        };
                        case _ {
                            // all good, continue
                        };
                    };

                    // Register the Share Agent canister with the Share Service canister, so it is allowed to call it
                    let shareServiceCanisterActor = actor (shareServiceCanisterAddress) : Types.MainerAgentCtrlbCanister;
                    D.print("mAInerCreator: createCanister - calling shareServiceCanisterActor.addMainerShareAgentCanister with mainerAgentCanisterInput = " # debug_show (mainerAgentCanisterInput));
                    let mainerAgentCanisterResult = await shareServiceCanisterActor.addMainerShareAgentCanister(mainerAgentCanisterInput);
                    D.print("mAInerCreator: createCanister mainerAgentCanisterResult " # debug_show (mainerAgentCanisterResult));
                    switch (mainerAgentCanisterResult) {
                        case (#Err(error)) {
                            return #Err(error);
                        };
                        case _ {
                            // all good, continue
                        };
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
                D.print("mAInerCreator: createCanister MainerLlm");
                // Sanity check
                switch (configurationInput.associatedCanisterAddress) {
                    case (null) {
                        return #Err(#Other("Please provide the canister address of the associated mAIner controller canister"));
                    };
                    case (?associatedCanisterAddress) {
                        D.print("mAInerCreator: createCanister associatedCanisterAddress = " # debug_show (associatedCanisterAddress));
                        let isValidPrincipal = Principal.fromText(associatedCanisterAddress); // this will throw an error if it's not a valid canister address
                        D.print("mAInerCreator: createCanister isValidPrincipal " # debug_show (isValidPrincipal));
                        var selectedModel = #Qwen2_5_500M;
                        switch (configurationInput.mainerConfig.selectedLLM) {
                            case (null) {
                                // use default
                                selectedModel := #Qwen2_5_500M; // TODO: retrieve default via function
                            };
                            case (?selectedLLM) {
                                selectedModel := selectedLLM;                                
                            };
                        };
                        switch (getModelCreationArtefacts(selectedModel)) {
                            case (null) {
                                return #Err(#Other("Cannot find creation artefacts for the selected model"));
                            };
                            case (?modelCreationArtefacts) {
                                D.print("mAInerCreator: createCanister modelCreationArtefacts");
                                // Create mAIner LLM (and add it to a mAIner controller)
                                Cycles.add(3_000_000_000_000);  // 3T cycles  (TODO: what is the minimum?) adjust based on cycles user paid for (and are being sent from Game State)

                                let createdLlmCanister = await IC0.create_canister({
                                    settings = ?{
                                        freezing_threshold = null;
                                        controllers = ?[Principal.fromText(associatedCanisterAddress), Principal.fromActor(this), configurationInput.owner];
                                        memory_allocation = null;
                                        compute_allocation = null;
                                    };
                                });
                                D.print("mAInerCreator: createCanister createdLlmCanister");
                                D.print(debug_show (createdLlmCanister));

                                let installLlmWasm = await IC0.install_code({
                                    arg = "";
                                    wasm_module = Blob.fromArray(modelCreationArtefacts.canisterWasm);
                                    mode = #install;
                                    canister_id = createdLlmCanister.canister_id;
                                });
                                D.print("mAInerCreator: createCanister installLlmWasm");
                                D.print(debug_show (installLlmWasm));

                                // Verify new canister is working
                                let llmCanisterActor = actor (Principal.toText(createdLlmCanister.canister_id)) : Types.LLMCanister;
                                D.print("mAInerCreator: createCanister llmCanisterActor");
                                let readyLlmResult = await llmCanisterActor.health();
                                D.print("mAInerCreator: createCanister readyLlmResult = " # debug_show (readyLlmResult));
                                switch (readyLlmResult) {
                                    case (#Err(error)) {
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };

                                // Make LLM functional
                                // Upload model file
                                // let chunkSize = 42000; // ~0.01 MB for testing
                                //var chunkSize : Nat = 9 * 1024 * 1024; // 9 MB
                                var chunkSize : Nat = 0;
                                var offset : Nat = 0;
                                var nextChunk : [Nat8] = [];
                                
                                D.print("mAInerCreator: createCanister start upload of LLM model");
                                var chunkCount : Nat = 0;
                                var uploadModelFileResult : Types.FileUploadRecordResult = #Ok({ filename = "models/model.gguf"; filesha256 = ""; filesize = 0 }); // Placeholder
                                for (chunk in modelCreationArtefacts.modelFile.vals()) {
                                    if (chunkCount % 10 == 0) {
                                        D.print("mAInerCreator: createCanister uploading file chunk " # debug_show (chunkCount));
                                    };
                                    chunkCount := chunkCount + 1;
                                    
                                    nextChunk := Blob.toArray(chunk);
                                    chunkSize := nextChunk.size();
                                    let uploadChunk : Types.FileUploadInputRecord = {
                                        filename = "models/model.gguf";
                                        chunk = nextChunk;
                                        chunksize = Nat64.fromNat(chunkSize);
                                        offset = Nat64.fromNat(offset);
                                    };

                                    // var attempts : Nat = 0;
                                    var delay : Nat = 2_000_000_000; // 2 seconds
                                    let maxAttempts : Nat = 8;
                                    uploadModelFileResult := await retryLlmChunkUploadWithDelay(llmCanisterActor, uploadChunk, maxAttempts, delay);
                                    switch (uploadModelFileResult) {
                                        case (#Err(error)) {
                                            D.print("mAInerCreator: createCanister ERROR - uploadModelFileResult:");
                                            D.print(debug_show (uploadModelFileResult));
                                            return #Err(error);
                                        };
                                        case (#Ok(_)) {
                                            // all good, continue with next chunk
                                            D.print("mAInerCreator: createCanister uploadModelFileResult = " # debug_show (uploadModelFileResult));
                                            offset := offset + chunkSize;
                                        };
                                    };
                                };

                                D.print("mAInerCreator: createCanister after upload -- checking filesha256.");
                                // This is how uploadModelFileResult looks like for Qwen2.5-05B-instruct model:
                                // #Ok({filename = "models/model.gguf"; filesha256 = "ca59ca7f13d0e15a8cfa77bd17e65d24f6844b554a7b6c12e07a5f89ff76844e"; filesize = 675_710_816})
                                switch (uploadModelFileResult) {
                                    case (#Err(error)) {
                                        D.print("mAInerCreator: createCanister ERROR - uploadModelFileResult:");
                                        D.print(debug_show (uploadModelFileResult));
                                        return #Err(error);
                                    };
                                    case (#Ok(uploadModelFileRecord)) {
                                        D.print("mAInerCreator: createCanister uploadModelFileRecord");
                                        D.print(debug_show (uploadModelFileRecord));
                                        // Check the sha256
                                        let filesha256 : Text = uploadModelFileRecord.filesha256;
                                        let expectedSha256 : Text = modelCreationArtefacts.modelFileSha256;
                                        
                                        if (not (filesha256 == expectedSha256)) {
                                            D.print("mAInerCreator: createCanister - ERROR: filesha256 = " # debug_show (filesha256) # "does not match expectedSha256 = " # debug_show (expectedSha256));
                                            return #Err(#Other("The sha256 of the uploaded llm file is " # filesha256 # ", which does not match the expected value of " # expectedSha256));
                                        } else {
                                            D.print("mAInerCreator: createCanister - filesha256 matches expectedSha256 = " # debug_show (expectedSha256));
                                        };
                                    };
                                };

                                // load model file in LLM
                                let inputRecord : Types.InputRecord = {
                                    args : [Text] = ["--model", "models/model.gguf"];
                                };
                                let loadModelResult = await llmCanisterActor.load_model(inputRecord);
                                D.print("mAInerCreator: createCanister loadModelResult");
                                D.print(debug_show (loadModelResult));
                                switch (loadModelResult) {
                                    case (#Err(error)) {
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };

                                // set max tokens
                                // TODO: This is for the Qwen 2.5-0.5B model, need to make it dynamic
                                let MAX_TOKENS : Nat64 = 13;
                                let maxTokensRecord : Types.MaxTokensRecord = {
                                    max_tokens_update : Nat64 = MAX_TOKENS;
                                    max_tokens_query : Nat64 = MAX_TOKENS;
                                };
                                let setMaxTokensResult = await llmCanisterActor.set_max_tokens(maxTokensRecord);
                                D.print("mAInerCreator: createCanister setMaxTokensResult");
                                D.print(debug_show (setMaxTokensResult));
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
                                D.print("mAInerCreator: createCanister associatedControllerCanisterActor");
                                let addLlmToControllerResult = await associatedControllerCanisterActor.add_llm_canister({ canister_id = Principal.toText(createdLlmCanister.canister_id); });
                                D.print("mAInerCreator: createCanister addLlmToControllerResult");
                                D.print(debug_show (addLlmToControllerResult));
                                switch (addLlmToControllerResult) {
                                    case (#Err(error)) {
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };
                                // Don't call this, so all the LLMs will be used by default in a round robbin fashion
                                // let roundRobinSetting : Nat = 1;
                                // let setControllerRoundRobinResult = await associatedControllerCanisterActor.setRoundRobinLLMs(roundRobinSetting);
                                // D.print("mAInerCreator: createCanister setControllerRoundRobinResult");
                                // D.print(debug_show (setControllerRoundRobinResult));
                                // switch (setControllerRoundRobinResult) {
                                //     case (#Err(error)) {
                                //         return #Err(error);
                                //     };
                                //     case _ {
                                //         // all good, continue
                                //     };
                                // };

                                 // Pause the logging of the LLM to avoid excessive debug prints
                                D.print("mAInerCreator: createCanister calling LLMs log_pause");
                                let logPauseResult = await llmCanisterActor.log_pause();
                                D.print("mAInerCreator: createCanister logPauseResult = "# debug_show (logPauseResult));
                                switch (logPauseResult) {
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
                                D.print("mAInerCreator: createCanister creationRecord");
                                D.print(debug_show (creationRecord));
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
    public shared (msg) func testCreateMainerControllerCanister(mainerAgentCanisterType : Types.MainerAgentCanisterType, shareServiceCanisterAddress : ?Types.CanisterAddress) : async Types.CanisterCreationResult {
        D.print("mAInerCreator: entered testCreateMainerControllerCanister");
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let mainerConfig : Types.MainerConfigurationInput = {
            mainerAgentCanisterType: Types.MainerAgentCanisterType = mainerAgentCanisterType;
            selectedLLM : ?Types.SelectableMainerLLMs = ?#Qwen2_5_500M;
        };
        let config : Types.CanisterCreationConfiguration = {
            canisterType : Types.ProtocolCanisterType = #MainerAgent(#Own);
            associatedCanisterAddress : ?Types.CanisterAddress = shareServiceCanisterAddress;
            owner : Principal = msg.caller; 
            mainerConfig : Types.MainerConfigurationInput = mainerConfig;
        };
        D.print("mAInerCreator: testCreateMainerControllerCanister - calling createCanister with config" # debug_show(config));
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

        // Sanity checks for controllerCanisterAddress
        try {
            // Check if the controller canister address exists and is functioning
            let controllerActor = actor (controllerCanisterAddress) : Types.MainerAgentCtrlbCanister;
            let healthResult = await controllerActor.health();
            
            switch (healthResult) {
            case (#Err(_)) {
                return #Err(#Other("Controller canister " # controllerCanisterAddress # " is not healthy"));
            };
            case (#Ok(_)) {
                // Controller is healthy, now check its type
                let canisterTypeResult = await controllerActor.getMainerCanisterType();
                
                switch (canisterTypeResult) {
                case (#Err(_)) {
                    return #Err(#Other("Failed to get controller canister type"));
                };
                case (#Ok(canisterType)) {
                    // Verify this is an allowed controller type
                    switch (canisterType) {
                    case (#Own) {
                        // This is allowed
                    };
                    case (#ShareService) {
                        // This is allowed
                    };
                    case (#ShareAgent) {
                        return #Err(#Other("ShareAgent type canister is not allowed to control an LLM canister"));
                    };
                    case _ {
                        return #Err(#Other("Invalid controller canister type " # debug_show(canisterType)));
                    };
                    };
                };
                };
            };
            };
        } catch (_) {
            D.print("mAInerCreator: testCreateMainerLlmCanister - Error accessing controller canister: ");
            return #Err(#Other("Controller canister does not exist or is not accessible"));
        };
        let mainerConfig : Types.MainerConfigurationInput = {
            mainerAgentCanisterType: Types.MainerAgentCanisterType = #Own;
            selectedLLM : ?Types.SelectableMainerLLMs = ?#Qwen2_5_500M;
        };

        let config : Types.CanisterCreationConfiguration = {
            canisterType : Types.ProtocolCanisterType = #MainerLlm;
            associatedCanisterAddress : ?Types.CanisterAddress = ?controllerCanisterAddress;
            owner : Principal = msg.caller;
            mainerConfig : Types.MainerConfigurationInput = mainerConfig;
        };
        let result = await createCanister(config);
        return result;
    };

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