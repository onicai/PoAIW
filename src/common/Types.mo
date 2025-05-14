import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Nat16 "mo:base/Nat16";
import List "mo:base/List";
import Prelude "mo:base/Prelude";

import TokenLedger "./icp-ledger-interface";
import CMC "./cycles-minting-canister-interface";

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
    public type NatResult = Result<Nat, ApiError>;
    public type TextResult = Result<Text, ApiError>;

    //-------------------------------------------------------------------------
    public type GameStateTresholds = {
        thresholdArchiveClosedChallenges : Nat;
        thresholdMaxOpenChallenges : Nat;
        thresholdMaxOpenSubmissions : Nat;
        thresholdScoredResponsesPerChallenge : Nat;
    };

    public type GameStateTresholdsResult = Result<GameStateTresholds, ApiError>;

    //-------------------------------------------------------------------------
    public type ProtocolCanisterType = {
        #Challenger;
        #Judge;
        #Verifier;
        #MainerCreator;
        #MainerAgent : MainerAgentCanisterType;
        #MainerLlm;
    };

    public type CanisterAddress = Text;

    public type CanisterAddressesResult = Result<[CanisterAddress], ApiError>;

    public type LlmSetupStatus = {
        #CanisterCreationInProgress;
        #CanisterCreated;
        #CodeInstallInProgress;
        #ModelUploadProgress : Nat8;
        #ConfigurationInProgress;
    };

    public type CanisterStatus = {
        #Unlocked;
        #Paid;
        #ControllerCreationInProgress;
        #ControllerCreated;
        #LlmSetupInProgress : LlmSetupStatus;
        #LlmSetupFinished;
        #Running;
        #Paused;
        #Other : Text;
    };

    public type OfficialProtocolCanister = {
        address : CanisterAddress;
        canisterType: ProtocolCanisterType;
        creationTimestamp : Nat64;
        createdBy : Principal;
        ownedBy : Principal;
        status : CanisterStatus;
    };

    public type OfficialMainerAgentCanister = OfficialProtocolCanister and {
        mainerConfig : MainerConfigurationInput;
    };

    public type CanisterInput = {
        address : CanisterAddress;
        canisterType: ProtocolCanisterType;
    };

    public type MainerAgentCanisterType = {
        #NA; // Not Applicable for this canister
        #Own;
        #ShareAgent;
        #ShareService;
    };

    public type MainerAgentCanisterTypeResult = Result<MainerAgentCanisterType, ApiError>;

    public type MainerAgentCanisterResult = Result<OfficialMainerAgentCanister, ApiError>;

    public type MainerAgentCanistersResult = Result<[OfficialMainerAgentCanister], ApiError>;

    public type SetUpMainerLlmCanisterResult = Result<
        {
            llmCanisterId : Text;
            controllerCanisterEntry : OfficialMainerAgentCanister;
        }, ApiError>;

    public type CanisterRetrieveInput = {
        address : CanisterAddress;
    };
    
    //-------------------------------------------------------------------------
    public type SelectableMainerLLMs = {
        #Qwen2_5_500M;
    };

    public type MainerConfigurationInput = {
        mainerAgentCanisterType: MainerAgentCanisterType;
        selectedLLM : ?SelectableMainerLLMs;
    };

    public type RedeemedForOptions = {
        #MainerCreation : MainerAgentCanisterType;
        #MainerTopUp : CanisterAddress;
    };

    public type HandleIncomingFundsRecord = {
        cyclesForProtocol: Nat;
        cyclesForMainer : Nat;
    };

    public type HandleIncomingFundsResult = Result<HandleIncomingFundsRecord, ApiError>;

    public type VerifyPaymentRecord = {
        verified : Bool;
        amountPaid : Nat;
    };

    public type VerifyPaymentResult = Result<VerifyPaymentRecord, ApiError>;

    public type RedeemedTransactionBlock = {
        paymentTransactionBlockId : Nat64;
        creationTimestamp : Nat64;
        redeemedBy : Principal;
        redeemedFor : RedeemedForOptions;
        amount : Nat;
    };

    public type AddCyclesRecord = {
        added : Bool;
        amount : Nat;
    };

    public type AddCyclesResult = Result<AddCyclesRecord, ApiError>;

    public type OfficialMainerCycleTopUp = {
        amountAdded : Nat;
        newOfficialCycleBalance : Nat;
        creationTimestamp : Nat64;
        sentBy : Principal;
    };

    public type MainerCreationInput = {
        paymentTransactionBlockId : Nat64;
        mainerConfig : MainerConfigurationInput;
        owner: ?Principal;
    };

    public type CanisterCreationConfigurationInput = {
        canisterType : ProtocolCanisterType;
        associatedCanisterAddress : ?CanisterAddress; // References Controller for an LLM, and ShareService for a ShareAgent
        mainerConfig : MainerConfigurationInput;
    };

    public type CanisterCreationConfiguration = CanisterCreationConfigurationInput and {
        owner: Principal;
        userMainerEntryCreationTimestamp : Nat64; // References Controller - for deduplication by putUserMainerAgent
        userMainerEntryCanisterType : ProtocolCanisterType; // References Controller
    };

    public type CanisterCreationRecord = {
        creationResult : Text;
        newCanisterId : Text;
    };

    public type CanisterCreationResult = Result<CanisterCreationRecord, ApiError>;

    public type MainerAgentTopUpInput = {
        paymentTransactionBlockId : Nat64;
        mainerAgent : OfficialMainerAgentCanister;
    };

    //-------------------------------------------------------------------------
