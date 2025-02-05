import Nat64 "mo:base/Nat64";

module Types {
    public type ChallengeResponseSubmissionStatus = {
        #FailedSubmission;
        #Received;
        #Submitted;
        #Judged;
        #Processed;
        #Other : Text;
    };

    public type ChallengeResponseSubmissionInput = {
        challengeId : Text;
        submittedBy : Principal;
        challengeQuestion : Text;
    };

    public type ChallengeResponseSubmission = ChallengeResponseSubmissionInput and {
        submissionId : Text;
        submittedTimestamp : Nat64;
        status : ChallengeResponseSubmissionStatus;
        challengeAnswer : Text;
    };

    public type ChallengeResponseSubmissionResult = Result<ChallengeResponseSubmission, ApiError>;
    public type ChallengeResponseSubmissionsResult = Result<[ChallengeResponseSubmission], ApiError>;


    public type ChallengeResponseSubmissionReturn = {
        success : Bool;
        submissionId : Text;
        submittedTimestamp : Nat64;
        status : ChallengeResponseSubmissionStatus;
    };

    public type ChallengeResponseSubmissionReturnResult = Result<ChallengeResponseSubmissionReturn, ApiError>;
    public type ChallengeResponseSubmissionsReturnResult = Result<[ChallengeResponseSubmissionReturn], ApiError>;

    public type ScoredResponseInput = ChallengeResponseSubmission and {
        judgedBy : Principal;
        score : Nat;
    };

    public type ScoredResponse = ScoredResponseInput and {
        judgedTimestamp : Nat64;
    };

    public type ScoredResponseReturn = {
        success : Bool;
    };

    public type ScoredResponseResult = Result<ScoredResponseReturn, ApiError>;

    public type JudgeScore = {
        generationId : Text;
        generatedTimestamp : Nat64;
        generatedByLlmId : Text;
        generationPrompt : Text;
        generatedScoreText : Text;
        generatedScore : Nat;
    };

    public type ScoredResponseByJudge = ScoredResponse and {
        judgeScoreRecord : JudgeScore;
    };

    public type JudgeChallengeResponseResult = Result<JudgeScore, ApiError>;

    public type ChallengeResponse = {
        challengeId : Text;
        generationId : Text;
        generatedTimestamp : Nat64;
        generatedByLlmId : Text;
        generationPrompt : Text;
        generatedResponseText : Text;
    };

    public type ChallengeResponseResult = Result<ChallengeResponse, ApiError>;

    public type GeneratedChallenge = {
        generationId : Text;
        generatedTimestamp : Nat64;
        generatedByLlmId : Text;
        generationPrompt : Text;
        generatedChallengeText : Text;
    };

    public type GeneratedChallengeResult = Result<GeneratedChallenge, ApiError>;

    public type CanisterIDRecordResult = Result<CanisterIDRecord, ApiError>;
    public type CanisterIDRecord = {
        canister_id : Text;
    };

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

    public type LLMCanister = actor {
        health : () -> async StatusCodeRecordResult;
        ready : () -> async StatusCodeRecordResult;
        check_access : () -> async StatusCodeRecordResult;
        new_chat : (InputRecord) -> async OutputRecordResult;
        run_update : (InputRecord) -> async OutputRecordResult;
        remove_prompt_cache : (InputRecord) -> async OutputRecordResult;
    };

    // Game State canister
    public type Challenge = {
        challengeId : Text;
        creationTimestamp : Nat64;
        createdBy : CanisterAddress;
        challengeQuestion : Text;
        status : ChallengeStatus;
        closedTimestamp : ?Nat64;
        responsibleJudgeAddress : CanisterAddress;
    };

    type CanisterAddress = Text;

    type ChallengeStatus = {
        #Open;
        #Closed;
        #Archived;
        #Other : Text;
    };

    public type NewChallengeInput = {
        challengeQuestion : Text;
    };

    public type ChallengeAdditionResult = Result<Challenge, ApiError>;

    public type ChallengeResult = Result<Challenge, ApiError>;

    public type GameStateCanister_Actor = actor {
        addChallenge : (NewChallengeInput) -> async ChallengeAdditionResult;
        addScoredResponse : (ScoredResponseInput) -> async ScoredResponseResult;
        submitChallengeResponse : (ChallengeResponseSubmissionInput) -> async ChallengeResponseSubmissionResult;
        getRandomOpenChallenge : () -> async ChallengeResult;
    };

    // Agent Settings
    public type TimeInterval = {
        #Daily;
    };

    public type CyclesBurnRate = {
        cycles : Nat;
        timeInterval : TimeInterval;
    };

    public type MainerAgentSettingsInput = {
        cyclesBurnRate : CyclesBurnRate;
    };

    public type MainerAgentSettings = MainerAgentSettingsInput and {
        creationTimestamp : Nat64;
        createdBy : Principal;
    };

    //--
    public type ApiError = {
        #Unauthorized;
        #InvalidId;
        #ZeroAddress;
        #FailedOperation;
        #Other : Text;
        #StatusCode : StatusCode;
    };

    //--
    public type Result<S, E> = {
        #Ok : S;
        #Err : E;
    };

    // --
    public type StatusCode = Nat16;

    public type StatusCodeRecord = { status_code : StatusCode };

    public type StatusCodeRecordResult = Result<StatusCodeRecord, ApiError>;

    public type AuthRecord = {
        auth : Text;
    };

    public type AuthRecordResult = Result<AuthRecord, ApiError>;
};
