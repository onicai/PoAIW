import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Nat16 "mo:base/Nat16";
import List "mo:base/List";
import Prelude "mo:base/Prelude";

import TokenLedger "./icp-ledger-interface";
import CMC "./cycles-minting-canister-interface";
import LiquidityPool "./icpswap-liquidity-pool-interface";

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
    public type MainerTimers = {
        action1RegularityInSeconds : Nat;
        action2RegularityInSeconds : Nat;
    };

    public type MainerTimersResult = Result<MainerTimers, ApiError>;

    //-------------------------------------------------------------------------
    public type SubnetIds = {
        subnetShareAgentCtrl : Text;
        subnetShareServiceCtrl : Text;
        subnetShareServiceLlm : Text;
    };

    public type SubnetIdsResult = Result<SubnetIds, ApiError>;

    //-------------------------------------------------------------------------
    // Types for storing all cycles flow values

    // variables sent by GameState to mAIner Creator
    public type CyclesCreateMainer = {
        cyclesCreateMainerctrlGsMc : Nat;
        cyclesCreateMainerllmGsMc : Nat;
        cyclesCreateMainerctrlMcMainerctrl : Nat;
        cyclesCreateMainerllmMcMainerllm   : Nat;
    };

    // variables sent by GameState to mAIner Creator
    public type CyclesUpgradeMainer = {
        cyclesUpgradeMainerctrlGsMc : Nat;
        cyclesUpgradeMainerllmGsMc : Nat;
        cyclesUpgradeMainerctrlMcMainerctrl : Nat;
        cyclesUpgradeMainerllmMcMainerllm   : Nat;
    };

    // variables sent by GameState to mAIner Creator
    public type CyclesReinstallMainer = {
        cyclesReinstallMainerctrlGsMc : Nat;
        cyclesReinstallMainerllmGsMc : Nat;
        cyclesReinstallMainerctrlMcMainerctrl : Nat;
        cyclesReinstallMainerllmMcMainerllm   : Nat;
    };

    // variables sent by GameState to Challenger
    public type CyclesGenerateChallenge = {
        cyclesGenerateChallengeGsChctrl : Nat;
        cyclesGenerateChallengeChctrlChllm : Nat;
    };

    // variables sent by GameState to mAIner Agent
    public type CyclesGenerateResponse = {
        cyclesSubmitResponse : Nat;
        protocolOperationFeesCut : Nat;
        cyclesGenerateResponseSactrlSsctrl : Nat;
        cyclesGenerateResponseSsctrlGs : Nat;
        cyclesGenerateResponseSsctrlSsllm : Nat;
        cyclesGenerateResponseOwnctrlGs : Nat;
        cyclesGenerateResponseOwnctrlOwnllmLOW : Nat;
        cyclesGenerateResponseOwnctrlOwnllmMEDIUM : Nat;
        cyclesGenerateResponseOwnctrlOwnllmHIGH : Nat;
    };

    // variables sent by GameState to Judge
    public type CyclesGenerateScore = {
        cyclesGenerateScoreGsJuctrl : Nat;
        cyclesGenerateScoreJuctrlJullm : Nat;
    };

    public type CyclesFlow = CyclesGenerateChallenge and 
    CyclesGenerateScore and CyclesGenerateResponse and {
        // mAIner creation
        cyclesCreateMainerMarginGs : Nat;
        cyclesCreatemMainerMarginMc : Nat;
        cyclesCreateMainerLlmTargetBalance : Nat;
        costCreateMainerCtrl : Nat;
        costCreateMainerLlm : Nat;
        costCreateMcMainerCtrl : Nat;
        costCreateMcMainerLlm : Nat;

        costUpgradeMainerCtrl : Nat;
        costUpgradeMainerLlm : Nat;
        costUpgradeMcMainerCtrl : Nat;
        costUpgradeMcMainerLlm : Nat;


        // Generations
        dailyChallenges : Nat;
        dailySubmissionsPerOwnLOW : Nat;
        dailySubmissionsPerOwnMEDIUM : Nat;
        dailySubmissionsPerOwnHIGH : Nat;
        dailySubmissionsPerShareLOW : Nat;
        dailySubmissionsPerShareMEDIUM : Nat;
        dailySubmissionsPerShareHIGH : Nat;
        dailySubmissionsAllOwn : Nat;
        dailySubmissionsAllShare : Nat;
        marginFailedSubmissionCut : Nat;
        marginCost : Nat;
        submissionFee : Nat;

        numChallengerLlms : Nat;
        numJudgeLlms : Nat;
        numShareServiceLlms : Nat;

        costIdleBurnRateGs : Nat;
        costIdleBurnRateMc : Nat;
        costIdleBurnRateChctrl : Nat;
        costIdleBurnRateChllm : Nat;
        costIdleBurnRateJuctrl : Nat;
        costIdleBurnRateJullm : Nat;
        costIdleBurnRateSsctrl : Nat;
        costIdleBurnRateSsllm : Nat;

        costIdleBurnRateSactrl : Nat;
        costIdleBurnRateSallm : Nat;
        costIdleBurnRateOwnctrl : Nat;
        costIdleBurnRateOwnllm : Nat;

        costGenerateChallengeGs : Nat;
        costGenerateChallengeChctrl : Nat;
        costGenerateChallengeChllm : Nat;
        costGenerateScoreGs : Nat;
        costGenerateScoreJuctrl : Nat;
        costGenerateScoreJullm : Nat;
        costGenerateResponseShareGs : Nat;
        costGenerateResponseOwnGs : Nat;
        costGenerateResponseOwnctrl : Nat;
        costGenerateResponseOwnllm : Nat;
        costGenerateResponseSactrl : Nat;
        costGenerateResponseSsctrl : Nat;
        costGenerateResponseSsllm : Nat;

        cyclesBurntChallengeGeneration : Nat;
        cyclesBurntJudgeScoring : Nat;
        cyclesBurntResponseGenerationOwn : Nat;
        cyclesBurntResponseGenerationShare : Nat;
        cyclesFailedSubmissionCut : Nat;
    };
    public type CyclesFlowResult = Result<CyclesFlow, ApiError>;

    // Type for selectively setting cycles flow values by Admin
    public type CyclesFlowSettings = {
        // mAIner creation
        cyclesCreateMainerMarginGs : ?Nat;
        cyclesCreatemMainerMarginMc : ?Nat;
        cyclesCreateMainerLlmTargetBalance : ?Nat;
        costCreateMainerCtrl : ?Nat;
        costCreateMainerLlm : ?Nat;
        costCreateMcMainerCtrl : ?Nat;
        costCreateMcMainerLlm : ?Nat;

        costUpgradeMainerCtrl :?Nat;
        costUpgradeMainerLlm : ?Nat;
        costUpgradeMcMainerCtrl : ?Nat;
        costUpgradeMcMainerLlm : ?Nat;

        cyclesUpgradeMainerctrlGsMc : ?Nat;
        cyclesUpgradeMainerllmGsMc : ?Nat;
        cyclesUpgradeMainerctrlMcMainerctrl : ?Nat;
        cyclesUpgradeMainerllmMcMainerllm   : ?Nat;

        cyclesReinstallMainerctrlGsMc : ?Nat;
        cyclesReinstallMainerllmGsMc : ?Nat;
        cyclesReinstallMainerctrlMcMainerctrl : ?Nat;
        cyclesReinstallMainerllmMcMainerllm   : ?Nat;

        // Generations
        dailyChallenges : ?Nat;
        dailySubmissionsPerOwnLOW : ?Nat;
        dailySubmissionsPerOwnMEDIUM : ?Nat;
        dailySubmissionsPerOwnHIGH : ?Nat;
        dailySubmissionsPerShareLOW : ?Nat;
        dailySubmissionsPerShareMEDIUM : ?Nat;
        dailySubmissionsPerShareHIGH : ?Nat;
        dailySubmissionsAllOwn : ?Nat;
        dailySubmissionsAllShare : ?Nat;
        marginFailedSubmissionCut : ?Nat;
        marginCost : ?Nat;
        submissionFee : ?Nat;

        numChallengerLlms : ?Nat;
        numJudgeLlms : ?Nat;
        numShareServiceLlms : ?Nat;

        costIdleBurnRateGs : ?Nat;
        costIdleBurnRateMc : ?Nat;
        costIdleBurnRateChctrl : ?Nat;
        costIdleBurnRateChllm : ?Nat;
        costIdleBurnRateJuctrl : ?Nat;
        costIdleBurnRateJullm : ?Nat;
        costIdleBurnRateSsctrl : ?Nat;
        costIdleBurnRateSsllm : ?Nat;

        costIdleBurnRateSactrl : ?Nat;
        costIdleBurnRateSallm : ?Nat;
        costIdleBurnRateOwnctrl : ?Nat;
        costIdleBurnRateOwnllm : ?Nat;

        costGenerateChallengeGs : ?Nat;
        costGenerateChallengeChctrl : ?Nat;
        costGenerateChallengeChllm : ?Nat;
        costGenerateScoreGs : ?Nat;
        costGenerateScoreJuctrl : ?Nat;
        costGenerateScoreJullm : ?Nat;
        costGenerateResponseOwnGs : ?Nat;
        costGenerateResponseOwnctrl : ?Nat;
        costGenerateResponseOwnllm : ?Nat;
        costGenerateResponseShareGs : ?Nat;
        costGenerateResponseSactrl : ?Nat;
        costGenerateResponseSsctrl : ?Nat;
        costGenerateResponseSsllm : ?Nat;

        cyclesGenerateChallengeGsChctrl : ?Nat;
        cyclesGenerateChallengeChctrlChllm : ?Nat;
        cyclesBurntChallengeGeneration : ?Nat;
        cyclesGenerateScoreGsJuctrl : ?Nat;
        cyclesGenerateScoreJuctrlJullm : ?Nat;
        cyclesBurntJudgeScoring : ?Nat;
        cyclesGenerateResponseOwnctrlGs : ?Nat;
        cyclesGenerateResponseOwnctrlOwnllmLOW : ?Nat;
        cyclesGenerateResponseOwnctrlOwnllmMEDIUM : ?Nat;
        cyclesGenerateResponseOwnctrlOwnllmHIGH : ?Nat;
        cyclesGenerateResponseSactrlSsctrl : ?Nat;
        cyclesGenerateResponseSsctrlGs : ?Nat;
        cyclesGenerateResponseSsctrlSsllm : ?Nat;
        cyclesBurntResponseGenerationOwn : ?Nat;
        cyclesBurntResponseGenerationShare : ?Nat;
        cyclesSubmitResponse : ?Nat;
        protocolOperationFeesCut : ?Nat;
        cyclesFailedSubmissionCut : ?Nat;
    };

    //-------------------------------------------------------------------------
    public type ProtocolCanisterType = {
        #Challenger;
        #Judge;
        #Verifier;
        #MainerCreator;
        #MainerAgent : MainerAgentCanisterType;
        #MainerLlm;
    };

    public type LlmCanistersRecordResult = Result<LlmCanistersRecord, ApiError>;
    public type LlmCanistersRecord = {
        llmCanisterIds : [CanisterAddress]; // List of LLM canister IDs as text
        roundRobinUseAll : Bool; // If true, use all canisters in round-robin fashion
        roundRobinLLMs : Nat; // number of LLMs to use - Only used when roundRobinUseAll is false
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
        subnet : Text;
        canisterType: ProtocolCanisterType;
        creationTimestamp : Nat64;
        createdBy : Principal;
        ownedBy : Principal;
        status : CanisterStatus;
    };

    public type OfficialProtocolCanistersResult = Result<[OfficialProtocolCanister], ApiError>;

    public type OfficialMainerAgentCanister = OfficialProtocolCanister and {
        mainerConfig : MainerConfigurationInput;
    };

    public type CanisterInput = {
        address : CanisterAddress;
        subnet : Text;
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

    public type UpdateWasmHashInput = {
        wasmHash : Blob;
        textNote : Text;
    };

    public type CanisterWasmHashRecord = UpdateWasmHashInput and {
        creationTimestamp : Nat64;
        createdBy : Principal;
        version : Nat;
    };

    public type DeriveWasmHashInput = {
        address : CanisterAddress;
        textNote : Text;
    };

    public type CanisterWasmHashRecordResult = Result<CanisterWasmHashRecord, ApiError>;
    
    //-------------------------------------------------------------------------
    public type SelectableMainerLLMs = {
        #Qwen2_5_500M;
    };

    public type MainerConfigurationInput = {
        mainerAgentCanisterType: MainerAgentCanisterType;
        selectedLLM : ?SelectableMainerLLMs;
        cyclesForMainer : Nat; // initial amount of the user payment used to create the mAIner
        subnetCtrl : Text; // the subnet where the mAIner Controller will be created
        subnetLlm : Text;  // the subnet where the mAIner LLMs will be created
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

    public type RedeemedTransactionBlockResult = Result<RedeemedTransactionBlock, ApiError>;

    public type RedeemedTransactionBlocksResult = Result<[RedeemedTransactionBlock], ApiError>;

    public type PriceRecord = {
        price : Nat64;
    };

    public type PriceResult = Result<PriceRecord, ApiError>;

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

    public type PaymentTransactionBlockId = {
        paymentTransactionBlockId : Nat64;
    };

    public type IcpTransferArgs = {
        amount : TokenLedger.Tokens;
        toPrincipal : Principal;
        toSubaccount : ?Blob;
    };

    public type IcpTransferResult = Result<Nat64, ApiError>;

    public type MainerCreationInput = PaymentTransactionBlockId and {
        mainerConfig : MainerConfigurationInput;
        owner: ?Principal;
    };

    public type WhitelistMainerCreationInput = MainerCreationInput and OfficialMainerAgentCanister;

    public type CheckMainerLimit = {
        mainerType : MainerAgentCanisterType;
    };

    public type MainerLimitInput = CheckMainerLimit and {
        newLimit : Nat;
    };

    public type MainerctrlUpgradeInput = {
        canisterAddress : CanisterAddress;
    };

    public type MainerctrlReinstallInput = {
        canisterAddress : CanisterAddress;
    };

    public type CanisterCreationConfigurationInput = {
        canisterType : ProtocolCanisterType;
        associatedCanisterAddress : ?CanisterAddress; // References Controller for an LLM, and ShareService for a ShareAgent
        associatedCanisterSubnet : Text; // References subnet of Controller for an LLM, and ShareService for a ShareAgent
        mainerConfig : MainerConfigurationInput;
    };

    public type CanisterCreationConfiguration = CanisterCreationConfigurationInput and 
    {
        owner: Principal;
        userMainerEntryCreationTimestamp : Nat64; // References Controller - for deduplication by putUserMainerAgent
        userMainerEntryCanisterType : ProtocolCanisterType; // References Controller
    } and 
    CyclesCreateMainer;

    public type CanisterCreationRecord = {
        creationResult : Text;
        newCanisterId : Text;
        subnet: Text;
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
    } and CyclesGenerateChallenge;
    public type ChallengeTopicResult = Result<ChallengeTopic, ApiError>;

    public type NewChallengeInput = ChallengeTopic and {
        challengeQuestion : Text;
        challengeQuestionSeed : Nat32;
        mainerPromptId : Text;
        mainerMaxContinueLoopCount : Nat;
        mainerNumTokens : Nat64;
        mainerTemp : Float;
        judgePromptId : Text;
    };

    public type Challenge = NewChallengeInput and {
        challengeId : Text;
        challengeCreationTimestamp : Nat64;
        challengeCreatedBy : CanisterAddress;
        challengeStatus : ChallengeStatus;
        challengeClosedTimestamp : ?Nat64;
    } and CyclesGenerateResponse;

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

// llama_cpp_canister endpoints data structures
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

    public type DownloadPromptCacheInputRecord = {
        promptcache : Text;
        chunksize : Nat64;
        offset : Nat64;
    };

    public type UploadPromptCacheInputRecord = {
        promptcache : Text;
        chunk : [Nat8];
        chunksize : Nat64;
        offset : Nat64;
    };

    public type PromptCacheDetailsInputRecord = {
        promptcache : Text;
    };

    // -----------------------------------------------------
    public type FileDownloadInputRecord = {
        filename : Text;
        chunksize : Nat64;
        offset : Nat64;
    };
    public type FileDownloadRecordResult = Result<FileDownloadRecord, ApiError>;

    public type FileDownloadRecord = {
        chunk : Blob; // the chunk read from the file, as a vec of bytes
        chunksize : Nat64; // the chunksize in bytes
        filesize : Nat64; // the total filesize in bytes
        offset : Nat64; // the chunk starts here (bytes from beginning)
        done : Bool; // true if there are no more bytes to read
    };

    // -----------------------------------------------------
    public type FileDetailsInputRecord = {
        filename : Text;
    };
    public type FileDetailsRecordResult = Result<FileDetailsRecord, ApiError>;

    public type FileDetailsRecord = {
        filename : Text;
        filesize : Nat64; // the total filesize in bytes
        filesha256 : Text; // the total filesize in bytes
    };

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
    } and CyclesGenerateScore;

    public type ChallengeResponseSubmission = ChallengeResponseSubmissionInput and ChallengeResponseSubmissionMetadata;

    public type ChallengeResponseSubmissionWithQueueStatus = {
        submission : ChallengeResponseSubmission;
        remainingInQueue : Nat;
    };

    public type ChallengeResponseSubmissionMetadataResult = Result<ChallengeResponseSubmissionMetadata, ApiError>;
    public type ChallengeResponseSubmissionResult = Result<ChallengeResponseSubmission, ApiError>;
    public type ChallengeResponseSubmissionWithQueueStatusResult = Result<ChallengeResponseSubmissionWithQueueStatus, ApiError>;
    public type ChallengeResponseSubmissionsResult = Result<[ChallengeResponseSubmission], ApiError>;

    public type UploadMainerLlmCanisterWasmBytesChunkInput = {
        selectedModel : SelectableMainerLLMs;
        bytesChunk : [Nat8];
    };
    public type AddModelCreationArtefactsEntry = {
        selectedModel : SelectableMainerLLMs;
        creationArtefacts : ModelCreationArtefacts;
    };
    public type FinishUploadMainerLlmInput = {
        selectedModel : SelectableMainerLLMs;
        modelFileSha256 : Text;
    };
    public type UploadMainerLlmBytesChunkInput = {
        bytesChunk : Blob;
        chunkID : Nat;
    };
    public type SetupCanisterInput = {
        newCanisterId : Text;
        subnet : Text;
        configurationInput : CanisterCreationConfiguration;
    };
    public type UpgradeMainerctrlInput = {
        mainerAgentEntry : Types.OfficialMainerAgentCanister; // Canister to upgrade
        associatedCanisterAddress : ?Types.CanisterAddress; // null for #Own, shareServiceCanisterAddress for ShareAgent
        associatedCanisterSubnet : Text;
        cyclesUpgradeMainerctrlGsMc : Nat;
        cyclesUpgradeMainerctrlMcMainerctrl : Nat;
    };
    public type ReinstallMainerctrlInput = {
        mainerAgentEntry : Types.OfficialMainerAgentCanister; // Canister to reinstall
        associatedCanisterAddress : ?Types.CanisterAddress; // null for #Own, shareServiceCanisterAddress for ShareAgent
        associatedCanisterSubnet : Text;
        cyclesReinstallMainerctrlGsMc : Nat;
        cyclesReinstallMainerctrlMcMainerctrl : Nat;
    };

    public type TestCreateMainerControllerCanister = {
        mainerAgentCanisterType : MainerAgentCanisterType;
        shareServiceCanisterAddress : ?CanisterAddress;
    };

    // Agent Settings
    public type TimeInterval = {
        #Daily;
    };

    public type CyclesBurnRate = {
        cycles : Nat;
        timeInterval : TimeInterval;
    };

    public type CyclesBurnRateResult = Result<CyclesBurnRate, ApiError>;

    public type CyclesBurnRateDefault = {
        #Low;
        #Mid;
        #High;
        #VeryHigh;
        #Custom : CyclesBurnRate;
    };

    public type SetCyclesBurnRateInput = {
        cyclesBurnRateDefault : CyclesBurnRateDefault;
        cyclesBurnRate : CyclesBurnRate;
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

    public type FlagRecord = {
        flag : Bool;
    };

    public type FlagResult = Result<FlagRecord, ApiError>;

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
        canisterWasm : [Blob]; // Preserve the chunks, so we do not need to re-chunk during code installation
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

    public type RewardPerChallenge = {
        rewardType : RewardType;
        totalAmount : Nat;
        winnerAmount : Nat;
        secondPlaceAmount : Nat;
        thirdPlaceAmount : Nat;
        amountForAllParticipants : Nat;
    };

    public type RewardPerChallengeResult = Result<RewardPerChallenge, ApiError>;

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
    // pre-calculated & ingested mAIner prompt & prompt cache
    public type MainerPromptInfo = {
        promptText : Text;
        promptCacheSha256 : Text;
        promptCacheFilename: Text;
        promptCacheNumberOfChunks : Nat;
    };
    public type MainerPromptInfoResult = Result<MainerPromptInfo, ApiError>;


    public type MainerPrompt = MainerPromptInfo and {
        promptCacheChunks : [Blob];
    };
    public type MainerPromptGenerationInput = {
        generatedChallenge : Types.GeneratedChallenge;
        chunkSizePrompCacheDownload : Nat64;
    };
    public type MainerPromptGenerationRecord = {
        generationId : Text;
        generationSeed : Nat32;
        generatedTimestamp : Nat64;
        generatedByLlmId : Text;
        generationPrompt : Text;
        mainerPrompt: MainerPrompt;
    };
    public type MainerPromptGenerationRecordResult = Result<MainerPromptGenerationRecord, ApiError>;

    public type StartUploadMainerPromptCacheRecord = {
        mainerPromptId : Text;
    };
    public type StartUploadMainerPromptCacheRecordResult = Result<StartUploadMainerPromptCacheRecord, ApiError>;

    public type UploadMainerPromptCacheBytesChunkInput = {
        mainerPromptId : Text;
        bytesChunk : Blob;
        chunkID : Nat;
    };
    public type FinishUploadMainerPromptCacheInput = {
        mainerPromptId : Text;
        promptText: Text;
        promptCacheSha256: Text;
        promptCacheFilename: Text;
    };

    public type DownloadMainerPromptCacheBytesChunkInput = {
        mainerPromptId : Text;
        chunkID : Nat;
    };
    public type DownloadMainerPromptCacheBytesChunkRecord = DownloadMainerPromptCacheBytesChunkInput and {
        bytesChunk : Blob;
    };
    public type DownloadMainerPromptCacheBytesChunkRecordResult = Result<DownloadMainerPromptCacheBytesChunkRecord, ApiError>;

    //-------------------------------------------------------------------------
    // pre-calculated & ingested Judge prompt & prompt cache
    public type JudgePromptInfo = {
        promptText : Text;
        promptCacheSha256 : Text;
        promptCacheFilename: Text;
        promptCacheNumberOfChunks : Nat;
    };
    public type JudgePromptInfoResult = Result<JudgePromptInfo, ApiError>;

    public type JudgePrompt = JudgePromptInfo and {
        promptCacheChunks : [Blob];
    };
    public type JudgePromptGenerationInput = {
        generatedChallenge : Types.GeneratedChallenge;
        chunkSizePrompCacheDownload : Nat64;
    };
    public type JudgePromptGenerationRecord = {
        generationId : Text;
        generationSeed : Nat32;
        generatedTimestamp : Nat64;
        generatedByLlmId : Text;
        generationPrompt : Text;
        judgePrompt: JudgePrompt;
    };
    public type JudgePromptGenerationRecordResult = Result<JudgePromptGenerationRecord, ApiError>;

    public type StartUploadJudgePromptCacheRecord = {
        judgePromptId : Text;
    };
    public type StartUploadJudgePromptCacheRecordResult = Result<StartUploadJudgePromptCacheRecord, ApiError>;

    public type UploadJudgePromptCacheBytesChunkInput = {
        judgePromptId : Text;
        bytesChunk : Blob;
        chunkID : Nat;
    };
    public type FinishUploadJudgePromptCacheInput = {
        judgePromptId : Text;
        promptText: Text;
        promptCacheSha256: Text;
        promptCacheFilename: Text;
    };

    public type DownloadJudgePromptCacheBytesChunkInput = {
        judgePromptId : Text;
        chunkID : Nat;
    };
    public type DownloadJudgePromptCacheBytesChunkRecord = DownloadJudgePromptCacheBytesChunkInput and {
        bytesChunk : Blob;
    };
    public type DownloadJudgePromptCacheBytesChunkRecordResult = Result<DownloadJudgePromptCacheBytesChunkRecord, ApiError>;

// Data migration to archive canisters
    public type ChallengeMigrationInput = {
        challenges : [Challenge];
    };

    public type ChallengeMigrationRecord = {
        migrated : Bool;
    };

    public type ChallengeMigrationResult = Result<ChallengeMigrationRecord, ApiError>;

    public type MainerBackupInput  = {
        mainers : [(Text, OfficialMainerAgentCanister)];
    };

    public type MainerBackupRecord = {
        backedUp : Bool;
    };

    public type MainerBackupResult = Result<MainerBackupRecord, ApiError>;

    public type MainersResult = Result<[(Text, OfficialMainerAgentCanister)], ApiError>;

    public type SubmissionMigrationInput = {
        submissions : [ChallengeResponseSubmission];
    };

    public type SubmissionMigrationRecord = {
        migrated : Bool;
    };

    public type SubmissionMigrationResult = Result<SubmissionMigrationRecord, ApiError>;

    public type WinnerDeclarationMigrationInput = {
        winnerDeclarations : [ChallengeWinnerDeclaration];
    };

    public type WinnerDeclarationMigrationRecord = {
        migrated : Bool;
    };

    public type WinnerDeclarationMigrationResult = Result<WinnerDeclarationMigrationRecord, ApiError>;

    public type ScoredResponsesForChallengeMigrationInput = {
        scoredResponses : [ScoredResponse];
    };

    public type ScoredResponsesMigrationRecord = {
        migrated : Bool;
    };

    public type ScoredResponsesMigrationResult = Result<ScoredResponsesMigrationRecord, ApiError>;

    public type ScoredResponsesResult = Result<[ScoredResponse], ApiError>;

// Treasury Canister
    public type NotifyDisbursementInput = {
        transactionId : Nat64;
        disbursementAmount : Nat;
    };

    public type NotifyDisbursementRecord = {
        disbursementHandled : Bool;
    };

    public type NotifyDisbursementResult = Result<NotifyDisbursementRecord, ApiError>;

    public type TokenDisbursement = NotifyDisbursementInput and {
        newIcpBalance : Nat;
        creationTimestamp : Nat64;
        sentBy : Principal;
    };

    public type TokenomicsActionType = {
        #Swap;
        #LiquidityProvision;
        #Burn;
        #Stake;
        #Other : Text;
    };

    public type TokenomicsActionTokens = {
        #ICP;
        #FUNNAI;
        #Other : Text;
    };

    public type TokenomicsAction = {
        actionId : Nat64;
        token : TokenomicsActionTokens;
        amount : Nat;
        creationTimestamp : Nat64;
        actionType : TokenomicsActionType;
        additionalToken : ?TokenomicsActionTokens;
        additionalTokenAmount : Nat;
        associatedTransactionId : ?Nat64;
        transactionIdDisbursement : ?Nat64;
        newIcpBalance : Nat;
    };

    public type TokenSwapRecord = {
        token : TokenomicsActionTokens;
        amount : Nat;
        creationTimestamp : Nat64;
        additionalToken : TokenomicsActionTokens;
        additionalTokenAmount : Nat;
    };

    public type TokenSwapResult = Result<TokenSwapRecord, ApiError>;

    public type TokenomicsActionResult = Result<TokenomicsAction, ApiError>;

    //-------------------------------------------------------------------------
// Canister Actors
    public type GameStateCanister_Actor = actor {
        getRandomOpenChallengeTopic : () -> async ChallengeTopicResult;
        addChallenge : (NewChallengeInput) -> async ChallengeAdditionResult;
        getNextSubmissionToJudge : () -> async ChallengeResponseSubmissionWithQueueStatusResult;
        addScoredResponse : (ScoredResponseInput) -> async ScoredResponseResult;
        submitChallengeResponse : (ChallengeResponseSubmissionInput) -> async ChallengeResponseSubmissionMetadataResult;
        getRandomOpenChallenge : () -> async ChallengeResult;
        addMainerAgentCanister : (OfficialMainerAgentCanister) -> async MainerAgentCanisterResult;
        startUploadMainerPromptCache : () -> async Types.StartUploadMainerPromptCacheRecordResult;
        uploadMainerPromptCacheBytesChunk : (UploadMainerPromptCacheBytesChunkInput) -> async Types.StatusCodeRecordResult;
        downloadMainerPromptCacheBytesChunk : (DownloadMainerPromptCacheBytesChunkInput) -> async Types.DownloadMainerPromptCacheBytesChunkRecordResult;
        finishUploadMainerPromptCache : (FinishUploadMainerPromptCacheInput) -> async Types.StatusCodeRecordResult;
        getMainerPromptInfo : (Text) -> async Types.MainerPromptInfoResult;
        startUploadJudgePromptCache : () -> async Types.StartUploadJudgePromptCacheRecordResult;
        uploadJudgePromptCacheBytesChunk : (UploadJudgePromptCacheBytesChunkInput) -> async Types.StatusCodeRecordResult;
        downloadJudgePromptCacheBytesChunk : (DownloadJudgePromptCacheBytesChunkInput) -> async Types.DownloadJudgePromptCacheBytesChunkRecordResult;
        finishUploadJudgePromptCache : (FinishUploadJudgePromptCacheInput) -> async Types.StatusCodeRecordResult;
        getJudgePromptInfo : (Text) -> async Types.JudgePromptInfoResult;
        getMainerCyclesUsedPerResponse : () -> async NatResult;
        getCyclesBurnRate : (Types.CyclesBurnRateDefault) -> async Types.CyclesBurnRateResult;
    };

    public type MainerCreator_Actor = actor {
        createCanister: shared CanisterCreationConfiguration -> async CanisterCreationResult;
        setupCanister: shared SetupCanisterInput -> async CanisterCreationResult;
        upgradeMainerctrl: shared UpgradeMainerctrlInput -> async Types.StatusCodeRecordResult;
        reinstallMainerctrl: shared ReinstallMainerctrlInput -> async Types.StatusCodeRecordResult;
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
        download_prompt_cache_chunk : (DownloadPromptCacheInputRecord) -> async FileDownloadRecordResult;
        upload_prompt_cache_chunk : (UploadPromptCacheInputRecord) -> async FileUploadRecordResult;
        uploaded_prompt_cache_details : (PromptCacheDetailsInputRecord) -> async FileDetailsRecordResult;
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

    // Archive canister
    public type ArchiveChallengesCanister_Actor = actor {
        addChallenges : (ChallengeMigrationInput) -> async ChallengeMigrationResult;
        addMainersAdmin : (MainerBackupInput) -> async MainerBackupResult;
        addSubmissions : (SubmissionMigrationInput) -> async SubmissionMigrationResult;
        addWinnerDeclarations : (WinnerDeclarationMigrationInput) -> async WinnerDeclarationMigrationResult;
        addScoredResponsesForChallenge : (ScoredResponsesForChallengeMigrationInput) -> async ScoredResponsesMigrationResult;
    };

    // Treasury canister
    public type TreasuryCanister_Actor = actor {
        notifyDisbursement : (NotifyDisbursementInput) -> async NotifyDisbursementResult;
    };

    // Liquidity Pool FUNNAI/ICP on ICPSwap
    public let FUNNAI_ICP_LIQUIDITY_POOL_CANISTER_ID = "c5u7l-rqaaa-aaaar-qbqta-cai"; // https://app.icpswap.com/info-swap/pool/details/c5u7l-rqaaa-aaaar-qbqta-cai?path=L2xpcXVpZGl0eT90YWI9VG9wUG9vbHM=&label=TGlxdWlkaXR5
    public let FunnaiIcpLiquidityPool_Actor : LiquidityPool.LIQUIDITY_POOL = actor (FUNNAI_ICP_LIQUIDITY_POOL_CANISTER_ID);

    // ICP Token Ledger
    public let ICP_TOKEN_LEDGER_CANISTER_ID = "ryjl3-tyaaa-aaaaa-aaaba-cai";
    public let IcpLedger_Actor : TokenLedger.TOKEN_LEDGER = actor (ICP_TOKEN_LEDGER_CANISTER_ID);

    // Cycles Minting Canister
    public let CYCLES_MINTING_CANISTER_ID = "rkp4c-7iaaa-aaaaa-aaaca-cai";
    public let CyclesMintingCanister_Actor : CMC.CYCLES_MINTING_CANISTER = actor (CYCLES_MINTING_CANISTER_ID);

    //-------------------------------------------------------------------------
    // Daily Metrics Types for API Canister
    
    // Mainers breakdown by tier (using existing CyclesBurnRateDefault categories)
    // Maps to Low, Mid, High, VeryHigh
    public type MainersTierBreakdown = {
        low: Nat;
        medium: Nat;
        high: Nat;
        very_high: Nat;
        custom: Nat;
    };

    // Daily burn rate with cycles and USD values
    public type DailyBurnRate = {
        cycles: Nat;
        usd: Float;
    };

    // System metrics for a specific day
    public type SystemMetrics = {
        funnai_index: Float;
        daily_burn_rate: DailyBurnRate;
    };

    // Mainers statistics for a specific day
    public type MainersMetrics = {
        totals: {
            created: Nat;
            active: Nat;
            paused: Nat;
            total_cycles: Nat;  // in trillion cycles
        };
        breakdown_by_tier: {
            active: MainersTierBreakdown;
            paused: MainersTierBreakdown;
        };
    };

    // Derived metrics calculated from the raw data
    public type DerivedMetrics = {
        active_percentage: Float;
        paused_percentage: Float;
        avg_cycles_per_mainer: Float;
        burn_rate_per_active_mainer: Float;
        tier_distribution: {
            low: Float;
            medium: Float;
            high: Float;
            very_high: Float;
            custom: Float;
        };
    };

    // Metadata for a daily metric entry
    public type DailyMetricMetadata = {
        date: Text;  // Format: YYYY-MM-DD
        created_at: Text;  // ISO 8601 timestamp
        updated_at: Text;  // ISO 8601 timestamp
    };

    // Complete daily metric entry
    public type DailyMetric = {
        metadata: DailyMetricMetadata;
        system_metrics: SystemMetrics;
        mainers: MainersMetrics;
        derived_metrics: DerivedMetrics;
    };

    // Input type for creating/updating daily metrics (admin use)
    public type DailyMetricInput = {
        date: Text;  // Format: YYYY-MM-DD
        funnai_index: Float;
        daily_burn_rate_cycles: Nat;
        daily_burn_rate_usd: Float;
        total_mainers_created: Nat;
        total_active_mainers: Nat;
        total_paused_mainers: Nat;
        total_cycles_all_mainers: Nat;  // in trillion cycles
        active_low_burn_rate_mainers: Nat;
        active_medium_burn_rate_mainers: Nat;
        active_high_burn_rate_mainers: Nat;
        active_very_high_burn_rate_mainers: Nat;
        active_custom_burn_rate_mainers: Nat;
        paused_low_burn_rate_mainers: Nat;
        paused_medium_burn_rate_mainers: Nat;
        paused_high_burn_rate_mainers: Nat;
        paused_very_high_burn_rate_mainers: Nat;
        paused_custom_burn_rate_mainers: Nat;
    };

    // Input type for partial updates (admin use)
    public type DailyMetricUpdateInput = {
        funnai_index: ?Float;
        daily_burn_rate_cycles: ?Nat;
        daily_burn_rate_usd: ?Float;
        total_mainers_created: ?Nat;
        total_active_mainers: ?Nat;
        total_paused_mainers: ?Nat;
        total_cycles_all_mainers: ?Nat;
        active_low_burn_rate_mainers: ?Nat;
        active_medium_burn_rate_mainers: ?Nat;
        active_high_burn_rate_mainers: ?Nat;
        active_very_high_burn_rate_mainers: ?Nat;
        active_custom_burn_rate_mainers: ?Nat;
        paused_low_burn_rate_mainers: ?Nat;
        paused_medium_burn_rate_mainers: ?Nat;
        paused_high_burn_rate_mainers: ?Nat;
        paused_very_high_burn_rate_mainers: ?Nat;
        paused_custom_burn_rate_mainers: ?Nat;
    };

    // Input type for update endpoint with date and update data
    public type UpdateDailyMetricAdminInput = {
        date: Text;
        input: DailyMetricUpdateInput;
    };

    // Query parameters for retrieving daily metrics
    public type DailyMetricsQuery = {
        start_date: ?Text;  // Optional start date (YYYY-MM-DD)
        end_date: ?Text;    // Optional end date (YYYY-MM-DD)
        limit: ?Nat;        // Optional limit on number of results
    };

    // Period information for query responses
    public type PeriodInfo = {
        start_date: Text;
        end_date: Text;
        total_days: Nat;
    };

    // Response format for public daily metrics queries
    public type DailyMetricsResponse = {
        period: PeriodInfo;
        daily_metrics: [DailyMetric];
    };

    // Result types for API responses
    public type DailyMetricResult = Result<DailyMetric, ApiError>;
    public type DailyMetricsResult = Result<DailyMetricsResponse, ApiError>;
};