// Challenger
    public type ChallengeTopicStatus = {
        #Open;
        #Closed;
        #Archived;
        #Other : Text;
    };

    public type ChallengeStatus = {
        #Open;
        #Closed;
        #Archived;
        #Other : Text;
    };

    public type ChallengeTopicInput = {
        challengeTopic : Text;
    };
    public type ChallengeTopic = ChallengeTopicInput and {
        challengeTopicId : Text;
        challengeTopicCreationTimestamp : Nat64;
        challengeTopicStatus : ChallengeTopicStatus;
    };
    public type ChallengeTopicResult = Result<ChallengeTopic, ApiError>;

    public type NewChallengeInput = ChallengeTopic and {
        challengeQuestion : Text;
        challengeQuestionSeed : Nat32;
    };

    public type Challenge = NewChallengeInput and {
        challengeId : Text;
        challengeCreationTimestamp : Nat64;
        challengeCreatedBy : CanisterAddress;
        challengeStatus : ChallengeStatus;
        challengeClosedTimestamp : ?Nat64;
        submissionCyclesRequired : Nat;
    };

    public type ChallengeAdditionResult = Result<Challenge, ApiError>;

    public type ChallengeResult = Result<Challenge, ApiError>;

    public type ChallengesResult = Result<[Challenge], ApiError>;

    public type GeneratedChallenge = {
        generationId : Text;
        generationSeed : Nat32;
        generatedTimestamp : Nat64;
        generatedByLlmId : Text;
        generationPrompt : Text;
        generatedChallengeText : Text;
    };

    public type GeneratedChallengeResult = Result<GeneratedChallenge, ApiError>;
    public type GeneratedChallengesResult = Result<[GeneratedChallenge], ApiError>;

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

    public type CanisterIDRecordResult = Result<CanisterIDRecord, ApiError>;

