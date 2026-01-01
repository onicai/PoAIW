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
import Hex "mo:hex/Hex";
import List "mo:base/List";
import Int "mo:base/Int";
import Time "mo:base/Time";

import Types "../../common/Types";
import ICManagementCanister "../../common/ICManagementCanister";
import CreateCanisterWithCMC "../../common/CreateCanisterWithCMC";
import InstallCanisterCode "../../common/InstallCanisterCode";
import Constants "../../common/Constants";

persistent actor class MainerCreatorCanister() = this {

    var MASTER_CANISTER_ID : Text = "r5m5y-diaaa-aaaaa-qanaa-cai"; // prd

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

    public query (msg) func getMasterCanisterIdAdmin() : async Text {
        if (Principal.isAnonymous(msg.caller)) {
            return "Unauthorized";
        };
        if (not Principal.isController(msg.caller)) {
            return "Unauthorized";
        };
        return MASTER_CANISTER_ID;
    };

    private transient let IC0 : ICManagementCanister.IC_Management = actor ("aaaaa-aa");

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

    // Move cycles to Game State canister
    var cyclesTransactionsStorage : List.List<Types.CyclesTransaction> = List.nil<Types.CyclesTransaction>();

    public query (msg) func getCyclesTransactionsAdmin() : async Types.CyclesTransactionsResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        return #Ok(List.toArray(cyclesTransactionsStorage));
    };
    
    var MIN_CYCLES_BALANCE : Nat = 30 * Constants.CYCLES_TRILLION;
    var CYCLES_AMOUNT_TO_GAME_STATE_CANISTER : Nat = 10 * Constants.CYCLES_TRILLION;

    public shared (msg) func sendCyclesToGameStateCanister() : async Types.AddCyclesResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let currentCyclesBalance : Nat = Cycles.balance();
        try {
            // Only move cycles if cycles balance is big enough
            if (currentCyclesBalance - CYCLES_AMOUNT_TO_GAME_STATE_CANISTER < MIN_CYCLES_BALANCE) {
                D.print("mAInerCreator: sendCyclesToGameStateCanister - requested cycles transaction but balance is not big enough: " # debug_show(currentCyclesBalance) # debug_show(msg));
                return #Err(#Unauthorized);
            };

            let gameStateCanisterActor = actor (MASTER_CANISTER_ID) : Types.GameStateCanister_Actor;
            D.print("mAInerCreator: sendCyclesToGameStateCanister gameStateCanisterActor = " # Principal.toText(Principal.fromActor(gameStateCanisterActor)));
            D.print("mAInerCreator: sendCyclesToGameStateCanister - CYCLES_AMOUNT_TO_GAME_STATE_CANISTER: " # debug_show(CYCLES_AMOUNT_TO_GAME_STATE_CANISTER));
            Cycles.add<system>(CYCLES_AMOUNT_TO_GAME_STATE_CANISTER);
            
            D.print("mAInerCreator: sendCyclesToGameStateCanister - calling gameStateCanisterActor.addCycles");
            let addCyclesResponse = await gameStateCanisterActor.addCycles();
            D.print("mAInerCreator: sendCyclesToGameStateCanister - addCyclesResponse: " # debug_show(addCyclesResponse));
            switch (addCyclesResponse) {
                case (#Err(error)) {
                    D.print("mAInerCreator: sendCyclesToGameStateCanister - addCyclesResponse FailedOperation: " # debug_show(error));
                    // Store the failed attempt
                    let transactionEntry : Types.CyclesTransaction = {
                        amountAdded : Nat = CYCLES_AMOUNT_TO_GAME_STATE_CANISTER;
                        newOfficialCycleBalance : Nat = Cycles.balance();
                        creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                        sentBy : Principal = msg.caller;
                        succeeded : Bool = false;
                        previousCyclesBalance : Nat = currentCyclesBalance;
                    };
                    cyclesTransactionsStorage := List.push<Types.CyclesTransaction>(transactionEntry, cyclesTransactionsStorage);
                    return #Err(#FailedOperation);
                };
                case (#Ok(addCyclesResult)) {
                    D.print("mAInerCreator: sendCyclesToGameStateCanister - addCyclesResult: " # debug_show(addCyclesResult));
                    // Store the transaction
                    let transactionEntry : Types.CyclesTransaction = {
                        amountAdded : Nat = CYCLES_AMOUNT_TO_GAME_STATE_CANISTER;
                        newOfficialCycleBalance : Nat = Cycles.balance();
                        creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                        sentBy : Principal = msg.caller;
                        succeeded : Bool = true;
                        previousCyclesBalance : Nat = currentCyclesBalance;
                    };
                    cyclesTransactionsStorage := List.push<Types.CyclesTransaction>(transactionEntry, cyclesTransactionsStorage);
                    return addCyclesResponse;
                };
            };
        } catch (e) {
            D.print("mAInerCreator: sendCyclesToGameStateCanister - Failed to send cycles to Game State: " # Error.message(e));      
            // Store the failed attempt
            let transactionEntry : Types.CyclesTransaction = {
                amountAdded : Nat = CYCLES_AMOUNT_TO_GAME_STATE_CANISTER;
                newOfficialCycleBalance : Nat = Cycles.balance();
                creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
                sentBy : Principal = msg.caller;
                succeeded : Bool = false;
                previousCyclesBalance : Nat = currentCyclesBalance;
            };
            cyclesTransactionsStorage := List.push<Types.CyclesTransaction>(transactionEntry, cyclesTransactionsStorage);
            return #Err(#Other("mAInerCreator: sendCyclesToGameStateCanister - Failed to send cycles to Game State: " # Error.message(e)));
        };
    };

    public shared (msg) func setMinCyclesBalanceAdmin(newCyclesBalance : Nat) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (newCyclesBalance < 20 * Constants.CYCLES_TRILLION) {
            return #Err(#Unauthorized);
        };
        MIN_CYCLES_BALANCE := newCyclesBalance;
        return #Ok({ status_code = 200 });
    };

    public query (msg) func getMinCyclesBalanceAdmin() : async Nat {
        if (Principal.isAnonymous(msg.caller)) {
            return 0;
        };
        if (not Principal.isController(msg.caller)) {
            return 0;
        };

        return MIN_CYCLES_BALANCE;
    };

    public shared (msg) func setCyclesToSendToGameStateAdmin(newValue : Nat) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (newValue > 100 * Constants.CYCLES_TRILLION) {
            return #Err(#Unauthorized);
        };
        CYCLES_AMOUNT_TO_GAME_STATE_CANISTER := newValue;
        return #Ok({ status_code = 200 });
    };

    public query (msg) func getCyclesToSendToGameStateAdmin() : async Nat {
        if (Principal.isAnonymous(msg.caller)) {
            return 0;
        };
        if (not Principal.isController(msg.caller)) {
            return 0;
        };

        return CYCLES_AMOUNT_TO_GAME_STATE_CANISTER;
    };

    // -------------------------------------------------------------------------------
    // Wasm Hash Management

    // Helper function to calculate SHA-256 hash of wasm blobs
    private func calculateWasmSha256(wasmBlobs : [Blob]) : Text {
        if (wasmBlobs.size() == 0) {
            return "";
        };

        // Concatenate all blobs and calculate hash
        var allBytes : [Nat8] = [];
        for (blob in wasmBlobs.vals()) {
            allBytes := Array.append(allBytes, Blob.toArray(blob));
        };

        let hashBlob = Sha256.fromArray(#sha256, allBytes);
        let hexHash = Hex.encode(Blob.toArray(hashBlob));
        return Text.toLowercase(hexHash);
    };

    // Get mainer controller wasm hash, calculating and caching if needed
    private func getMainerControllerWasmSha256() : Text {
        if (mainerControllerCanisterWasmSha256 == "" and mainerControllerCanisterWasm.size() > 0) {
            mainerControllerCanisterWasmSha256 := calculateWasmSha256(mainerControllerCanisterWasm);
        };
        return mainerControllerCanisterWasmSha256;
    };

    // Get LLM canister wasm hash for a model (returns cached value only)
    private func getLlmCanisterWasmSha256(modelName : Text) : Text {
        switch (llmCanisterWasmSha256ByModel.get(modelName)) {
            case (?cachedHash) { return cachedHash; };
            case null { return ""; };
        };
    };

    // Admin function to get SHA-256 hashes of all uploaded wasm files
    public query (msg) func getSha256HashesAdmin() : async Types.Sha256HashesResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Get mainer controller wasm hash
        let controllerHash = getMainerControllerWasmSha256();

        // Log warning if controller wasm hash is empty but wasm data exists
        if (controllerHash == "" and mainerControllerCanisterWasm.size() > 0) {
            D.print("mAInerCreator: getSha256HashesAdmin - WARNING: mainerControllerWasmSha256 is empty but wasm data exists. Call finish_upload_mainer_controller_canister_wasm() to calculate the hash.");
        };

        // Get hashes for all LLM models
        var llmHashes : [(Text, { wasmSha256 : Text; modelFileSha256 : Text })] = [];
        for ((modelName, artefacts) in creationArtefactsByModel.entries()) {
            // Get wasm hash (returns cached value only)
            let wasmHash = getLlmCanisterWasmSha256(modelName);

            // Log warning if LLM wasm hash is empty but wasm data exists
            if (wasmHash == "" and artefacts.canisterWasm.size() > 0) {
                D.print("mAInerCreator: getSha256HashesAdmin - WARNING: wasmSha256 for model '" # modelName # "' is empty but wasm data exists. Call finish_upload_mainer_llm_canister_wasm() to calculate the hash.");
            };

            let modelInfo = {
                wasmSha256 = wasmHash;
                modelFileSha256 = artefacts.modelFileSha256;
            };
            llmHashes := Array.append(llmHashes, [(modelName, modelInfo)]);
        };

        return #Ok({
            mainerControllerWasmSha256 = controllerHash;
            llmWasmHashes = llmHashes;
        });
    };

    // -------------------------------------------------------------------------------
    // Wasm Upload Functions

    // Admin function to upload mainer agent controller canister wasm
    private var mainerControllerCanisterWasm : [Blob] = [];
    private var mainerControllerCanisterWasmSha256 : Text = "";

    public shared (msg) func start_upload_mainer_controller_canister_wasm() : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        mainerControllerCanisterWasm := [];
        mainerControllerCanisterWasmSha256 := ""; // Reset hash for new upload
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

    // Finish mainer controller wasm upload and calculate SHA-256 hash
    public shared (msg) func finish_upload_mainer_controller_canister_wasm() : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        if (mainerControllerCanisterWasm.size() > 0) {
            mainerControllerCanisterWasmSha256 := calculateWasmSha256(mainerControllerCanisterWasm);
            D.print("mAInerCreator: finish_upload_mainer_controller_canister_wasm - hash = " # mainerControllerCanisterWasmSha256);
            return #Ok({ status_code = 200 });
        } else {
            return #Err(#Other("No wasm data found"));
        };
    };

    // Admin function to upload artefacts for mainer agent LLM canister
    // Map each AI model id to a record with the artefacts needed to create a new canister
    private transient var creationArtefactsByModel = HashMap.HashMap<Text, Types.ModelCreationArtefacts>(0, Text.equal, Text.hash);
    private var creationArtefactsByModelStable : [(Text, Types.ModelCreationArtefacts)] = [];

    // Separate storage for LLM canister wasm SHA-256 hashes (to avoid modifying ModelCreationArtefacts type)
    private transient var llmCanisterWasmSha256ByModel = HashMap.HashMap<Text, Text>(0, Text.equal, Text.hash);
    private var llmCanisterWasmSha256ByModelStable : [(Text, Text)] = [];

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
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
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

                // Reset hash for new wasm upload
                switch (selectedModel) {
                    case (#Qwen2_5_500M) {
                        llmCanisterWasmSha256ByModel.put("Qwen2_5_500M", "");
                    };
                    case _ {};
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

    // Finish LLM canister wasm upload and calculate SHA-256 hash
    public shared (msg) func finish_upload_mainer_llm_canister_wasm(selectedModel : Types.SelectableMainerLLMs) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };

        // Calculate and cache the wasm hash
        let modelName = switch (selectedModel) {
            case (#Qwen2_5_500M) { "Qwen2_5_500M" };
            case _ { return #Err(#Other("Unknown model type")); };
        };

        switch (creationArtefactsByModel.get(modelName)) {
            case (?artefacts) {
                if (artefacts.canisterWasm.size() > 0) {
                    let calculatedHash = calculateWasmSha256(artefacts.canisterWasm);
                    llmCanisterWasmSha256ByModel.put(modelName, calculatedHash);
                    D.print("mAInerCreator: finish_upload_mainer_llm_canister_wasm - hash = " # calculatedHash);
                    return #Ok({ status_code = 200 });
                } else {
                    return #Err(#Other("No wasm data found for this model"));
                };
            };
            case null {
                return #Err(#Other("Model artefacts not found"));
            };
        };
    };

    // Data structure for the model file
    var nextChunkID : Nat = 0;
    stable let innerInitArray : [Nat8] = Array.freeze<Nat8>(Array.init<Nat8>(1, 1));
    stable let initBlob : Blob = Blob.fromArray(innerInitArray);
    var modelFileChunks : [var Blob] = Array.init<Blob>(1, initBlob);
    stable let MAX_MODEL_FILE_CHUNKS : Nat = 400; // TODO - Design: should this be a parameter or switch to Buffer?

    // Admin function to start upload of the mainer LLM model file
    public shared (msg) func start_upload_mainer_llm() : async Types.StatusCodeRecordResult {
        D.print("mAInerCreator: start_upload_mainer_llm");
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
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
                D.print("mAInerCreator: createCanister - cyclesAcceptedForMainerAgentCtrlbCreation = " # debug_show (cyclesAcceptedForMainerAgentCtrlbCreation) # " from caller " # Principal.toText(msg.caller));
                // if (cyclesAcceptedForMainerAgentCtrlbCreation != cyclesCreateMainerGsMc) {
                //     // Sanity check: At this point, this should never fail
                //     D.print("mAInerCreator: createCanister - should never fail checking cyclesAcceptedForMainerAgentCtrlbCreation");
                //     return #Err(#Unauthorized);                    
                // };

                // CMC based approach, allows to specify the subnet
                let subnetCtrl : Text = configurationInput.mainerConfig.subnetCtrl;
                let cyclesToAttach : Nat = configurationInput.cyclesCreateMainerctrlMcMainerctrl;
                // TODO - Testing: remove our principals
                let controllers : [Principal] = [Principal.fromActor(this), configurationInput.owner, Principal.fromText("3v5vy-2aaaa-aaaai-aapla-cai"), Principal.fromText("fqkhp-waaaa-aaaam-qdmta-cai"), Principal.fromText("cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"), Principal.fromText("fsmbm-odyjn-hkwt2-3be4e-h6bg3-yi3pi-f5eny-2rosh-4u6jm-3rwa5-xae"), Principal.fromText("chfec-vmrjj-vsmhw-uiolc-dpldl-ujifg-k6aph-pwccq-jfwii-nezv4-2ae"), Principal.fromText("opcne-svazk-6dnsy-iejci-fsm7h-miuun-ovpm4-wtsgw-5pgbz-teu3h-eqe")];
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
                                D.print("mAInerCreator: createCanister - cyclesAcceptedForMainerAgentLlmCreation = " # debug_show (cyclesAcceptedForMainerAgentLlmCreation) # " from caller " # Principal.toText(msg.caller));
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
                    // Do not call startTimerExecutionAdmin for ShareAgent canisters yet. It sometimes times out. Make this the last step
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
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - calling controllerCanisterActor.setShareServiceCanisterId (" # shareServiceCanisterAddress # ")");
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

                if (mainerAgentCanisterType == #ShareAgent) {
                    // Do not call startTimerExecutionAdmin for ShareAgent canisters yet. It sometimes times out. Make this the last step
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - calling startTimerExecutionAdmin for #ShareAgent type controller");
                    // Use ignore to avoid time-out issues
                    ignore controllerCanisterActor.startTimerExecutionAdmin();
                    // let authRecordResult = await controllerCanisterActor.startTimerExecutionAdmin();
                    // D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): setupCanister (" # newCanisterId # ") - authRecordResult returned by startTimerExecutionAdmin " # debug_show (authRecordResult));
                    // switch (authRecordResult) {
                    //     case (#Err(error)) {
                    //         return #Err(error);
                    //     };
                    //     case _ {
                    //         // all good, continue
                    //     };
                    // };
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

                                // Start the timer for the controlling mAIner agent canister
                                D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - calling startTimerExecutionAdmin for the controller");
                                // Use ignore to avoid time-out issues
                                ignore associatedControllerCanisterActor.startTimerExecutionAdmin();
                                // let authRecordResult = await associatedControllerCanisterActor.startTimerExecutionAdmin();
                                // D.print("mAInerCreator (#MainerLlm): setupCanister (" # newCanisterId # ") - authRecordResult returned by startTimerExecutionAdmin " # debug_show (authRecordResult));
                                // switch (authRecordResult) {
                                //     case (#Err(error)) {
                                //         return #Err(error);
                                //     };
                                //     case _ {
                                //         // all good, continue
                                //     };
                                // };


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
    
    // Upgrades the code into a mAIner controller canister.
    // This function is designed to be ignored, because there is no reason to await it
    // It will call the GameState canister addMainerAgentCanister when done, to update the status of the controller canister
    public shared (msg) func upgradeMainerctrl(upgradeMainerctrlInput : Types.UpgradeMainerctrlInput) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        
        // Only Controllers and the GameState canister may call this
        if (not (Principal.isController(msg.caller) or Principal.equal(msg.caller, Principal.fromText(MASTER_CANISTER_ID)))) {
            return #Err(#Unauthorized);
        };

        let mainerAgentEntry : Types.OfficialMainerAgentCanister =upgradeMainerctrlInput.mainerAgentEntry; // Canister to upgrade
        let cyclesUpgradeMainerctrlGsMc : Nat = upgradeMainerctrlInput.cyclesUpgradeMainerctrlGsMc;
        let cyclesUpgradeMainerctrlMcMainerctrl : Nat = upgradeMainerctrlInput.cyclesUpgradeMainerctrlMcMainerctrl;

        let canisterAddress : Text = mainerAgentEntry.address;
        let canisterPrincipal : Principal = Principal.fromText(mainerAgentEntry.address);
        
        D.print("mAInerCreator: upgradeMainerctrl - mainerAgentEntry = " # debug_show (mainerAgentEntry));

        switch (mainerAgentEntry.canisterType) {
            case (#MainerAgent(_)) {
                // Upgrade mAIner controller canister               
                let mainerAgentCanisterType = mainerAgentEntry.mainerConfig.mainerAgentCanisterType;
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ")");

                // Accept required cycles for mAIner controller creation
                let cyclesAccepted = Cycles.accept<system>(cyclesUpgradeMainerctrlGsMc);
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - cyclesAccepted = " # debug_show (cyclesAccepted) # " from caller " # Principal.toText(msg.caller));

                // Deposit cycles in the mAIner controller canister for the upgrade
                let cyclesAdded = cyclesUpgradeMainerctrlMcMainerctrl;
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - calling Cycles.add for = " # debug_show(cyclesAdded) # " Cycles");
                Cycles.add<system>(cyclesAdded);
                
                let deposit_cycles_args = { canister_id : Principal = canisterPrincipal; };
                let _ = await IC0.deposit_cycles(deposit_cycles_args);
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - Successfully deposited " # debug_show(cyclesAdded) # " cycles to mAIner canister " # canisterAddress );
                
                // --------------------------------------------------
                // Verify the Shared Service canister. We are upgrading the links to it during a ShareAgent upgrade
                var shareServiceCanisterAddress : Types.CanisterAddress = ""; // TODO - Design: determine if this should be provided or whether Creator stores this info and fills it in here
                if (mainerAgentCanisterType == #ShareAgent) {
                    switch (upgradeMainerctrlInput.associatedCanisterAddress) {
                        case (null) {
                            return #Err(#Other("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - a #ShareAgent canister requires the shareServiceCanisterAddress to be provided in the onfigurationInput.associatedCanisterAddress."));
                        };
                        case (?associatedCanisterAddress) {
                            shareServiceCanisterAddress := associatedCanisterAddress;
                            try {
                                // Make sure the associated canister actually exists
                                let _ = Principal.fromText(associatedCanisterAddress); // this will throw an error if it's not a valid canister address
                                let associatedControllerCanisterActor = actor (associatedCanisterAddress) : Types.MainerAgentCtrlbCanister;
                                let healthResult = await associatedControllerCanisterActor.health();
                                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - healthResult" # debug_show (healthResult));
                                switch (healthResult) {
                                    case (#Err(error)) {                                        
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };
                            } catch (e) {
                                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - failed to validate existence & health of associatedCanisterAddress: " # debug_show(associatedCanisterAddress ) # " Error: " # Error.message(e) );
                                return #Err(#Other("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - failed to validate existence & health of associatedCanisterAddress: " # debug_show(associatedCanisterAddress ) # " Error: " # Error.message(e)));
                            };
                        };
                    };
                };

                // --------------------------------------------------
                // upgrade code
                let mode : ICManagementCanister.canister_install_mode = #upgrade(null); // for enhanced orthogonal persistence
                // let mode : ICManagementCanister.canister_install_mode = #upgrade(?{wasm_memory_persistence = ?#keep; skip_pre_upgrade = ?false}); // for enhanced orthogonal persistence
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - start upgrading ctrlb canister " # canisterAddress);
                let installResult = await InstallCanisterCode.installCanisterCode(canisterPrincipal, mainerControllerCanisterWasm, mode);
                switch (installResult) {
                    case (#Ok(_)) {
                        D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - Successfully installed code into ctrlb canister " # canisterAddress);
                    };
                    case (#Err(errorMessage)) {
                        D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - Failed installing code into ctrlb canister " # canisterAddress # " Error: " # errorMessage);
                        return #Err(#Other("mAInerCreator: upgradeMainerctrl (" # canisterAddress # ") - Failed installing code into ctrlb canister: " # canisterAddress # " Error: " # errorMessage));
                    };
                };
                
                // --------------------------------------------------
                // Verify upgraded canister is working
                let controllerCanisterActor = actor (canisterAddress) : Types.MainerAgentCtrlbCanister;
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - calling createdControllerCanister.health()");
                let readyControllerResult = await controllerCanisterActor.health();
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - readyControllerResult " # debug_show (readyControllerResult));
                switch (readyControllerResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                // --------------------------------------------------
                // We are also updating the GameState & ShareService settings, just in case they were not properly set or they have been upgraded since initial install

                // Set Game State canister address
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - calling createdControllerCanister.setGameStateCanisterId(MASTER_CANISTER_ID)");
                let setControllerGameStateResult = await controllerCanisterActor.setGameStateCanisterId(MASTER_CANISTER_ID);
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - setControllerGameStateResult " # debug_show (setControllerGameStateResult));
                switch (setControllerGameStateResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };
                

                // Set the setMainerCanisterType
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - calling createdControllerCanister.setMainerCanisterType(mainerAgentCanisterType)");
                let statusCodeRecordResult = await controllerCanisterActor.setMainerCanisterType(mainerAgentCanisterType);
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - setControllerGameStateResult " # debug_show (setControllerGameStateResult));
                switch (statusCodeRecordResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                let mainerAgentCanisterInput : Types.OfficialMainerAgentCanister = {
                    address : Text = mainerAgentEntry.address;
                    subnet : Text = mainerAgentEntry.subnet;
                    canisterType = mainerAgentEntry.canisterType;
                    creationTimestamp : Nat64 = mainerAgentEntry.creationTimestamp;
                    createdBy : Principal = mainerAgentEntry.createdBy;
                    ownedBy = mainerAgentEntry.ownedBy;
                    status = #Running;
                    mainerConfig = mainerAgentEntry.mainerConfig;
                };

                // Link up the ShareAgent & ShareService canisters 
                if (mainerAgentCanisterType == #ShareAgent) {
                    // Set the Share Service canister id for the Share Agent canister
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - calling controllerCanisterActor.setShareServiceCanisterId(" # shareServiceCanisterAddress # ")");
                    let statusCodeRecordResult = await controllerCanisterActor.setShareServiceCanisterId(shareServiceCanisterAddress);
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - statusCodeRecordResult " # debug_show (statusCodeRecordResult));
                    switch (statusCodeRecordResult) {
                        case (#Err(error)) {
                            D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - IGNORING THE ERROR: statusCodeRecordResult = " # debug_show (statusCodeRecordResult));
                            // return #Err(error);
                        };
                        case _ {
                            // all good, continue
                        };
                    };

                    // Register the Share Agent canister with the Share Service canister, so it is allowed to call it
                    let shareServiceCanisterActor = actor (shareServiceCanisterAddress) : Types.MainerAgentCtrlbCanister;
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - calling shareServiceCanisterActor.addMainerShareAgentCanister with mainerAgentCanisterInput = " # debug_show (mainerAgentCanisterInput));
                    let mainerAgentCanisterResult = await shareServiceCanisterActor.addMainerShareAgentCanister(mainerAgentCanisterInput);
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - mainerAgentCanisterResult " # debug_show (mainerAgentCanisterResult));
                    switch (mainerAgentCanisterResult) {
                        case (#Err(error)) {
                            D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - IGNORING THE ERROR: mainerAgentCanisterResult = " # debug_show (mainerAgentCanisterResult));
                            // return #Err(error);
                        };
                        case _ {
                            // all good, continue
                        };
                    };
                };

                
                // --------------------------------------------------------------------
                // Update the controller canister status with the Game State canister
                let gameStateCanisterActor = actor (MASTER_CANISTER_ID) : Types.GameStateCanister_Actor;
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - calling gameStateCanisterActor.addMainerAgentCanister with mainerAgentCanisterInput = " # debug_show (mainerAgentCanisterInput));
                let addMainerAgentCanisterResult = await gameStateCanisterActor.addMainerAgentCanister(mainerAgentCanisterInput);
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - addMainerAgentCanisterResult" # debug_show (addMainerAgentCanisterResult));
                switch (addMainerAgentCanisterResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - calling startTimerExecutionAdmin for upgraded canister");
                // Use ignore to avoid time-out issues
                ignore controllerCanisterActor.startTimerExecutionAdmin();
                // let authRecordResult = await controllerCanisterActor.startTimerExecutionAdmin();
                // D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): upgradeMainerctrl (" # canisterAddress # ") - authRecordResult returned by startTimerExecutionAdmin " # debug_show (authRecordResult));
                // switch (authRecordResult) {
                //     case (#Err(error)) {
                //         return #Err(error);
                //     };
                //     case _ {
                //         // all good, continue
                //     };
                // };


                // --------------------------------------------------------------------
                return #Ok({ status_code = 200 });
            };
            case _ { 
                return #Err(#Other("canisterType not supported"));
            };
        };
    };
    
    // Reinstalls the code into a mAIner controller canister.
    // This function is designed to be ignored, because there is no reason to await it
    // It will call the GameState canister addMainerAgentCanister when done, to update the status of the controller canister
    public shared (msg) func reinstallMainerctrl(reinstallMainerctrlInput : Types.ReinstallMainerctrlInput) : async Types.StatusCodeRecordResult {
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
        
        // Only Controllers and the GameState canister may call this
        if (not (Principal.isController(msg.caller) or Principal.equal(msg.caller, Principal.fromText(MASTER_CANISTER_ID)))) {
            return #Err(#Unauthorized);
        };

        let mainerAgentEntry : Types.OfficialMainerAgentCanister =reinstallMainerctrlInput.mainerAgentEntry; // Canister to reinstall
        let cyclesReinstallMainerctrlGsMc : Nat = reinstallMainerctrlInput.cyclesReinstallMainerctrlGsMc;
        let cyclesReinstallMainerctrlMcMainerctrl : Nat = reinstallMainerctrlInput.cyclesReinstallMainerctrlMcMainerctrl;

        let canisterAddress : Text = mainerAgentEntry.address;
        let canisterPrincipal : Principal = Principal.fromText(mainerAgentEntry.address);
        
        D.print("mAInerCreator: reinstallMainerctrl - mainerAgentEntry = " # debug_show (mainerAgentEntry));

        switch (mainerAgentEntry.canisterType) {
            case (#MainerAgent(_)) {
                // Reinstall mAIner controller canister               
                let mainerAgentCanisterType = mainerAgentEntry.mainerConfig.mainerAgentCanisterType;
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ")");

                // Accept required cycles for mAIner controller creation
                let cyclesAccepted = Cycles.accept<system>(cyclesReinstallMainerctrlGsMc);
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - cyclesAccepted = " # debug_show (cyclesAccepted) # " from caller " # Principal.toText(msg.caller));

                // Deposit cycles in the mAIner controller canister for the reinstall
                let cyclesAdded = cyclesReinstallMainerctrlMcMainerctrl;
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - calling Cycles.add for = " # debug_show(cyclesAdded) # " Cycles");
                Cycles.add<system>(cyclesAdded);
                
                let deposit_cycles_args = { canister_id : Principal = canisterPrincipal; };
                let _ = await IC0.deposit_cycles(deposit_cycles_args);
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - Successfully deposited " # debug_show(cyclesAdded) # " cycles to mAIner canister " # canisterAddress );
                
                // --------------------------------------------------
                // Verify the Shared Service canister. We are upgrading the links to it during a ShareAgent reinstall
                var shareServiceCanisterAddress : Types.CanisterAddress = ""; // TODO - Design: determine if this should be provided or whether Creator stores this info and fills it in here
                if (mainerAgentCanisterType == #ShareAgent) {
                    switch (reinstallMainerctrlInput.associatedCanisterAddress) {
                        case (null) {
                            return #Err(#Other("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - a #ShareAgent canister requires the shareServiceCanisterAddress to be provided in the onfigurationInput.associatedCanisterAddress."));
                        };
                        case (?associatedCanisterAddress) {
                            shareServiceCanisterAddress := associatedCanisterAddress;
                            try {
                                // Make sure the associated canister actually exists
                                let _ = Principal.fromText(associatedCanisterAddress); // this will throw an error if it's not a valid canister address
                                let associatedControllerCanisterActor = actor (associatedCanisterAddress) : Types.MainerAgentCtrlbCanister;
                                let healthResult = await associatedControllerCanisterActor.health();
                                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - healthResult" # debug_show (healthResult));
                                switch (healthResult) {
                                    case (#Err(error)) {                                        
                                        return #Err(error);
                                    };
                                    case _ {
                                        // all good, continue
                                    };
                                };
                            } catch (e) {
                                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - failed to validate existence & health of associatedCanisterAddress: " # debug_show(associatedCanisterAddress ) # " Error: " # Error.message(e) );
                                return #Err(#Other("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - failed to validate existence & health of associatedCanisterAddress: " # debug_show(associatedCanisterAddress ) # " Error: " # Error.message(e)));
                            };
                        };
                    };
                };

                // --------------------------------------------------
                // reinstall code
                let mode : ICManagementCanister.canister_install_mode = #reinstall;
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - start upgrading ctrlb canister " # canisterAddress);
                let installResult = await InstallCanisterCode.installCanisterCode(canisterPrincipal, mainerControllerCanisterWasm, mode);
                switch (installResult) {
                    case (#Ok(_)) {
                        D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - Successfully installed code into ctrlb canister " # canisterAddress);
                    };
                    case (#Err(errorMessage)) {
                        D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - Failed installing code into ctrlb canister " # canisterAddress # " Error: " # errorMessage);
                        return #Err(#Other("mAInerCreator: reinstallMainerctrl (" # canisterAddress # ") - Failed installing code into ctrlb canister: " # canisterAddress # " Error: " # errorMessage));
                    };
                };
                
                // --------------------------------------------------
                // Verify reinstalled canister is working
                let controllerCanisterActor = actor (canisterAddress) : Types.MainerAgentCtrlbCanister;
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - calling createdControllerCanister.health()");
                let readyControllerResult = await controllerCanisterActor.health();
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - readyControllerResult " # debug_show (readyControllerResult));
                switch (readyControllerResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                // --------------------------------------------------
                // We are also updating the GameState & ShareService settings, just in case they were not properly set or they have been upgraded since initial install

                // Set Game State canister address
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - calling createdControllerCanister.setGameStateCanisterId(MASTER_CANISTER_ID)");
                let setControllerGameStateResult = await controllerCanisterActor.setGameStateCanisterId(MASTER_CANISTER_ID);
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - setControllerGameStateResult " # debug_show (setControllerGameStateResult));
                switch (setControllerGameStateResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };
                

                // Set the setMainerCanisterType
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - calling createdControllerCanister.setMainerCanisterType(mainerAgentCanisterType)");
                let statusCodeRecordResult = await controllerCanisterActor.setMainerCanisterType(mainerAgentCanisterType);
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - setControllerGameStateResult " # debug_show (setControllerGameStateResult));
                switch (statusCodeRecordResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                let mainerAgentCanisterInput : Types.OfficialMainerAgentCanister = {
                    address : Text = mainerAgentEntry.address;
                    subnet : Text = mainerAgentEntry.subnet;
                    canisterType = mainerAgentEntry.canisterType;
                    creationTimestamp : Nat64 = mainerAgentEntry.creationTimestamp;
                    createdBy : Principal = mainerAgentEntry.createdBy;
                    ownedBy = mainerAgentEntry.ownedBy;
                    status = #Running;
                    mainerConfig = mainerAgentEntry.mainerConfig;
                };

                // Link up the ShareAgent & ShareService canisters 
                if (mainerAgentCanisterType == #ShareAgent) {
                    // Set the Share Service canister id for the Share Agent canister
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - calling controllerCanisterActor.setShareServiceCanisterId(" # shareServiceCanisterAddress # ")");
                    let statusCodeRecordResult = await controllerCanisterActor.setShareServiceCanisterId(shareServiceCanisterAddress);
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - statusCodeRecordResult " # debug_show (statusCodeRecordResult));
                    switch (statusCodeRecordResult) {
                        case (#Err(error)) {
                            D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - IGNORING THE ERROR: statusCodeRecordResult = " # debug_show (statusCodeRecordResult));
                            // return #Err(error);
                        };
                        case _ {
                            // all good, continue
                        };
                    };

                    // Register the Share Agent canister with the Share Service canister, so it is allowed to call it
                    let shareServiceCanisterActor = actor (shareServiceCanisterAddress) : Types.MainerAgentCtrlbCanister;
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - calling shareServiceCanisterActor.addMainerShareAgentCanister with mainerAgentCanisterInput = " # debug_show (mainerAgentCanisterInput));
                    let mainerAgentCanisterResult = await shareServiceCanisterActor.addMainerShareAgentCanister(mainerAgentCanisterInput);
                    D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - mainerAgentCanisterResult " # debug_show (mainerAgentCanisterResult));
                    switch (mainerAgentCanisterResult) {
                        case (#Err(error)) {
                            D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - IGNORING THE ERROR: mainerAgentCanisterResult = " # debug_show (mainerAgentCanisterResult));
                            // return #Err(error);
                        };
                        case _ {
                            // all good, continue
                        };
                    };
                };

                
                // --------------------------------------------------------------------
                // Update the controller canister status with the Game State canister
                let gameStateCanisterActor = actor (MASTER_CANISTER_ID) : Types.GameStateCanister_Actor;
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - calling gameStateCanisterActor.addMainerAgentCanister with mainerAgentCanisterInput = " # debug_show (mainerAgentCanisterInput));
                let addMainerAgentCanisterResult = await gameStateCanisterActor.addMainerAgentCanister(mainerAgentCanisterInput);
                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - addMainerAgentCanisterResult" # debug_show (addMainerAgentCanisterResult));
                switch (addMainerAgentCanisterResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case _ {
                        // all good, continue
                    };
                };

                D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - calling startTimerExecutionAdmin for reinstalled canister");
                // Use ignore to avoid time-out issues
                ignore controllerCanisterActor.startTimerExecutionAdmin();
                // let authRecordResult = await controllerCanisterActor.startTimerExecutionAdmin();
                // D.print("mAInerCreator ("  # debug_show (mainerAgentCanisterType) # "): reinstallMainerctrl (" # canisterAddress # ") - authRecordResult returned by startTimerExecutionAdmin " # debug_show (authRecordResult));
                // switch (authRecordResult) {
                //     case (#Err(error)) {
                //         return #Err(error);
                //     };
                //     case _ {
                //         // all good, continue
                //     };
                // };


                // --------------------------------------------------------------------
                return #Ok({ status_code = 200 });
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
        if (Principal.isAnonymous(msg.caller)) {
            return #Err(#Unauthorized);
        };
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
            if (Principal.isAnonymous(msg.caller)) {
                return #Err(#Unauthorized);
            };
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
        // Copy the runtime state back into the variable before upgrade.
        creationArtefactsByModelStable := Iter.toArray(creationArtefactsByModel.entries());
        llmCanisterWasmSha256ByModelStable := Iter.toArray(llmCanisterWasmSha256ByModel.entries());
    };

    // System-provided lifecycle method called after an upgrade or on initial deploy.
    system func postupgrade() {
        // After upgrade, reload the runtime state from the variable.
        creationArtefactsByModel := HashMap.fromIter(Iter.fromArray(creationArtefactsByModelStable), creationArtefactsByModelStable.size(), Text.equal, Text.hash);
        creationArtefactsByModelStable := [];

        llmCanisterWasmSha256ByModel := HashMap.fromIter(Iter.fromArray(llmCanisterWasmSha256ByModelStable), llmCanisterWasmSha256ByModelStable.size(), Text.equal, Text.hash);
        llmCanisterWasmSha256ByModelStable := [];
    };
    // -------------------------------------------------------------------------------
};