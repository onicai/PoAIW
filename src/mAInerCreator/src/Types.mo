import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Nat16 "mo:base/Nat16";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";

module Types {
    //-------------------------------------------------------------------------
    public type ApiError = {
        #Unauthorized;
        #InvalidId;
        #ZeroAddress;
        #FailedOperation;
        #Other : Text;
        #StatusCode : StatusCode;
        #InsuffientCycles : Nat; // Returns the required cycles to perform the operation
    };

    public type Result<S, E> = {
        #Ok : S;
        #Err : E;
    };

    //-------------------------------------------------------------------------
    public type AuthRecord = {
        auth : Text;
    };

    public type AuthRecordResult = Result<AuthRecord, ApiError>;

    //-------------------------------------------------------------------------
    // data needed to create a new canister with the model
    public type ModelCreationArtefacts = {
        canisterWasm : [Nat8];
        modelFile : [Blob];
    };

    public type AvailableModels = {
        #Qwen2_5_500M;
    };
    
    public type CanisterAddress = Text;

    public type CanisterCreationConfigurationInput = {
        canisterType : ProtocolCanisterType;
        selectedModel : AvailableModels;
        associatedCanisterAddress : ?CanisterAddress;
    };

    public type CanisterCreationConfiguration = CanisterCreationConfigurationInput and {
        owner: Principal;
    };

    public type CanisterCreationRecord = {
        creationResult : Text;
        newCanisterId : Text;
    };

    public type CanisterCreationResult = Result<CanisterCreationRecord, ApiError>;

    public type ProtocolCanisterType = {
        #Challenger;
        #Judge;
        #Verifier;
        #MainerCreator;
        #MainerAgent;
        #MainerLlm;
    };

    public type InsertArtefactsResult = Result<ModelCreationArtefacts, ApiError>;

    public type StatusCode = Nat16;

    public type StatusCodeRecord = { status_code : StatusCode };

    public type StatusCodeRecordResult = Result<StatusCodeRecord, ApiError>;

    public type CanisterIDRecord = { canister_id : Text };

    public type InputRecord = {
        args : [Text]; // the CLI args of llama.cpp/examples/main, as a list of strings
    };

    public type OutputRecordResult = Result<OutputRecord, ApiError>;
    public type OutputRecord = {
        status_code : Nat16;
        output : Text;
        conversation : Text;
        error : Text;
        prompt_remaining : Text;
        generated_eog : Bool;
    };

    public type MainerAgentCtrlbCanister = actor {
        add_llm_canister_id: (CanisterIDRecord) -> async StatusCodeRecordResult;
        health: query () -> async StatusCodeRecordResult;
        setGameStateCanisterId: (Text) -> async StatusCodeRecordResult;
        setRoundRobinLLMs: (Nat) -> async StatusCodeRecordResult;
        set_llm_canister_id: (CanisterIDRecord) -> async StatusCodeRecordResult;
    };

    public type MaxTokensRecord = {
        max_tokens_update : Nat64;
        max_tokens_query : Nat64;
    };

    public type FileUploadInputRecord = {
        filename : Text;
        chunk : [Nat8]; // the chunk being uploaded, as a vec of bytes
        chunksize : Nat64; // the chunksize (allowing sanity check)
        offset : Nat64; // the offset where to write the chunk
    };

    type FileUploadRecordResult = Result<FileUploadRecord, ApiError>;
    
    public type FileUploadRecord = {
        filesize : Nat64; // the total filesize in bytes after writing chunk at offset
    };

    public type UploadResult = {
        creationResult : Text;
    };

    public type FileUploadResult = Result<UploadResult, ApiError>;

    public type LLMCanister = actor {
        health : () -> async StatusCodeRecordResult;
        ready : () -> async StatusCodeRecordResult;
        check_access : () -> async StatusCodeRecordResult;
        new_chat : (InputRecord) -> async OutputRecordResult;
        run_update : (InputRecord) -> async OutputRecordResult;
        remove_prompt_cache : (InputRecord) -> async OutputRecordResult;
        load_model : (InputRecord) -> async OutputRecordResult;
        set_max_tokens : (MaxTokensRecord) -> async StatusCodeRecordResult;
        file_upload_chunk : (FileUploadInputRecord) -> async FileUploadRecordResult;
    };

    // IC Management Canister types
    public type canister_id = Principal;
    public type canister_settings = {
        controllers : ?[Principal];
        freezing_threshold : ?Nat;
        memory_allocation : ?Nat;
        compute_allocation : ?Nat;
    };
    public type definite_canister_settings = {
        controllers : ?[Principal];
        freezing_threshold : Nat;
        memory_allocation : Nat;
        compute_allocation : Nat;
    };
    public type user_id = Principal;
    public type wasm_module = Blob;
    public type canister_status_response = {
        status : { #stopped; #stopping; #running };
        memory_size : Nat;
        cycles : Nat;
        settings : definite_canister_settings;
        module_hash : ?Blob;
    };

    public type IC_Management = actor {
        canister_status : shared query { canister_id : canister_id } -> async canister_status_response;
        create_canister : shared { settings : ?canister_settings } -> async {
            canister_id : canister_id;
        };
        delete_canister : shared { canister_id : canister_id } -> async ();
        deposit_cycles : shared { canister_id : canister_id } -> async ();
        install_code : shared {
            arg : Blob;
            wasm_module : wasm_module;
            mode : { #reinstall; #upgrade; #install };
            canister_id : canister_id;
        } -> async ();
        provisional_create_canister_with_cycles : shared {
            settings : ?canister_settings;
            amount : ?Nat;
        } -> async { canister_id : canister_id };
        provisional_top_up_canister : shared {
            canister_id : canister_id;
            amount : Nat;
        } -> async ();
        raw_rand : shared () -> async Blob;
        start_canister : shared { canister_id : canister_id } -> async ();
        stop_canister : shared { canister_id : canister_id } -> async ();
        uninstall_code : shared { canister_id : canister_id } -> async ();
        update_settings : shared {
            canister_id : Principal;
            settings : canister_settings;
        } -> async ();
    };
};