// mAIner
    public type ChallengeQueueInput = Challenge and {
        challengeQueuedId : Text;
        challengeQueuedBy : Principal;
        challengeQueuedTo : Principal;
        challengeQueuedTimestamp : Nat64;
    };
    public type ChallengeQueueInputResult = Result<ChallengeQueueInput, ApiError>;
    public type ChallengeQueueInputsResult = Result<[ChallengeQueueInput], ApiError>;

    public type ChallengeResponseSubmissionStatus = {
        #FailedSubmission;
        #Received;
        #Submitted;
        #Judging;
        #Judged;
        #Processed;
        #Other : Text;
    };

    public type ChallengeResponseSubmissionInput = ChallengeQueueInput and {
        challengeAnswer : Text;
        challengeAnswerSeed : Nat32;
        submittedBy : Principal;
    };

    public type ChallengeResponseSubmissionMetadata = {
        submissionId : Text;
        submittedTimestamp : Nat64;
        submissionStatus : ChallengeResponseSubmissionStatus;
    };

    public type ChallengeResponseSubmission = ChallengeResponseSubmissionInput and ChallengeResponseSubmissionMetadata;

    public type ChallengeResponseSubmissionMetadataResult = Result<ChallengeResponseSubmissionMetadata, ApiError>;
    public type ChallengeResponseSubmissionResult = Result<ChallengeResponseSubmission, ApiError>;
    public type ChallengeResponseSubmissionsResult = Result<[ChallengeResponseSubmission], ApiError>;

    // Agent Settings
    public type TimeInterval = {
        #Daily;
    };

    public type CyclesBurnRate = {
        cycles : Nat;
        timeInterval : TimeInterval;
    };

    // TODO - Implementation: finalize implementation (likely: make this settable in Game State and then retrievable by mAIner)
    // TODO - Design: finalize exact (initial) amounts
    public let cyclesBurnRateDefaultLow : CyclesBurnRate = {
        cycles : Nat = 1_000_000_000_000;
        timeInterval : TimeInterval = #Daily;
    };

    public let cyclesBurnRateDefaultMid : CyclesBurnRate = {
        cycles : Nat = 4_000_000_000_000;
        timeInterval : TimeInterval = #Daily;
    };

    public let cyclesBurnRateDefaultHigh : CyclesBurnRate = {
        cycles : Nat = 10_000_000_000_000;
        timeInterval : TimeInterval = #Daily;
    };

    public let cyclesBurnRateDefaultVeryHigh : CyclesBurnRate = {
        cycles : Nat = 20_000_000_000_000;
        timeInterval : TimeInterval = #Daily;
    };

    public type CyclesBurnRateDefault = {
        #Low;
        #Mid;
        #High;
        #VeryHigh;
        #Custom : CyclesBurnRate;
    };

    public func getCyclesBurnRate(cyclesBurnRateDefault : CyclesBurnRateDefault) : CyclesBurnRate {
        switch (cyclesBurnRateDefault) {
            case (#Low) {
                return cyclesBurnRateDefaultLow;
            };
            case (#Mid) {
                return cyclesBurnRateDefaultMid;
            };
            case (#High) {
                return cyclesBurnRateDefaultHigh;
            };
            case (#VeryHigh) {
                return cyclesBurnRateDefaultVeryHigh;
            };
            case (#Custom(customCyclesBurnRate)) {
                return customCyclesBurnRate;
            };
            case (_) {
                return cyclesBurnRateDefaultLow;
            };
        };
    };

    // TODO - Implementation: merge into common file and finalize numbers
    public let PROTOCOL_OPERATION_FEES_CUT_PERCENT : Nat = 20;
    let CYCLES_BURNT_RESPONSE_GENERATION : Nat = 200_000_000_000;
    let SUBMISSION_CYCLES_REQUIRED : Nat = 100_000_000_000;
    let secondsInMinute = 60;
    let minutesInHour = 60;
    let hoursInDay = 24;

    public func getTimerRegularityForCyclesBurnRate(cyclesBurnRate : CyclesBurnRate) : Nat {
        var timeIntervalDuration = secondsInMinute * minutesInHour * hoursInDay; // Daily as default, i.e. this gives the seconds per day
        switch (cyclesBurnRate.timeInterval) {
            case (#Daily) {
                // use default
            };
        };
        // Calculate how many responses can be generated with the cycles budget based on response costs (generation plus submission)
        let submissionsInTimeInterval = cyclesBurnRate.cycles / (CYCLES_BURNT_RESPONSE_GENERATION + SUBMISSION_CYCLES_REQUIRED);
        // Calculate how often to respond (in seconds)
        let timerRegularity = timeIntervalDuration / submissionsInTimeInterval;

        return timerRegularity;
    };

    public type MainerAgentSettingsInput = {
        cyclesBurnRate : CyclesBurnRateDefault;
    };

    public type MainerAgentSettings = MainerAgentSettingsInput and {
        creationTimestamp : Nat64;
        createdBy : Principal;
    };

    public type IssueFlagsRecord = {
        lowCycleBalance : Bool;
    };

    public type IssueFlagsRetrievalResult = Result<IssueFlagsRecord, ApiError>;

    public type StatisticsRecord = {
        totalCyclesBurnt : Nat;
        cycleBalance : Nat;
        cyclesBurnRate : CyclesBurnRate;
    };

    public type StatisticsRetrievalResult = Result<StatisticsRecord, ApiError>;

    // local for mAIner interacting with LLM
    public type ChallengeResponse = {
        challengeId : Text;
        generationId : Text;
        generationSeed : Nat32;
        generatedTimestamp : Nat64;
        generatedByLlmId : Text;
        generationPrompt : Text;
        generatedResponseText : Text;
    };

    public type ChallengeResponseResult = Result<ChallengeResponse, ApiError>;

