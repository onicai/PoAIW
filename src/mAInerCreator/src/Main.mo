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
import ICManagementCanister "../../common/ICManagementCanister";
import CreateCanisterWithCMC "../../common/CreateCanisterWithCMC";
import InstallCanisterCode "../../common/InstallCanisterCode";

actor class MainerCreatorCanister() = this {

    stable var MASTER_CANISTER_ID : Text = "be2us-64aaa-aaaaa-qaabq-cai"; // Corresponds to Game State canister

    public shared (msg) func setMasterCanisterId(_master_canister_id : Text) : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        MASTER_CANISTER_ID := _master_canister_id;
        let authRecord = { auth = "You set the master canister for this canister." };
        return #Ok(authRecord);
    };

    let IC0 : ICManagementCanister.IC_Management = actor ("aaaaa-aa");

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

    // Admin function to upload mainer agent controller canister wasm
    private stable var mainerControllerCanisterWasm : [Blob] = [];

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

        if (bytesChunk.size() > 2_000_000) {
            return #Err(#Other("Chunk too large ! Maximum size is 2MB."));
        };

        // Append the incoming chunk as a Blob - maintain the chunks so we do not need to re-chunk during code installation
        let chunkBlob = Blob.fromArray(bytesChunk);
        mainerControllerCanisterWasm := Array.append(mainerControllerCanisterWasm, [chunkBlob]);

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
    public shared (msg) func addModelCreationArtefactsEntry(addModelCreationArtefactsEntryInput : Types.AddModelCreationArtefactsEntry) : async Types.InsertArtefactsResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let selectedModel = addModelCreationArtefactsEntryInput.selectedModel;
        let creationArtefacts = addModelCreationArtefactsEntryInput.creationArtefacts;
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
    public shared (msg) func upload_mainer_llm_canister_wasm_bytes_chunk(uploadMainerLlmCanisterWasmBytesChunkInput : Types.UploadMainerLlmCanisterWasmBytesChunkInput) : async Types.FileUploadResult {
        D.print("mAInerCreator: upload_mainer_llm_canister_wasm_bytes_chunk");
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let selectedModel = uploadMainerLlmCanisterWasmBytesChunkInput.selectedModel;
        let bytesChunk = uploadMainerLlmCanisterWasmBytesChunkInput.bytesChunk;

        // Append the incoming chunk as a Blob - maintain the chunks so we do not need to re-chunk during code installation
        let chunkBlob = Blob.fromArray(bytesChunk);
        switch (getModelCreationArtefacts(selectedModel)) {
            case (?existingArtefacts) {
                let updatedArtefacts : Types.ModelCreationArtefacts = {
                    canisterWasm = Array.append(existingArtefacts.canisterWasm, [chunkBlob]);
                    modelFile : [Blob] = existingArtefacts.modelFile;
                    modelFileSha256 : Text = existingArtefacts.modelFileSha256;
                };

                let updateArtefactsResult = putModelCreationArtefacts(selectedModel, updatedArtefacts);

                return #Ok({ creationResult = "Success" });
            };
            case _ {
                // new entry
                let newArtefacts : Types.ModelCreationArtefacts = {
                    canisterWasm : [Blob] = [chunkBlob];
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
    stable let MAX_MODEL_FILE_CHUNKS : Nat = 400; // TODO - Design: should this be a parameter or switch to Buffer?

    // Admin function to start upload of the mainer LLM model file
    public shared (msg) func start_upload_mainer_llm() : async Types.StatusCodeRecordResult {
        D.print("mAInerCreator: start_upload_mainer_llm");
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // By setting nextChunkID to zero, we effectively reset the model file upload process
        // The first call to upload_mainer_llm_bytes_chunk will initialize the data structure
        nextChunkID := 0;
        return #Ok({ status_code = 200 });
    };

    // Admin function to upload a model file chunk
    public shared (msg) func upload_mainer_llm_bytes_chunk(uploadMainerLlmBytesChunkInput : Types.UploadMainerLlmBytesChunkInput) : async Types.FileUploadResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let bytesChunk = uploadMainerLlmBytesChunkInput.bytesChunk;
        let chunkID = uploadMainerLlmBytesChunkInput.chunkID;
        if (chunkID >= MAX_MODEL_FILE_CHUNKS) {
            return #Err(#Other("upload_mainer_llm_bytes_chunk: chunkID exceeds maximum allowed value - overflowing the allocated size of the modelFileChunks array"));
        };
        if (chunkID == 0 and nextChunkID == 0) {
            // initialize data structure only on the first chunk
            modelFileChunks := Array.init<Blob>(MAX_MODEL_FILE_CHUNKS, initBlob);
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
    public shared (msg) func finish_upload_mainer_llm(finishUploadMainerLlmInput : Types.FinishUploadMainerLlmInput) : async Types.FileUploadResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        let selectedModel = finishUploadMainerLlmInput.selectedModel;
        let modelFileSha256 = finishUploadMainerLlmInput.modelFileSha256;

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

    // Uploads a chunk of the model file to the LLM canister
    private func retryLlmChunkUploadWithDelay(llmCanisterActor : Types.LLMCanister, uploadChunk : Types.FileUploadInputRecord, attempts : Nat, delay : Nat) : async Types.FileUploadRecordResult {
        if (attempts > 0) {
            try {
                D.print("mAInerCreator: retryLlmChunkUploadWithDelay calling file_upload_chunk for chunksize, offset = " # debug_show (uploadChunk.chunksize) # ", " # debug_show (uploadChunk.offset));
                let uploadModelFileResult : Types.FileUploadRecordResult = await llmCanisterActor.file_upload_chunk(uploadChunk);
                return uploadModelFileResult;
                
            } catch (e) {
                D.print("LLM file_upload_chunk failed with catch error " # Error.message(e) # ", retrying in " # debug_show(delay) # " nanoseconds");
                
                // TODO - Implementation: introduce a delay using a timer...
                // Just retry immediately with decremented attempts
                return await retryLlmChunkUploadWithDelay(llmCanisterActor, uploadChunk, attempts - 1, delay);
            };
        } else {
            D.print("Max retry attempts reached");
            return #Err(#Other("Max retry attempts reached"));
        };
    };

    // Create a new canister as specified by the input parameters, but do not yet install code or configure
    // This function is designed to be awaited, and returns the newly created canister address
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
                let mainerAgentCanisterType = configurationInput.mainerConfig.mainerAgentCanisterType;
                D.print("mAInerCreator: createCanister - mainerAgentCanisterType = " # debug_show (mainerAgentCanisterType));
                var shareServiceCanisterAddress : Types.CanisterAddress = ""; // TODO - Design: determine if this should be provided or whether Creator stores this info and fills it in here
                if (mainerAgentCanisterType == #ShareAgent) {
                    switch (configurationInput.associatedCanisterAddress) {
                        case (null) {
                            return #Err(#Other("mAInerCreator: createCanister - a #ShareAgent canister requires the shareServiceCanisterAddress to be provided in the onfigurationInput.associatedCanisterAddress."));
                        };
                        case (?associatedCanisterAddress) {
                            shareServiceCanisterAddress := associatedCanisterAddress;
                            try {
                                // Make sure the associated canister actually exists
                                let _ = Principal.fromText(associatedCanisterAddress); // this will throw an error if it's not a valid canister address
                                let associatedControllerCanisterActor = actor (associatedCanisterAddress) : Types.MainerAgentCtrlbCanister;
                                let healthResult = await associatedControllerCanisterActor.health();
                                D.print("mAInerCreator: createCanister - healthResult" # debug_show (healthResult));
                                switch (healthResult) {
                                    case (#Err(error)) {
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };
                            } catch (e) {
                                D.print("mAInerCreator: createCanister - failed to validate existence & health of associatedCanisterAddress: " # debug_show(associatedCanisterAddress ) # " Error: " # Error.message(e) );
                                return #Err(#Other("mAInerCreator: createCanister - failed to validate existence & health of associatedCanisterAddress: " # debug_show(associatedCanisterAddress ) #  " Error: " # Error.message(e)));
                            };
                        };
                    };
                };

                // Accept required cycles for mAIner controller creation
                let cyclesAcceptedForMainerAgentCtrlbCreation = Cycles.accept<system>(configurationInput.cyclesCreateMainerctrlGsMc);
                D.print("mAInerCreator: createCanister - cyclesAcceptedForMainerAgentCtrlbCreation = " # debug_show (cyclesAcceptedForMainerAgentCtrlbCreation));
                // if (cyclesAcceptedForMainerAgentCtrlbCreation != cyclesCreateMainerGsMc) {
                //     // Sanity check: At this point, this should never fail
                //     D.print("mAInerCreator: createCanister - should never fail checking cyclesAcceptedForMainerAgentCtrlbCreation");
                //     return #Err(#Unauthorized);                    
                // };

                // CMC based approach, allows to specify the subnet
                let subnetCtrl : Text = configurationInput.mainerConfig.subnetCtrl;
                let cyclesToAttach : Nat = configurationInput.cyclesCreateMainerctrlMcMainerctrl;
                // TODO - remove owner from controllers
                let controllers : [Principal] = [Principal.fromActor(this), configurationInput.owner];
                D.print("mAInerCreator: createCanister - Calling CMC.create_canister_on_subnet targeting subnet " # subnetCtrl # " with " # debug_show(cyclesToAttach) # " cycles.");
                let createCanisterWithCMCResult = await CreateCanisterWithCMC.createCanisterOnSubnet(cyclesToAttach, subnetCtrl, ?controllers);
                var canister_id = Principal.fromText("aaaaa-aa"); // Placeholder
                switch (createCanisterWithCMCResult) {
                    case (#Ok(newCanisterId)) {
                        canister_id := newCanisterId;
                    };
                    case (#Err(errorMessage)) {
                        D.print("mAInerCreator: createCanister - CMC.create_canister_on_subnet failed with error: " # errorMessage);
                        return #Err(#Other("mAInerCreator: createCanister - CMC.create_canister_on_subnet failed with error: " # errorMessage));
                    };
                };

                var cyclesBalance : Nat = 0;
                try {
                    let canisterStatus = await IC0.canister_status({canister_id = canister_id;});
                    cyclesBalance := canisterStatus.cycles;
                } catch (e) {
                    D.print("mAInerCreator: createCanister - Failed to retrieve info for canister_id: " # debug_show(canister_id)  # Error.message(e) );
                    return #Err(#Other("mAInerCreator: createCanister - Failed to retrieve info for canister_id: " # debug_show(canister_id) # Error.message(e)));
                };

                D.print("mAInerCreator: createCanister - canister_id = " # debug_show (canister_id) # "(cyclesBalance = " # debug_show (cyclesBalance) # ")");

                // --------------------------------------------------------------------
                let creationRecord : Types.CanisterCreationRecord = {
                    creationResult : Text = "Success";
                    newCanisterId : Text = Principal.toText(canister_id);
                    subnet : Text = subnetCtrl;
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
                        try {
                            // Make sure the associated canister actually exists
                            let _ = Principal.fromText(associatedCanisterAddress); // this will throw an error if it's not a valid canister address
                            let associatedControllerCanisterActor = actor (associatedCanisterAddress) : Types.MainerAgentCtrlbCanister;
                            let healthResult = await associatedControllerCanisterActor.health();
                            D.print("mAInerCreator: createCanister - healthResult" # debug_show (healthResult));
                            switch (healthResult) {
                                case (#Err(error)) {
                                    return #Err(error);
                                };
                                case _ {
                                    // all good, continue
                                };
                            };
                        } catch (e) {
                            D.print("mAInerCreator: createCanister - failed to validate existence & health of associatedCanisterAddress: " # debug_show(associatedCanisterAddress ) # Error.message(e) );
                            return #Err(#Other("mAInerCreator: createCanister - failed to validate existence & health of associatedCanisterAddress: " # debug_show(associatedCanisterAddress ) #  " Error: " # Error.message(e)));
                        };

                        var selectedModel = #Qwen2_5_500M;
                        switch (configurationInput.mainerConfig.selectedLLM) {
                            case (null) {
                                // use default
                                selectedModel := #Qwen2_5_500M; // TODO - Implementation: retrieve default via function
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

                                // Accept required cycles for canister creation
                                let cyclesAcceptedForMainerAgentLlmCreation = Cycles.accept<system>(configurationInput.cyclesCreateMainerllmGsMc);
                                D.print("mAInerCreator: createCanister - cyclesAcceptedForMainerAgentLlmCreation = " # debug_show (cyclesAcceptedForMainerAgentLlmCreation));
                                // if (cyclesAcceptedForMainerAgentLlmCreation != CyclesFlows.MAINER_AGENT_LLM_CREATION_CYCLES_REQUIRED) {
                                //     // Sanity check: At this point, this should never fail
                                //     D.print("mAInerCreator: createCanister - should never fail checking cyclesAcceptedForMainerAgentLlmCreation");
                                //     return #Err(#Unauthorized);                    
                                // };


                                // CMC based approach, allows to specify the subnet
                                let subnetLlm : Text = configurationInput.mainerConfig.subnetLlm;
                                let cyclesToAttach : Nat = configurationInput.cyclesCreateMainerllmMcMainerllm;
                                // TODO - remove owner from controllers
                                let controllers : [Principal] = [Principal.fromActor(this), Principal.fromText(associatedCanisterAddress), configurationInput.owner];
                                D.print("mAInerCreator: createCanister - Calling CMC.create_canister_on_subnet targeting subnet " # subnetLlm # " with " # debug_show(cyclesToAttach) # " cycles.");
                                let createCanisterWithCMCResult = await CreateCanisterWithCMC.createCanisterOnSubnet(cyclesToAttach, subnetLlm, ?controllers);
                                var canister_id = Principal.fromText("aaaaa-aa"); // Placeholder
                                switch (createCanisterWithCMCResult) {
                                    case (#Ok(newCanisterId)) {
                                        canister_id := newCanisterId;
                                    };
                                    case (#Err(errorMessage)) {
                                        D.print("mAInerCreator: createCanister - CMC.create_canister_on_subnet failed with error: " # errorMessage);
                                        return #Err(#Other("mAInerCreator: createCanister - CMC.create_canister_on_subnet failed with error: " # errorMessage));
                                    };
                                };


                                var cyclesBalance : Nat = 0;
                                try {
                                    let canisterStatus = await IC0.canister_status({canister_id = canister_id;});
                                    cyclesBalance := canisterStatus.cycles;
                                } catch (e) {
                                    D.print("mAInerCreator: createCanister - Failed to retrieve info for createdLlmCanister: " # debug_show(canister_id)  # Error.message(e) );
                                    return #Err(#Other("mAInerCreator: createCanister - Failed to retrieve info for createdLlmCanister: " # debug_show(canister_id) # Error.message(e)));
                                };

                                D.print("mAInerCreator: createCanister - createdLlmCanister = " # debug_show(canister_id) # "(cyclesBalance = " # debug_show (cyclesBalance) # ")");

                                let creationRecord = {
                                    creationResult = "Success";
                                    newCanisterId = Principal.toText(canister_id);
                                    subnet = subnetLlm;
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

    // Installs code into a mAIner canister and configures it.
    // This function is designed to be ignored.
    // It will call the GameState canister addMainerAgentCanister when done, to update the status of the controller canister
    public shared (msg) func setupCanister(setupCanisterInput : Types.SetupCanisterInput) : async Types.CanisterCreationResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let newCanisterId = setupCanisterInput.newCanisterId;
        let configurationInput = setupCanisterInput.configurationInput;
        // Only Controllers and the Master canister may call this (plus the canister itself for testing functionality)
        D.print("mAInerCreator: setupCanister - msg.caller = " # debug_show(msg.caller));
        D.print("mAInerCreator: setupCanister - MASTER_CANISTER_ID = " # debug_show(MASTER_CANISTER_ID));
        D.print("mAInerCreator: setupCanister - Principal.isController(msg.caller) = " # debug_show(Principal.isController(msg.caller)));
        D.print("mAInerCreator: setupCanister - Principal.fromText(MASTER_CANISTER_ID) = " # debug_show(Principal.fromText(MASTER_CANISTER_ID)));
        D.print("mAInerCreator: setupCanister - Principal.fromActor(this) = " # debug_show(Principal.fromActor(this)));
        if (not (Principal.isController(msg.caller) or Principal.equal(msg.caller, Principal.fromText(MASTER_CANISTER_ID)) or Principal.equal(msg.caller, Principal.fromActor(this)))) {
            return #Err(#Unauthorized);
        };
        D.print("mAInerCreator: setupCanister - configurationInput = " # debug_show (configurationInput));

        let newCanisterIdPrincipal = Principal.fromText(newCanisterId);

        switch (configurationInput.canisterType) {
            case (#MainerAgent(_)) {
                // Create mAIner controller canister for new mAIner agent                
                let mainerAgentCanisterType = configurationInput.mainerConfig.mainerAgentCanisterType;
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ")");
                var shareServiceCanisterAddress : Types.CanisterAddress = ""; // TODO - Design: determine if this should be provided or whether Creator stores this info and fills it in here
                if (mainerAgentCanisterType == #ShareAgent) {
                    switch (configurationInput.associatedCanisterAddress) {
                        case (null) {
                            return #Err(#Other("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - a #ShareAgent canister requires the shareServiceCanisterAddress to be provided in the onfigurationInput.associatedCanisterAddress."));
                        };
                        case (?associatedCanisterAddress) {
                            shareServiceCanisterAddress := associatedCanisterAddress;
                            try {
                                // Make sure the associated canister actually exists
                                let _ = Principal.fromText(associatedCanisterAddress); // this will throw an error if it's not a valid canister address
                                let associatedControllerCanisterActor = actor (associatedCanisterAddress) : Types.MainerAgentCtrlbCanister;
                                let healthResult = await associatedControllerCanisterActor.health();
                                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - healthResult" # debug_show (healthResult));
                                switch (healthResult) {
                                    case (#Err(error)) {                                        
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };
                            } catch (e) {
                                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - failed to validate existence & health of associatedCanisterAddress: " # debug_show(associatedCanisterAddress ) # " Error: " # Error.message(e) );
                                return #Err(#Other("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - failed to validate existence & health of associatedCanisterAddress: " # debug_show(associatedCanisterAddress ) # " Error: " # Error.message(e)));
                            };
                        };
                    };
                };

                var cyclesBalance : Nat = 0;
                try {
                    let canisterStatus = await IC0.canister_status({canister_id = newCanisterIdPrincipal ;});
                    cyclesBalance := canisterStatus.cycles;
                } catch (e) {
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - Failed to retrieve info for createdControllerCanister: " # debug_show(newCanisterIdPrincipal )  # Error.message(e) );
                    return #Err(#Other("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - Failed to retrieve info for createdControllerCanister: " # debug_show(newCanisterIdPrincipal ) # Error.message(e)));
                };

                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - createdControllerCanister = " # debug_show (newCanisterIdPrincipal ) # "(cyclesBalance = " # debug_show (cyclesBalance) # ")");

                // --------------------------------------------------
                // install code
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - start installing code into ctrlb canister " # debug_show (newCanisterIdPrincipal));
                let installResult = await InstallCanisterCode.installCanisterCode(newCanisterIdPrincipal, mainerControllerCanisterWasm, #install);
                switch (installResult) {
                    case (#Ok(_)) {
                        D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - Successfully installed code into ctrlb canister " # debug_show (newCanisterIdPrincipal));
                    };
                    case (#Err(errorMessage)) {
                        D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - Failed installing code into ctrlb canister " # debug_show (newCanisterIdPrincipal) # " Error: " # errorMessage);
                        return #Err(#Other("mAInerCreator: setupCanister (" # newCanisterId # ") - Failed installing code into ctrlb canister: " # debug_show(newCanisterIdPrincipal) # " Error: " # errorMessage));
                    };
                };

                var cyclesUsed : Nat = 0;
                try {
                    let canisterStatus = await IC0.canister_status({canister_id = newCanisterIdPrincipal ;});
                    cyclesUsed := cyclesBalance - canisterStatus.cycles;
                    cyclesBalance := canisterStatus.cycles;
                } catch (e) {
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - Failed to retrieve info for createdControllerCanister: " # debug_show(newCanisterIdPrincipal )  # Error.message(e) );
                    return #Err(#Other("mAInerCreator: setupCanister (" # newCanisterId # ") - Failed to retrieve info for createdControllerCanister: " # debug_show(newCanisterIdPrincipal ) # Error.message(e)));
                };
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - install_code for createdControllerCanister = " # debug_show (newCanisterIdPrincipal ) # 
                " - cyclesUsed = " # debug_show (cyclesUsed) # 
                " - cyclesBalance = " # debug_show (cyclesBalance));
                
                // --------------------------------------------------
                // Verify new canister is working
                let controllerCanisterActor = actor (newCanisterId) : Types.MainerAgentCtrlbCanister;
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - calling createdControllerCanister.health()");
                let readyControllerResult = await controllerCanisterActor.health();
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - readyControllerResult " # debug_show (readyControllerResult));
                switch (readyControllerResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                // Set Game State canister address
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - calling createdControllerCanister.setGameStateCanisterId(MASTER_CANISTER_ID)");
                let setControllerGameStateResult = await controllerCanisterActor.setGameStateCanisterId(MASTER_CANISTER_ID);
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - setControllerGameStateResult " # debug_show (setControllerGameStateResult));
                switch (setControllerGameStateResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };
                

                // Set the setMainerCanisterType
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - calling createdControllerCanister.setMainerCanisterType(mainerAgentCanisterType)");
                let statusCodeRecordResult = await controllerCanisterActor.setMainerCanisterType(mainerAgentCanisterType);
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - setControllerGameStateResult " # debug_show (setControllerGameStateResult));
                switch (statusCodeRecordResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                var status : Types.CanisterStatus = #ControllerCreated;
                if (mainerAgentCanisterType == #ShareAgent) {
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - calling startTimerExecutionAdmin for #ShareAgent type controller");
                    let authRecordResult = await controllerCanisterActor.startTimerExecutionAdmin();
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - authRecordResult returned by startTimerExecutionAdmin " # debug_show (authRecordResult));
                    switch (authRecordResult) {
                        case (#Err(error)) {
                            return #Err(error);
                        };
                        case _ {
                            // all good, continue
                        };
                    };
                    status := #Running;
                };
                let mainerAgentCanisterInput : Types.OfficialMainerAgentCanister = {
                    address : Text = setupCanisterInput.newCanisterId;
                    subnet : Text = setupCanisterInput.subnet;
                    canisterType = configurationInput.canisterType;
                    creationTimestamp : Nat64 = configurationInput.userMainerEntryCreationTimestamp;
                    createdBy : Principal = msg.caller;
                    ownedBy = configurationInput.owner;
                    status = status;
                    mainerConfig = configurationInput.mainerConfig;
                };

                // Link up the ShareAgent & ShareService canisters 
                if (mainerAgentCanisterType == #ShareAgent) {
                    // Set the Share Service canister id for the Share Agent canister
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - calling controllerCanisterActor.setShareServiceCanisterId(shareServiceCanisterAddress)");
                    let statusCodeRecordResult = await controllerCanisterActor.setShareServiceCanisterId(shareServiceCanisterAddress);
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - statusCodeRecordResult " # debug_show (statusCodeRecordResult));
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
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - calling shareServiceCanisterActor.addMainerShareAgentCanister with mainerAgentCanisterInput = " # debug_show (mainerAgentCanisterInput));
                    let mainerAgentCanisterResult = await shareServiceCanisterActor.addMainerShareAgentCanister(mainerAgentCanisterInput);
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - mainerAgentCanisterResult " # debug_show (mainerAgentCanisterResult));
                    switch (mainerAgentCanisterResult) {
                        case (#Err(error)) {
                            return #Err(error);
                        };
                        case _ {
                            // all good, continue
                        };
                    };
                };

                // ---------------------------------------------------------
                try {
                    let canisterStatus = await IC0.canister_status({canister_id = newCanisterIdPrincipal ;});
                    cyclesUsed := cyclesBalance - canisterStatus.cycles;
                    cyclesBalance := canisterStatus.cycles;
                } catch (e) {
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - Failed to retrieve info for createdControllerCanister: " # debug_show(newCanisterIdPrincipal )  # Error.message(e) );
                    return #Err(#Other("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - Failed to retrieve info for createdControllerCanister: " # debug_show(newCanisterIdPrincipal ) # Error.message(e)));
                };
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - configuration of createdControllerCanister = " # debug_show (newCanisterIdPrincipal ) # 
                " - cyclesUsed = " # debug_show (cyclesUsed) # 
                " - cyclesBalance = " # debug_show (cyclesBalance));

                // --------------------------------------------------------------------
                // Update the controller canister status with the Game State canister
                let gameStateCanisterActor = actor (MASTER_CANISTER_ID) : Types.GameStateCanister_Actor;
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - calling gameStateCanisterActor.addMainerAgentCanister with mainerAgentCanisterInput = " # debug_show (mainerAgentCanisterInput));
                let addMainerAgentCanisterResult = await gameStateCanisterActor.addMainerAgentCanister(mainerAgentCanisterInput);
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - addMainerAgentCanisterResult" # debug_show (addMainerAgentCanisterResult));
                switch (addMainerAgentCanisterResult) {
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
                    newCanisterId   = setupCanisterInput.newCanisterId;
                    subnet : Text = setupCanisterInput.subnet;
                };
                return #Ok(creationRecord);
            };
            case (#MainerLlm) {
                D.print("mAInerCreator (#MainerLlm): setupCanister");
                // Sanity check
                switch (configurationInput.associatedCanisterAddress) {
                    case (null) {
                        return #Err(#Other("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - Please provide the canister address of the associated mAIner controller canister"));
                    };
                    case (?associatedCanisterAddress) {
                        try {
                            // Make sure the associated canister actually exists                           
                            let _ = Principal.fromText(associatedCanisterAddress); // this will throw an error if it's not a valid canister address
                            let associatedControllerCanisterActor = actor (associatedCanisterAddress) : Types.MainerAgentCtrlbCanister;
                            let healthResult = await associatedControllerCanisterActor.health();
                            D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - healthResult" # debug_show (healthResult));
                            switch (healthResult) {
                                case (#Err(error)) {
                                    return #Err(error);
                                };
                                case _ {
                                    // all good, continue
                                };
                            };
                        } catch (e) {
                            D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") -  failed to validate existence & health of associatedCanisterAddress: " # debug_show(associatedCanisterAddress ) # " Error: " # Error.message(e) );
                            return #Err(#Other("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") -  failed to validate existence & health of associatedCanisterAddress: " # debug_show(associatedCanisterAddress )  # " Error: "  # Error.message(e)));
                        };

                        let associatedControllerCanisterActor = actor (associatedCanisterAddress) : Types.MainerAgentCtrlbCanister;
                        var selectedModel = #Qwen2_5_500M;
                        switch (configurationInput.mainerConfig.selectedLLM) {
                            case (null) {
                                // use default
                                selectedModel := #Qwen2_5_500M; // TODO - Implementation: retrieve default via function
                            };
                            case (?selectedLLM) {
                                selectedModel := selectedLLM;                                
                            };
                        };
                        switch (getModelCreationArtefacts(selectedModel)) {
                            case (null) {
                                return #Err(#Other("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - Cannot find creation artefacts for the selected model"));
                            };
                            case (?modelCreationArtefacts) {
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - modelCreationArtefacts");
                                
                                var cyclesBalance : Nat = 0;
                                try {
                                    let canisterStatus = await IC0.canister_status({canister_id = newCanisterIdPrincipal ;});
                                    cyclesBalance := canisterStatus.cycles;
                                } catch (e) {
                                    D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - Failed to retrieve info for LLM canister: " # debug_show(newCanisterIdPrincipal )  # Error.message(e) );
                                    return #Err(#Other("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - Failed to retrieve info for LLM canister: " # debug_show(newCanisterIdPrincipal ) # Error.message(e)));
                                };

                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - (cyclesBalance = " # debug_show (cyclesBalance) # ")");

                                // ---------------------------------------------------------
                                // Update the Controller Agent canister status with the Game State canister
                                var mainerAgentCanisterInput : Types.OfficialMainerAgentCanister = {
                                    address = associatedCanisterAddress;
                                    subnet = configurationInput.associatedCanisterSubnet;
                                    canisterType = configurationInput.userMainerEntryCanisterType;
                                    creationTimestamp : Nat64 = configurationInput.userMainerEntryCreationTimestamp;
                                    createdBy : Principal = msg.caller;
                                    ownedBy = configurationInput.owner;
                                    status = #LlmSetupInProgress(#CodeInstallInProgress); // Only field updated
                                    mainerConfig = configurationInput.mainerConfig;
                                };
                                let gameStateCanisterActor = actor (MASTER_CANISTER_ID) : Types.GameStateCanister_Actor;
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - calling gameStateCanisterActor.addMainerAgentCanister with mainerAgentCanisterInput = " # debug_show (mainerAgentCanisterInput));
                                var addMainerAgentCanisterResult = await gameStateCanisterActor.addMainerAgentCanister(mainerAgentCanisterInput);
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - addMainerAgentCanisterResult" # debug_show (addMainerAgentCanisterResult));
                                switch (addMainerAgentCanisterResult) {
                                    case (#Err(error)) {
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };

                                // --------------------------------------------------
                                // install code
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - start installing code into llm canister " # debug_show (newCanisterIdPrincipal));
                                let installResult = await InstallCanisterCode.installCanisterCode(newCanisterIdPrincipal, modelCreationArtefacts.canisterWasm, #install);
                                switch (installResult) {
                                    case (#Ok(_)) {
                                        D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - Successfully installed code into llm canister " # debug_show (newCanisterIdPrincipal));
                                    };
                                    case (#Err(errorMessage)) {
                                        D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - Failed installing code into llm canister " # debug_show (newCanisterIdPrincipal) # " Error: " # errorMessage);
                                        return #Err(#Other("mAInerCreator (#MainerLlm): setupCanister - Failed installing code into llm canister: " # debug_show(newCanisterIdPrincipal) # " Error: " # errorMessage));
                                    };
                                };

                                var cyclesUsed : Nat = 0;
                                try {
                                    let canisterStatus = await IC0.canister_status({canister_id = newCanisterIdPrincipal ;});
                                    cyclesUsed := cyclesBalance - canisterStatus.cycles;
                                    cyclesBalance := canisterStatus.cycles;
                                } catch (e) {
                                    D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - Failed to retrieve info for createdLlmCanister: " # debug_show(newCanisterIdPrincipal )  # Error.message(e) );
                                    return #Err(#Other("mAInerCreator: setupCanister (" # newCanisterId # ") - Failed to retrieve info for createdLlmCanister: " # debug_show(newCanisterIdPrincipal ) # Error.message(e)));
                                };
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - install_code for createdLlmCanister = " # debug_show (newCanisterIdPrincipal ) # 
                                " - cyclesUsed = " # debug_show (cyclesUsed) # 
                                " - cyclesBalance = " # debug_show (cyclesBalance));
                            
                                // --------------------------------------------------
                                // Verify new canister is working
                                let llmCanisterActor = actor (Principal.toText(newCanisterIdPrincipal )) : Types.LLMCanister;
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - llmCanisterActor");
                                let readyLlmResult = await llmCanisterActor.health();
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - setupCanister readyLlmResult = " # debug_show (readyLlmResult));
                                switch (readyLlmResult) {
                                    case (#Err(error)) {
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };

                                // ------------------------------------------
                                // Make LLM functional
                                // Upload model file
                                // let chunkSize = 42000; // ~0.01 MB for testing TODO - Testing
                                //var chunkSize : Nat = 9 * 1024 * 1024; // 9 MB
                                var chunkSize : Nat = 0;
                                var offset : Nat = 0;
                                var nextChunk : [Nat8] = [];

                                // For progress reporting
                                var modelUploadProgress : Nat8 = 0;
                                let modelUploadProgressInterval : Nat = 10; // 10% progress interval

                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - start upload of LLM model");
                                var chunkCount : Nat = 0;
                                let totalChunks : Nat = modelCreationArtefacts.modelFile.size();
                                var nextProgressThreshold : Nat = 0;

                                var uploadModelFileResult : Types.FileUploadRecordResult = #Ok({ filename = "models/model.gguf"; filesha256 = ""; filesize = 0 }); // Placeholder
                                for (chunk in modelCreationArtefacts.modelFile.vals()) {
                                    var progress : Nat = (chunkCount * 100) / totalChunks; // Integer division rounds down
                                    if (chunkCount + 1 == totalChunks) {
                                        progress := 100; // Set to 100% for the last chunk
                                    };
                                    if (progress >= nextProgressThreshold) {
                                        modelUploadProgress := Nat8.fromNat(nextProgressThreshold); // Set to 0, 10, 20, ..., 100
                                        D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - uploading file chunk " # debug_show (chunkCount) # "(modelUploadProgress = " # debug_show (modelUploadProgress) # "%)");

                                        // ---------------------------------------------------------
                                        // Update the Controller Agent canister status with the Game State canister
                                        mainerAgentCanisterInput := {
                                            address = associatedCanisterAddress;
                                            subnet = configurationInput.associatedCanisterSubnet;
                                            canisterType = configurationInput.userMainerEntryCanisterType;
                                            creationTimestamp : Nat64 = configurationInput.userMainerEntryCreationTimestamp;
                                            createdBy : Principal = msg.caller;
                                            ownedBy = configurationInput.owner;
                                            status = #LlmSetupInProgress(#ModelUploadProgress(modelUploadProgress)); // Only field updated
                                            mainerConfig = configurationInput.mainerConfig;
                                        };
                                        D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - calling gameStateCanisterActor.addMainerAgentCanister with mainerAgentCanisterInput = " # debug_show (mainerAgentCanisterInput));
                                        addMainerAgentCanisterResult := await gameStateCanisterActor.addMainerAgentCanister(mainerAgentCanisterInput);
                                        D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - addMainerAgentCanisterResult" # debug_show (addMainerAgentCanisterResult));
                                        switch (addMainerAgentCanisterResult) {
                                            case (#Err(error)) {
                                                return #Err(error);
                                            };
                                            case _ {
                                                // all good, continue
                                            };
                                        };

                                        nextProgressThreshold += modelUploadProgressInterval;
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

                                    var delay : Nat = 2_000_000_000; // 2 seconds
                                    let maxAttempts : Nat = 8;
                                    uploadModelFileResult := await retryLlmChunkUploadWithDelay(llmCanisterActor, uploadChunk, maxAttempts, delay);
                                    switch (uploadModelFileResult) {
                                        case (#Err(error)) {
                                            D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - ERROR - uploadModelFileResult:");
                                            D.print(debug_show (uploadModelFileResult));
                                            return #Err(error);
                                        };
                                        case (#Ok(_)) {
                                            // all good, continue with next chunk
                                            D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - uploadModelFileResult = " # debug_show (uploadModelFileResult));
                                            offset := offset + chunkSize;
                                        };
                                    };
                                };

                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - after upload -- checking filesha256.");
                                // This is how uploadModelFileResult looks like for Qwen2.5-05B-instruct model:
                                // #Ok({filename = "models/model.gguf"; filesha256 = "ca59ca7f13d0e15a8cfa77bd17e65d24f6844b554a7b6c12e07a5f89ff76844e"; filesize = 675_710_816})
                                switch (uploadModelFileResult) {
                                    case (#Err(error)) {
                                        D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - ERROR - uploadModelFileResult:");
                                        D.print(debug_show (uploadModelFileResult));
                                        return #Err(error);
                                    };
                                    case (#Ok(uploadModelFileRecord)) {
                                        D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - uploadModelFileRecord");
                                        D.print(debug_show (uploadModelFileRecord));
                                        // Check the sha256
                                        let filesha256 : Text = uploadModelFileRecord.filesha256;
                                        let expectedSha256 : Text = modelCreationArtefacts.modelFileSha256;
                                        
                                        if (not (filesha256 == expectedSha256)) {
                                            D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - ERROR: filesha256 = " # debug_show (filesha256) # "does not match expectedSha256 = " # debug_show (expectedSha256));
                                            return #Err(#Other("The sha256 of the uploaded llm file is " # filesha256 # ", which does not match the expected value of " # expectedSha256));
                                        } else {
                                            D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - filesha256 matches expectedSha256 = " # debug_show (expectedSha256));
                                        };
                                    };
                                };

                                // ---------------------------------------------------------
                                // Update the Controller Agent canister status with the Game State canister
                                mainerAgentCanisterInput := {
                                    address = associatedCanisterAddress;
                                    subnet = configurationInput.associatedCanisterSubnet;
                                    canisterType = configurationInput.userMainerEntryCanisterType;
                                    creationTimestamp : Nat64 = configurationInput.userMainerEntryCreationTimestamp;
                                    createdBy : Principal = msg.caller;
                                    ownedBy = configurationInput.owner;
                                    status = #LlmSetupInProgress(#ConfigurationInProgress); // Only field updated
                                    mainerConfig = configurationInput.mainerConfig;
                                };
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - calling gameStateCanisterActor.addMainerAgentCanister with mainerAgentCanisterInput = " # debug_show (mainerAgentCanisterInput));
                                addMainerAgentCanisterResult := await gameStateCanisterActor.addMainerAgentCanister(mainerAgentCanisterInput);
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - addMainerAgentCanisterResult" # debug_show (addMainerAgentCanisterResult));
                                switch (addMainerAgentCanisterResult) {
                                    case (#Err(error)) {
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };

                                // load model file in LLM
                                let inputRecord : Types.InputRecord = {
                                    args : [Text] = ["--model", "models/model.gguf"];
                                };
                                let loadModelResult = await llmCanisterActor.load_model(inputRecord);
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - loadModelResult");
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
                                // TODO - Implementation: This is for the Qwen 2.5-0.5B model, need to make it dynamic
                                let MAX_TOKENS : Nat64 = 13;
                                let maxTokensRecord : Types.MaxTokensRecord = {
                                    max_tokens_update : Nat64 = MAX_TOKENS;
                                    max_tokens_query : Nat64 = MAX_TOKENS;
                                };
                                let setMaxTokensResult = await llmCanisterActor.set_max_tokens(maxTokensRecord);
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - setMaxTokensResult" # debug_show (setMaxTokensResult));
                                switch (setMaxTokensResult) {
                                    case (#Err(error)) {
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };    

                                // connect LLM and controller canisters
                                try {
                                    // Register LLM with controller
                                    let associatedControllerCanisterActor = actor (associatedCanisterAddress) : Types.MainerAgentCtrlbCanister;
                                    D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - associatedControllerCanisterActor");
                                    let addLlmToControllerResult = await associatedControllerCanisterActor.add_llm_canister({ canister_id = Principal.toText(newCanisterIdPrincipal ); });
                                    D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - addLlmToControllerResult" # debug_show (addLlmToControllerResult));
                                    switch (addLlmToControllerResult) {
                                        case (#Err(error)) {
                                            return #Err(error);
                                        };
                                        case _ {
                                            // all good, continue
                                        };
                                    };
                                } catch (e) {
                                    D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - Failed to register LLM with it's controller, with associatedCanisterAddress: " # debug_show(associatedCanisterAddress )  # Error.message(e) );
                                    return #Err(#Other("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - Failed to register LLM with it's controller, with associatedCanisterAddress: " # debug_show(associatedCanisterAddress ) # Error.message(e)));
                                };
                                
                                // TODO - Testing: Don't call this, so all the LLMs will be used by default in a round robbin fashion
                                // let roundRobinSetting : Nat = 1;
                                // let setControllerRoundRobinResult = await associatedControllerCanisterActor.setRoundRobinLLMs(roundRobinSetting);
                                // D.print("mAInerCreator (#MainerLlm): setupCanister setControllerRoundRobinResult" # debug_show (setControllerRoundRobinResult));
                                // switch (setControllerRoundRobinResult) {
                                //     case (#Err(error)) {
                                //         return #Err(error);
                                //     };
                                //     case _ {
                                //         // all good, continue
                                //     };
                                // };

                                // Pause the logging of the LLM to avoid excessive debug prints
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - calling LLMs log_pause");
                                let logPauseResult = await llmCanisterActor.log_pause();
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - logPauseResult = "# debug_show (logPauseResult));
                                switch (logPauseResult) {
                                    case (#Err(error)) {
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };

                                // Start the timer for the controlling mAIner agent canister
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - calling startTimerExecutionAdmin for the controller");
                                let authRecordResult = await associatedControllerCanisterActor.startTimerExecutionAdmin();
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - authRecordResult returned by startTimerExecutionAdmin " # debug_show (authRecordResult));
                                switch (authRecordResult) {
                                    case (#Err(error)) {
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };


                                // ---------------------------------------------------------
                                try {
                                    let canisterStatus = await IC0.canister_status({canister_id = newCanisterIdPrincipal ;});
                                    cyclesUsed := cyclesBalance - canisterStatus.cycles;
                                    cyclesBalance := canisterStatus.cycles;
                                } catch (e) {
                                    D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - Failed to retrieve info for createdLlmCanister: " # debug_show(newCanisterIdPrincipal )  # Error.message(e) );
                                    return #Err(#Other("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - Failed to retrieve info for createdLlmCanister: " # debug_show(newCanisterIdPrincipal ) # Error.message(e)));
                                };
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - configuration of createdLlmCanister = " # debug_show (newCanisterIdPrincipal ) # 
                                " - cyclesUsed = " # debug_show (cyclesUsed) # 
                                " - cyclesBalance = " # debug_show (cyclesBalance));

                                // ---------------------------------------------------------
                                // Update the Controller Agent canister status with the Game State canister
                                mainerAgentCanisterInput := {
                                    address = associatedCanisterAddress;
                                    subnet = configurationInput.associatedCanisterSubnet;
                                    canisterType = configurationInput.userMainerEntryCanisterType;
                                    creationTimestamp : Nat64 = configurationInput.userMainerEntryCreationTimestamp;
                                    createdBy : Principal = msg.caller;
                                    ownedBy = configurationInput.owner;
                                    status = #Running;   // We started the timer of the controller mAIner Agent, so we are running
                                    mainerConfig = configurationInput.mainerConfig;
                                };
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - calling gameStateCanisterActor.addMainerAgentCanister with mainerAgentCanisterInput = " # debug_show (mainerAgentCanisterInput));
                                addMainerAgentCanisterResult := await gameStateCanisterActor.addMainerAgentCanister(mainerAgentCanisterInput);
                                D.print("mmAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - addMainerAgentCanisterResult" # debug_show (addMainerAgentCanisterResult));
                                switch (addMainerAgentCanisterResult) {
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
                                    newCanisterId   = setupCanisterInput.newCanisterId;
                                    subnet : Text = setupCanisterInput.subnet;
                                };
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - creationRecord");
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
    // TODO: remove these helper Admin functions
    public shared (msg) func getDefaultSubnetsAdmin() : async {
        #Ok : [Principal];
        #Err : {#Unauthorized};
    } {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let subnets = await CreateCanisterWithCMC.getDefaultSubnets();
        return #Ok(subnets);
    };
    public shared (msg) func isSubnetAvailableAdmin(subnet: Text) : async {
            #Ok : Bool;
            #Err : {#Unauthorized};
        } {
            if (not Principal.isController(msg.caller)) {
                return #Err(#Unauthorized);
            };
            let result = await CreateCanisterWithCMC.isSubnetAvailable(subnet);
            return #Ok(result);
    };
    // TODO - REMOVE
    // // public shared (msg) func testCreateMainerControllerCanister(mainerAgentCanisterType : Types.MainerAgentCanisterType, shareServiceCanisterAddress : ?Types.CanisterAddress) : async Types.CanisterCreationResult {
    // public shared (msg) func testCreateMainerControllerCanister(testCreateMainerControllerCanister : Types.TestCreateMainerControllerCanister) : async Types.CanisterCreationResult {
    //     D.print("mAInerCreator: entered testCreateMainerControllerCanister");
    //     if (Principal.isAnonymous(msg.caller)) {
    //         return #Err(#Unauthorized);
    //     };
    //     if (not Principal.isController(msg.caller)) {
    //         return #Err(#Unauthorized);
    //     };
    //     let mainerAgentCanisterType : Types.MainerAgentCanisterType = testCreateMainerControllerCanister.mainerAgentCanisterType;
    //     let shareServiceCanisterAddress : ?Types.CanisterAddress = testCreateMainerControllerCanister.shareServiceCanisterAddress;

    //     let mainerConfig : Types.MainerConfigurationInput = {
    //         mainerAgentCanisterType: Types.MainerAgentCanisterType = mainerAgentCanisterType;
    //         selectedLLM : ?Types.SelectableMainerLLMs = ?#Qwen2_5_500M;
    //     };
    //     let config : Types.CanisterCreationConfiguration = {
    //         canisterType : Types.ProtocolCanisterType = #MainerAgent(mainerAgentCanisterType);
    //         associatedCanisterAddress : ?Types.CanisterAddress = shareServiceCanisterAddress;
    //         owner : Principal = msg.caller; 
    //         mainerConfig : Types.MainerConfigurationInput = mainerConfig;
    //         userMainerEntryCreationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
    //         userMainerEntryCanisterType : Types.ProtocolCanisterType = #MainerAgent(mainerAgentCanisterType);
    //     };
    //     D.print("mAInerCreator: testCreateMainerControllerCanister - calling createCanister with config" # debug_show(config));
    //     let result = await createCanister(config);
    //     return result;
    // };

    // // TODO - REMOVE
    // public shared (msg) func testCreateMainerLlmCanister(controllerCanisterAddress : Text) : async Types.CanisterCreationResult {
    //     if (Principal.isAnonymous(msg.caller)) {
    //         return #Err(#Unauthorized);
    //     };
    //     if (not Principal.isController(msg.caller)) {
    //         return #Err(#Unauthorized);
    //     };

    //     // Sanity checks for controllerCanisterAddress
    //     try {
    //         // Check if the controller canister address exists and is functioning
    //         let controllerActor = actor (controllerCanisterAddress) : Types.MainerAgentCtrlbCanister;
    //         let healthResult = await controllerActor.health();
            
    //         switch (healthResult) {
    //         case (#Err(_)) {
    //             return #Err(#Other("Controller canister " # controllerCanisterAddress # " is not healthy"));
    //         };
    //         case (#Ok(_)) {
    //             // Controller is healthy, now check its type
    //             let canisterTypeResult = await controllerActor.getMainerCanisterType();
                
    //             switch (canisterTypeResult) {
    //             case (#Err(_)) {
    //                 return #Err(#Other("Failed to get controller canister type"));
    //             };
    //             case (#Ok(canisterType)) {
    //                 // Verify this is an allowed controller type
    //                 switch (canisterType) {
    //                 case (#Own) {
    //                     // This is allowed
    //                 };
    //                 case (#ShareService) {
    //                     // This is allowed
    //                 };
    //                 case (#ShareAgent) {
    //                     return #Err(#Other("ShareAgent type canister is not allowed to control an LLM canister"));
    //                 };
    //                 case _ {
    //                     return #Err(#Other("Invalid controller canister type " # debug_show(canisterType)));
    //                 };
    //                 };
    //             };
    //             };
    //         };
    //         };
    //     } catch (_) {
    //         D.print("mAInerCreator: testCreateMainerLlmCanister - Error accessing controller canister: ");
    //         return #Err(#Other("Controller canister does not exist or is not accessible"));
    //     };
    //     let mainerConfig : Types.MainerConfigurationInput = {
    //         mainerAgentCanisterType: Types.MainerAgentCanisterType = #Own;
    //         selectedLLM : ?Types.SelectableMainerLLMs = ?#Qwen2_5_500M;
    //     };

    //     let config : Types.CanisterCreationConfiguration = {
    //         canisterType : Types.ProtocolCanisterType = #MainerLlm;
    //         associatedCanisterAddress : ?Types.CanisterAddress = ?controllerCanisterAddress;
    //         owner : Principal = msg.caller;
    //         mainerConfig : Types.MainerConfigurationInput = mainerConfig;
    //         userMainerEntryCreationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
    //         userMainerEntryCanisterType : Types.ProtocolCanisterType = #MainerLlm;
    //     };
    //     let result = await createCanister(config);
    //     return result;
    // };

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