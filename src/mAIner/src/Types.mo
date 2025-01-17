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

    public type ScoredResponseInput = ChallengeResponseSubmission and {
        judgedBy: Principal;
        score: Nat;
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
        generatedChallengeText : Text;
    };

    public type ScoredResponseByJudge = ScoredResponse and {
        judgeScoreRecord : JudgeScore;
    };

    public type JudgeChallengeResponseResult = Result<JudgeScore, ApiError>;

    public type GeneratedChallenge = {
        generationId : Text;
        generatedTimestamp : Nat64;
        generatedByLlmId : Text;
        generationPrompt : Text;
        generatedChallengeText : Text;
    };

    public type GeneratedChallengeResult = Result<GeneratedChallenge, ApiError>;

    public type StoryID = Text; // Must be unique for each story to be created

    public type Prompt = {
        prompt : Text;
        //  Max number of steps to run for
        steps : Nat64;
        //  Temperature [0:1] (0.0 = stories are deterministic)
        temperature : Float; // Candid float64
        //  p value in top-p (nucleus) sampling. [0:1] (1.0=off)
        topp : Float; // Candid float64
        //  Seed  (0=use random seed based on time)
        rng_seed : Nat64;
    };

    public type CanisterIDRecordResult = Result<CanisterIDRecord, ApiError>;
    public type CanisterIDRecord = {
        canister_id : Text;
    };

    public type LLMCanister = actor {
        health : () -> async StatusCodeRecordResult;
        ready : () -> async StatusCodeRecordResult;
        nft_ami_whitelisted : () -> async StatusCodeRecordResult;
        nft_story_start_mo : (NFT_llama2_c, Prompt) -> async InferenceRecordResult;
        nft_story_continue_mo : (NFT_llama2_c, Prompt) -> async InferenceRecordResult;
        nft_story_delete : (NFT_llama2_c) -> async StatusCodeRecordResult;
    };

    // Game State canister
    public type Challenge = {
        challengeId : Text;
        creationTimestamp : Nat64;
        createdBy : CanisterAddress;
        challengePrompt : Text;
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
        challengePrompt : Text;
    };

    public type ChallengeAdditionResult = Result<Challenge, ApiError>;

    public type ChallengeResponseSubmissionInput = {
        challengeId : Text;
        submittedBy : Principal;
        response : Text;
    };

    public type ChallengeResult = Result<Challenge, ApiError>;

    public type GameStateCanister_Actor = actor {
        addChallenge : (NewChallengeInput) -> async ChallengeAdditionResult;
        addScoredResponse : (ScoredResponseInput) -> async ScoredResponseResult;
        submitChallengeResponse : (ChallengeResponseSubmissionInput) -> async ChallengeResponseSubmissionResult;
        getRandomOpenChallenge : () -> async ChallengeResult;
    };

    // --
    // Input to StoryUpdate endpoint called by bioniq's NFT collection canister
    public type StoryInputRecord = {
        storyID : Text;
        storyPrompt : Text;
    };

    // --
    // Output from StoryUpdate endpoint called by bioniq's NFT collection canister
    public type StoryOutputRecordResult = Result<StoryOutputRecord, ApiError>;
    public type StoryOutputRecord = {
        storyID : Text;
        storyPrompt : Text;
        story : Text;
        status : Text;
        llmCanisterID : Text;
    };

    //--
    public type ApiError = {
        #InvalidId;
        #StatusCode : Nat16;
        #Other : Text;
        #ZeroAddress;
    };

    //--
    public type Result<S, E> = {
        #Ok : S;
        #Err : E;
    };

    // --
    public type StatusCodeRecordResult = Result<StatusCodeRecord, ApiError>;
    public type StatusCodeRecord = { status_code : Nat16 };

    public type AuthRecord = {
        auth : Text;
    };

    public type AuthRecordResult = Result<AuthRecord, ApiError>;

    // --
    // This is what the llama2_c canister uses
    // We set the token_id equal to the storyID
    public type NFT_llama2_c = {
        token_id : Text;
    };

    // --
    // Returned by 'nft_story_start', 'nft_story_continue'
    // Section of a story, generated by a single inference call
    public type InferenceRecordResult = Result<InferenceRecord, ApiError>;
    public type InferenceRecord = {
        inference : Text;
        num_tokens : Nat64;
    };
};