// Judge
    public type ScoredResponseInput = ChallengeResponseSubmission and {
        judgedBy: Principal;
        score: Nat;
        scoreSeed : Nat32;
    };

    public type ScoredResponse = ScoredResponseInput and {
        judgedTimestamp : Nat64;
    };

    public type ScoredResponseReturn = {
        success : Bool;
    };

    public type ScoredResponseResult = Result<ScoredResponseReturn, ApiError>;

    public type ScoredChallengesResult = Result<[(Text, List.List<ScoredResponse>)], ApiError>;

    public type SubmissionRetrievalInput = {
        challengeId : Text;
        submissionId : Text;
    };

    public type ScoredResponseRetrievalResult = Result<ScoredResponse, ApiError>;

    // local for Judge interacting with LLM
    public type JudgeScore = {
        generationId : Text;
        generationSeed : Nat32;
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

    public type CopyPromptCacheInputRecord = {
        from : Text;
        to : Text;
    };

// mAIner Creator
    public type InsertArtefactsResult = Result<ModelCreationArtefacts, ApiError>;

    // data needed to create a new canister with the model
    public type ModelCreationArtefacts = {
        canisterWasm : [Nat8];
        modelFile : [Blob];
        modelFileSha256 : Text;
    };

    public type FileUploadInputRecord = {
        filename : Text;
        chunk : [Nat8]; // the chunk being uploaded, as a vec of bytes
        chunksize : Nat64; // the chunksize (allowing sanity check)
        offset : Nat64; // the offset where to write the chunk
    };

    public type FileUploadRecordResult = Result<FileUploadRecord, ApiError>;
    
    public type FileUploadRecord = {
        filename : Text; // the total filesize in bytes
        filesize : Nat64; // the total filesize in bytes after writing chunk at offset
        filesha256 : Text; // the total filesize in bytes after writing chunk at offset
    };

    public type UploadResult = {
        creationResult : Text;
    };

    public type FileUploadResult = Result<UploadResult, ApiError>;

    public type MaxTokensRecord = {
        max_tokens_update : Nat64;
        max_tokens_query : Nat64;
    };

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

    public type ProtocolActivityRecord = {
        winners : [ChallengeWinnerDeclaration];
        challenges : [Challenge];
    };

    public type ProtocolActivityResult = Result<ProtocolActivityRecord, ApiError>;

    //-------------------------------------------------------------------------
    public type CyclesBurntResult = Result<Nat, ApiError>;

    //-------------------------------------------------------------------------

    public type StatusCode = Nat16;

    public type StatusCodeRecord = { status_code : StatusCode };

    public type StatusCodeRecordResult = Result<StatusCodeRecord, ApiError>;

    public type CanisterIDRecord = { canister_id : Text };

    //-------------------------------------------------------------------------
// Canister Actors
    public type GameStateCanister_Actor = actor {
        getRandomOpenChallengeTopic : () -> async ChallengeTopicResult;
        addChallenge : (NewChallengeInput) -> async ChallengeAdditionResult;
        getNextSubmissionToJudge : () -> async ChallengeResponseSubmissionResult;
        addScoredResponse : (ScoredResponseInput) -> async ScoredResponseResult;
        submitChallengeResponse : (ChallengeResponseSubmissionInput) -> async ChallengeResponseSubmissionMetadataResult;
        getRandomOpenChallenge : () -> async ChallengeResult;
        addMainerAgentCanister : (OfficialMainerAgentCanister) -> async MainerAgentCanisterResult;
    };

    public type MainerCreator_Actor = actor {
        createCanister: shared CanisterCreationConfiguration -> async CanisterCreationResult;
        setupCanister: shared (Text, CanisterCreationConfiguration) -> async CanisterCreationResult;
    };

    // mAIner
    public type MainerAgentCtrlbCanister = actor {
        add_llm_canister: (CanisterIDRecord) -> async StatusCodeRecordResult;
        health: query () -> async StatusCodeRecordResult;
        setGameStateCanisterId: (Text) -> async StatusCodeRecordResult;
        setRoundRobinLLMs: (Nat) -> async StatusCodeRecordResult;
        set_llm_canister_id: (CanisterIDRecord) -> async StatusCodeRecordResult;
        setMainerCanisterType: (MainerAgentCanisterType) -> async StatusCodeRecordResult;
        getMainerCanisterType: () -> async MainerAgentCanisterTypeResult;
        setShareServiceCanisterId: (Text) -> async StatusCodeRecordResult;
        addMainerShareAgentCanister: (OfficialMainerAgentCanister) -> async MainerAgentCanisterResult;
        startTimerExecutionAdmin: () -> async AuthRecordResult;
        addCycles: () -> async AddCyclesResult;
    };

    public type LLMCanister = actor {
        health : () -> async StatusCodeRecordResult;
        ready : () -> async StatusCodeRecordResult;
        check_access : () -> async StatusCodeRecordResult;
        new_chat : (InputRecord) -> async OutputRecordResult;
        run_update : (InputRecord) -> async OutputRecordResult;
        remove_prompt_cache : (InputRecord) -> async OutputRecordResult;
        copy_prompt_cache : (CopyPromptCacheInputRecord) -> async StatusCodeRecordResult;
        load_model : (InputRecord) -> async OutputRecordResult;
        set_max_tokens : (MaxTokensRecord) -> async StatusCodeRecordResult;
        file_upload_chunk : (FileUploadInputRecord) -> async FileUploadRecordResult;
        log_pause : () -> async StatusCodeRecordResult;
        log_resume : () -> async StatusCodeRecordResult;
    };

    // mAIner ShareAgent canister
    public type MainerCanister_Actor = actor {
        addChallengeToShareServiceQueue : (ChallengeQueueInput) -> async ChallengeQueueInputResult;
        addChallengeResponseToShareAgent : (ChallengeResponseSubmissionInput) -> async StatusCodeRecordResult;
    };

    // ICP Token Ledger
    public let ICP_TOKEN_LEDGER_CANISTER_ID = "ryjl3-tyaaa-aaaaa-aaaba-cai";
    public let IcpLedger_Actor : TokenLedger.TOKEN_LEDGER = actor (ICP_TOKEN_LEDGER_CANISTER_ID);

    // Cycles Minting Canister
    public let CYCLES_MINTING_CANISTER_ID = "rkp4c-7iaaa-aaaaa-aaaca-cai";
    public let CyclesMintingCanister_Actor : CMC.CYCLES_MINTING_CANISTER = actor (CYCLES_MINTING_CANISTER_ID);
};
