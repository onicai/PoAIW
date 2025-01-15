import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Nat16 "mo:base/Nat16";
import List "mo:base/List";

module Types {
    //-------------------------------------------------------------------------
    public type ApiError = {
        #Unauthorized;
        #InvalidId;
        #ZeroAddress;
        #FailedOperation;
        #Other : Text;
        #StatusCode : StatusCode;
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
    public type ProtocolCanisterType = {
        #Challenger;
        #Judge;
        #Verifier;
        #MainerCreator;
        #MainerAgent;
    };

    public type CanisterAddress = Text;

    public type OfficialProtocolCanister = {
        address : CanisterAddress;
        canisterType: ProtocolCanisterType;
        creationTimestamp : Nat64;
        createdBy : Principal;
        ownedBy: Principal;
    };

    public type CanisterInput = {
        address : CanisterAddress;
        canisterType: ProtocolCanisterType;
    };

    public type MainerAgentCanisterInput = {
        address : CanisterAddress;
        canisterType: ProtocolCanisterType;
        ownedBy: Principal;
    };

    public type MainerAgentCanisterResult = Result<OfficialProtocolCanister, ApiError>;

    public type CanisterRetrieveInput = {
        address : CanisterAddress;
    };
    
    //-------------------------------------------------------------------------
    public type SelectableMainerLLM = {
        #Qwen2_5_0_5_B;
    };

    public type MainerConfigurationInput = {
        aiModel : ?SelectableMainerLLM;
    };

    public type CanisterCreationConfiguration = {
        canisterType : ProtocolCanisterType;
        owner: Principal;
    };

    public type CanisterCreationRecord = {
        creationResult : Text;
        newCanisterId : Text;
    };

    public type CanisterCreationResult = Result<CanisterCreationRecord, ApiError>;

    //-------------------------------------------------------------------------
    public type Challenge = {
        challengeId : Text;
        creationTimestamp : Nat64;
        createdBy : CanisterAddress;
        challengePrompt : Text;
        status : ChallengeStatus;
        closedTimestamp : ?Nat64;
        responsibleJudgeAddress : CanisterAddress;
    };

    public type ChallengeStatus = {
        #Open;
        #Closed;
        #Archived;
        #Other : Text;
    };

    public type NewChallengeInput = {
        challengePrompt : Text;
    };

    public type ChallengeAdditionResult = Result<Challenge, ApiError>;

    public type ChallengeResult = Result<Challenge, ApiError>;

    public type ChallengesResult = Result<[Challenge], ApiError>;

    public type ChallengeResponseSubmissionInput = {
        challengeId : Text;
        submittedBy : Principal;
        response : Text;
    };

    public type ChallengeResponseSubmissionStatus = {
        #FailedSubmission;
        #Received;
        #Submitted;
        #Judged;
        #Processed;
        #Other : Text;
    };

    public type ChallengeResponseSubmission = {
        submissionId : Text;
        challengeId : Text;
        submittedBy : Principal;
        response : Text;
        submittedTimestamp : Nat64;
        status: ChallengeResponseSubmissionStatus;
    };

    public type ChallengeResponseSubmissionReturn = {
        success : Bool;
        submissionId : Text;
        submittedTimestamp : Nat64;
        status: ChallengeResponseSubmissionStatus;
    };

    public type ChallengeResponseSubmissionResult = Result<ChallengeResponseSubmissionReturn, ApiError>;

    public type ScoredResponseInput = {
        submissionId : Text;
        challengeId : Text;
        submittedBy : Principal;
        response : Text;
        submittedTimestamp : Nat64;
        status: ChallengeResponseSubmissionStatus;
        judgedBy: Principal;
        score: Nat;
    };

    public type ScoredResponse = {
        submissionId : Text;
        challengeId : Text;
        submittedBy : Principal;
        response : Text;
        submittedTimestamp : Nat64;
        status: ChallengeResponseSubmissionStatus;
        judgedBy: Principal;
        score: Nat;
        judgedTimestamp : Nat64;
    };

    public type ScoredResponseReturn = {
        success : Bool;
    };

    public type ScoredResponseResult = Result<ScoredResponseReturn, ApiError>;

    //-------------------------------------------------------------------------
    public type ChallengeWinnerDeclaration = {
        challengeId : Text;
        finalizedTimestamp : Nat64;
        winner : ChallengeParticipantEntry;
        secondPlace : ChallengeParticipantEntry;
        thirdPlace : ChallengeParticipantEntry;
        participants : List.List<ChallengeParticipantEntry>;
    };

    public type ChallengeParticipationResult = {
        #Winner;
        #SecondPlace;
        #ThirdPlace;
        #Participated;
        #Other : Text;
    };

    public type RewardType = {
        #MainerToken;
        #ICP;
        #Cycles;
        #Coupon : Text;
        #Other : Text;
    };

    public type ChallengeWinnerReward = {
        rewardType : RewardType;
        amount : Nat;
        rewardDetails : Text;
        distributed : Bool;
        distributedTimestamp : ?Nat64;
    };

    public type ChallengeParticipantEntry = {
        submissionId : Text;
        submittedBy : Principal;
        ownedBy : Principal;
        result : ChallengeParticipationResult;
        reward : ChallengeWinnerReward;
    };

    public type ChallengeWinnersResult = Result<[ChallengeWinnerDeclaration], ApiError>;

    //-------------------------------------------------------------------------

    public type FileUploadRecord = {
        creationResult : Text;
    };

    public type FileUploadResult = Result<FileUploadRecord, ApiError>;

    public type StatusCode = Nat16;

    public type StatusCodeRecord = { status_code : StatusCode };

    public type StatusCodeRecordResult = Result<StatusCodeRecord, ApiError>;

    public type CanisterIDRecord = { canister_id : Text };

    //-------------------------------------------------------------------------
// Canister Actors
    public type Judge_Actor = actor {
        addSubmissionToJudge: shared (Types.ChallengeResponseSubmission) -> async Bool
    };

    public type MainerCreator_Actor = actor {
        createCanister: shared CanisterCreationConfiguration -> async CanisterCreationResult;
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
