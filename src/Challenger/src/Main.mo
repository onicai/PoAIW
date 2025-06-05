import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import D "mo:base/Debug";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Bool "mo:base/Bool";
import List "mo:base/List";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Time "mo:base/Time";
import { print } = "mo:base/Debug";
import { setTimer; recurringTimer } = "mo:base/Timer";
import Timer "mo:base/Timer";
import Cycles "mo:base/ExperimentalCycles";

import Types "../../common/Types";
import Constants "../../common/Constants";
import ICManagementCanister "../../common/ICManagementCanister";
import Utils "Utils";

actor class ChallengerCtrlbCanister() {

    let IC0 : ICManagementCanister.IC_Management = actor ("aaaaa-aa");

    public shared query (msg) func whoami() : async Principal {
        return msg.caller;
    };

    // Function to verify that canister is up & running
    public shared query func health() : async Types.StatusCodeRecordResult {
        return #Ok({ status_code = 200 });
    };

    // Function to verify that canister is ready for inference
    public shared (msg) func ready() : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        for (llmCanister in llmCanisters.vals()) {
            try {
                let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.ready();
                switch (statusCodeRecordResult) {
                    case (#Err(_)) { return statusCodeRecordResult };
                    case (_) {
                        // If it's not an error, do nothing and continue the loop
                    };
                };
            } catch (_) {
                // Handle errors, such as llm canister not responding
                return #Err(#Other("Failed to call ready endpoint of llm canister = " # Principal.toText(Principal.fromActor(llmCanister))));
            };
        };
        return #Ok({ status_code = 200 });
    };

    // Admin function to verify that caller is a controller of this canister
    public shared query (msg) func amiController() : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        return #Ok({ status_code = 200 });
    };

    // Orthogonal Persisted Data storage

    stable var GAME_STATE_CANISTER_ID : Text = "b77ix-eeaaa-aaaaa-qaada-cai"; // local dev: "b77ix-eeaaa-aaaaa-qaada-cai";
    
    stable var gameStateCanisterActor = actor (GAME_STATE_CANISTER_ID) : Types.GameStateCanister_Actor;

    public shared (msg) func setGameStateCanisterId(_game_state_canister_id : Text) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        GAME_STATE_CANISTER_ID := _game_state_canister_id;
        gameStateCanisterActor := actor (GAME_STATE_CANISTER_ID);
        return #Ok({ status_code = 200 });
    };

    public query (msg) func getGameStateCanisterId() : async Text {
        if (not Principal.isController(msg.caller)) {
            return "#Err(#StatusCode(401))";
        };

        return GAME_STATE_CANISTER_ID;
    };

    // timer ID, so we can stop it after starting
    stable var recurringTimerId : ?Timer.TimerId = null;

    // Record of all generated challenges
    stable var generatedChallenges : List.List<Types.GeneratedChallenge> = List.nil<Types.GeneratedChallenge>();

    private func putGeneratedChallenge(challengeEntry : Types.GeneratedChallenge) : Bool {
        generatedChallenges := List.push<Types.GeneratedChallenge>(challengeEntry, generatedChallenges);
        return true;
    };

    private func getGeneratedChallenge(generationId : Text) : ?Types.GeneratedChallenge {
        return List.find<Types.GeneratedChallenge>(generatedChallenges, func(challengeEntry : Types.GeneratedChallenge) : Bool { challengeEntry.generationId == generationId });
    };

    private func getGeneratedChallenges() : [Types.GeneratedChallenge] {
        return List.toArray<Types.GeneratedChallenge>(generatedChallenges);
    };

    private func removeGeneratedChallenge(generationId : Text) : Bool {
        generatedChallenges := List.filter(generatedChallenges, func(challengeEntry : Types.GeneratedChallenge) : Bool { challengeEntry.generationId != generationId });
        return true;
    };

    public shared query (msg) func getChallengesAdmin() : async Types.GeneratedChallengesResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let challenges : [Types.GeneratedChallenge] = getGeneratedChallenges();
        return #Ok(challenges);
    };

    public query (msg) func getChallengesListAdmin() : async List.List<Types.GeneratedChallenge> {
        if (not Principal.isController(msg.caller)) {
            return List.nil<Types.GeneratedChallenge>();
        };

        return generatedChallenges;
    };

    // Round-robin load balancer for LLM canisters to call
    private var roundRobinIndex : Nat = 0;
    private var roundRobinUseAll : Bool = true;
    private var roundRobinLLMs : Nat = 0; // Only used when roundRobinUseAll is false

    // -------------------------------------------------------------------------------
    // The C++ LLM canisters that can be called

    private var llmCanisters : Buffer.Buffer<Types.LLMCanister> = Buffer.fromArray([]);

    // Resets llmCanisters
    public shared (msg) func reset_llm_canisters() : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        llmCanisters.clear();
        return #Ok({ status_code = 200 });
    };

    // Adds an llmCanister
    public shared (msg) func add_llm_canister(llmCanisterIdRecord : Types.CanisterIDRecord) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        _add_llm_canister_id(llmCanisterIdRecord);
    };

    private func _add_llm_canister_id(llmCanisterIdRecord : Types.CanisterIDRecord) : Types.StatusCodeRecordResult {
        let llmCanister = actor (llmCanisterIdRecord.canister_id) : Types.LLMCanister;
        D.print("Challenger: Inside function _add_llm_canister_id. Adding llm: " # Principal.toText(Principal.fromActor(llmCanister)));
        llmCanisters.add(llmCanister);

        // Print content of the llmCanisters Buffer:
        D.print("Challenger: Content of llmCanisters after addition: ");
        Buffer.iterate(
            llmCanisters,
            func(canister : Types.LLMCanister) : () {
                D.print("Challenger: Canister ID: " # Principal.toText(Principal.fromActor(canister)));
            },
        );
        return #Ok({ status_code = 200 });
    };

    // Admin function to verify that challenger_ctrlb_canister is a controller of all the llm canisters
    public shared (msg) func checkAccessToLLMs() : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };

        // Call all the llm canisters to verify that challenger_ctrlb_canister is a controller
        for (llmCanister in llmCanisters.vals()) {
            try {
                let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.check_access();
                switch (statusCodeRecordResult) {
                    case (#Err(_)) { return statusCodeRecordResult };
                    case (_) {
                        // If it's not an error, do nothing and continue the loop
                    };
                };
            } catch (_) {
                // Handle errors, such as llm canister not responding
                return #Err(#Other("Call failed to llm canister = " # Principal.toText(Principal.fromActor(llmCanister))));
            };
        };
        return #Ok({ status_code = 200 });
    };

    // Admin function to set roundRobinLLMs
    public shared (msg) func setRoundRobinLLMs(_roundRobinLLMs : Nat) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        roundRobinUseAll := false;
        roundRobinLLMs := _roundRobinLLMs;
        roundRobinIndex := 0;

        return #Ok({ status_code = 200 });
    };

    // Endpoint to generate a new challenge
    public shared (msg) func generateNewChallenge() : async Types.GeneratedChallengeResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };

        let generatedChallengeOutput : Types.GeneratedChallengeResult = await generateChallenge();
        return generatedChallengeOutput;
    };

    private func getChallengeTopicFromGameStateCanister() : async Types.ChallengeTopicResult {
        D.print("Challenger:  calling getRandomOpenChallengeTopic of gameStateCanisterActor = " # Principal.toText(Principal.fromActor(gameStateCanisterActor)));
        let result : Types.ChallengeTopicResult = await gameStateCanisterActor.getRandomOpenChallengeTopic();
        D.print("Challenger:  getRandomOpenChallengeTopic returned.");
        return result;
    };

    private func generateChallenge() : async Types.GeneratedChallengeResult {
        // Get the next topic to generate a Challenge for
        
        D.print("Challenger: generateChallenge - calling getChallengeTopicFromGameStateCanister.");
        let challengeTopicResult : Types.ChallengeTopicResult = await getChallengeTopicFromGameStateCanister();
        D.print("Challenger: generateChallenge - received challengeResult from getChallengeTopicFromGameStateCanister: " # debug_show (challengeTopicResult));
        switch (challengeTopicResult) {
            case (#Err(error)) {
                D.print("Challenger: generateChallenge - challengeTopicResult error : " # debug_show (error));
                return #Err(error);
            };
            case (#Ok(challengeTopic : Types.ChallengeTopic)) {
                D.print("Challenger: generateChallenge - challengeTopic = " # debug_show(challengeTopic));

                let generatedChallengeOutput : Types.GeneratedChallengeResult = await challengeGenerationDoIt_(challengeTopic);

                D.print("Challenger: generateChallenge generatedChallengeOutput");
                print(debug_show (generatedChallengeOutput));
                switch (generatedChallengeOutput) {
                    case (#Err(error)) {
                        D.print("Challenger: generateChallenge generatedChallengeOutput error");
                        print(debug_show (error));
                        return #Err(error);
                    };
                    case (#Ok(generatedChallenge)) {
                        // Generate the mAInerPrompt for this challenge, including the LLM's prompt-cache
                        let mainerPromptGenerationInput: Types.MainerPromptGenerationInput = {
                            generatedChallenge : Types.GeneratedChallenge = generatedChallenge;
                            chunkSizePrompCacheDownload : Nat64 = 2000000; // ~1.9 MB
                        };
                        let mainerPromptGenerationRecordResult : Types.MainerPromptGenerationRecordResult = await mAInerPromptGenerationDoIt_(mainerPromptGenerationInput);

                        var mainerPromptId : Text = "";
                        switch (mainerPromptGenerationRecordResult) {
                            case (#Err(error)) {
                                D.print("Challenger: generateChallenge mAInerPromptGenerationDoIt_ error");
                                print(debug_show (error));
                                return #Err(error);
                            };
                            case (#Ok(mainerPromptGenerationRecord)) {
                                let mainerPrompt : Types.MainerPrompt = mainerPromptGenerationRecord.mainerPrompt;
                                // Upload the mAInerPrompt to the GameState
                                let startUploadMainerPromptCacheRecordResult : Types.StartUploadMainerPromptCacheRecordResult = await gameStateCanisterActor.startUploadMainerPromptCache();
                                switch (startUploadMainerPromptCacheRecordResult) {
                                    case (#Err(error)) {
                                        D.print("Challenger: generateChallenge startUploadMainerPromptCache error" # debug_show (error));
                                        return #Err(error);
                                    };
                                    case (#Ok(startUploadMainerPromptCacheRecord)) {
                                        mainerPromptId := startUploadMainerPromptCacheRecord.mainerPromptId;
                                        D.print("Challenger: generateChallenge - start upload of mainer prompt cache");
                                        // For progress reporting
                                        var promptCacheUploadProgress : Nat8 = 0;
                                        let promptCacheUploadProgressInterval : Nat = 10; // 10% progress interval

                                        var chunkSize : Nat = 0;
                                        // var offset : Nat = 0;
                                        var nextChunk : [Nat8] = [];
                                        var chunkCount : Nat = 0;
                                        let totalChunks : Nat = mainerPrompt.promptCacheChunks.size();
                                        var nextProgressThreshold : Nat = 0;

                                        for (chunk in mainerPrompt.promptCacheChunks.vals()) {
                                            chunkSize := nextChunk.size();
                                            let uploadMainerPromptCacheBytesChunkInput : Types.UploadMainerPromptCacheBytesChunkInput = {
                                                mainerPromptId : Text = mainerPromptId;
                                                bytesChunk : Blob = chunk;
                                                chunkID : Nat = chunkCount;
                                            };

                                            var progress : Nat = (chunkCount * 100) / totalChunks; // Integer division rounds down
                                            if (chunkCount + 1 == totalChunks) {
                                                progress := 100; // Set to 100% for the last chunk
                                            };
                                            if (progress >= nextProgressThreshold) {
                                                promptCacheUploadProgress := Nat8.fromNat(nextProgressThreshold); // Set to 0, 10, 20, ..., 100
                                                D.print("Challenger: generateChallenge - uploading mAIner prompt cache chunk " # debug_show (chunkCount) # "(promptCacheUploadProgress = " # debug_show (promptCacheUploadProgress) # "%)");
                                                nextProgressThreshold += promptCacheUploadProgressInterval;
                                            };
                                            chunkCount := chunkCount + 1;
                                            
                                            var delay : Nat = 2_000_000_000; // 2 seconds
                                            let maxAttempts : Nat = 8;
                                            let statusCodeRecordResult: Types.StatusCodeRecordResult = await retryGameStateMainerPromptCacheChunkUploadWithDelay(gameStateCanisterActor, uploadMainerPromptCacheBytesChunkInput, maxAttempts, delay);
                                            switch (statusCodeRecordResult) {
                                                case (#Err(error)) {
                                                    D.print("Challenger: generateChallenge -  ERROR during upload of mAIner prompt cache chunk - statusCodeRecordResult:" # debug_show (statusCodeRecordResult));
                                                    return #Err(error);
                                                };
                                                case (#Ok(_)) {
                                                    // all good, continue with next chunk
                                                    D.print("Challenger: generateChallenge - upload of mAIner prompt cache chunk successful: " # debug_show (statusCodeRecordResult));
                                                };
                                            };
                                        };

                                        let finishUploadMainerPromptCacheInput : Types.FinishUploadMainerPromptCacheInput = {
                                            mainerPromptId : Text = mainerPromptId;
                                            promptText: Text = mainerPrompt.promptText;
                                            promptCacheSha256: Text = mainerPrompt.promptCacheSha256;
                                            promptCacheFilename: Text = mainerPrompt.promptCacheFilename;
                                        };
                                        let finishUploadMainerPromptCacheRecordResult : Types.StatusCodeRecordResult = await gameStateCanisterActor.finishUploadMainerPromptCache(finishUploadMainerPromptCacheInput);
                                        switch (finishUploadMainerPromptCacheRecordResult) {
                                            case (#Err(error)) {
                                                D.print("Challenger: generateChallenge -  ERROR during call to gameStateCanisterActor.finishUploadMainerPromptCacheRecordResult - statusCodeRecordResult:" # debug_show (error));
                                                return #Err(error);
                                            };
                                            case (#Ok(finishUploadMainerPromptCacheRecord)) {
                                                // all good, done uploading the mAIner prompt cache
                                                D.print("Challenger: generateChallenge - call to gameStateCanisterActor.finishUploadMainerPromptCacheRecordResult successful: " # debug_show (finishUploadMainerPromptCacheRecord));
                                            };
                                        };
                                    };
                                };
                            };
                        };
                        // Generate the judgePrompt for this challenge, including the LLM's prompt-cache
                        let judgePromptGenerationInput: Types.JudgePromptGenerationInput = {
                            generatedChallenge : Types.GeneratedChallenge = generatedChallenge;
                            chunkSizePrompCacheDownload : Nat64 = 2000000; // ~1.9 MB
                        };
                        let judgePromptGenerationRecordResult : Types.JudgePromptGenerationRecordResult = await judgePromptGenerationDoIt_(judgePromptGenerationInput);

                        switch (judgePromptGenerationRecordResult) {
                            case (#Err(error)) {
                                D.print("Challenger: generateChallenge judgePromptGenerationDoIt_ error");
                                print(debug_show (error));
                                return #Err(error);
                            };
                            case (#Ok(judgePromptGenerationRecord)) {
                                let judgePrompt : Types.JudgePrompt = judgePromptGenerationRecord.judgePrompt;
                                // Upload the judgePrompt to the GameState
                                let startUploadJudgePromptCacheRecordResult : Types.StartUploadJudgePromptCacheRecordResult = await gameStateCanisterActor.startUploadJudgePromptCache();
                                switch (startUploadJudgePromptCacheRecordResult) {
                                    case (#Err(error)) {
                                        D.print("Challenger: generateChallenge startUploadJudgePromptCache error" # debug_show (error));
                                        return #Err(error);
                                    };
                                    case (#Ok(startUploadJudgePromptCacheRecord)) {
                                        let judgePromptId : Text = startUploadJudgePromptCacheRecord.judgePromptId;
                                        D.print("Challenger: generateChallenge - start upload of judge prompt cache");
                                        // For progress reporting
                                        var promptCacheUploadProgress : Nat8 = 0;
                                        let promptCacheUploadProgressInterval : Nat = 10; // 10% progress interval

                                        var chunkSize : Nat = 0;
                                        // var offset : Nat = 0;
                                        var nextChunk : [Nat8] = [];
                                        var chunkCount : Nat = 0;
                                        let totalChunks : Nat = judgePrompt.promptCacheChunks.size();
                                        var nextProgressThreshold : Nat = 0;

                                        for (chunk in judgePrompt.promptCacheChunks.vals()) {
                                            chunkSize := nextChunk.size();
                                            let uploadJudgePromptCacheBytesChunkInput : Types.UploadJudgePromptCacheBytesChunkInput = {
                                                judgePromptId : Text = judgePromptId;
                                                bytesChunk : Blob = chunk;
                                                chunkID : Nat = chunkCount;
                                            };

                                            var progress : Nat = (chunkCount * 100) / totalChunks; // Integer division rounds down
                                            if (chunkCount + 1 == totalChunks) {
                                                progress := 100; // Set to 100% for the last chunk
                                            };
                                            if (progress >= nextProgressThreshold) {
                                                promptCacheUploadProgress := Nat8.fromNat(nextProgressThreshold); // Set to 0, 10, 20, ..., 100
                                                D.print("Challenger: generateChallenge - uploading Judge prompt cache chunk " # debug_show (chunkCount) # "(promptCacheUploadProgress = " # debug_show (promptCacheUploadProgress) # "%)");
                                                nextProgressThreshold += promptCacheUploadProgressInterval;
                                            };
                                            chunkCount := chunkCount + 1;
                                            
                                            var delay : Nat = 2_000_000_000; // 2 seconds
                                            let maxAttempts : Nat = 8;
                                            let statusCodeRecordResult: Types.StatusCodeRecordResult = await retryGameStateJudgePromptCacheChunkUploadWithDelay(gameStateCanisterActor, uploadJudgePromptCacheBytesChunkInput, maxAttempts, delay);
                                            switch (statusCodeRecordResult) {
                                                case (#Err(error)) {
                                                    D.print("Challenger: generateChallenge -  ERROR during upload of Judge prompt cache chunk - statusCodeRecordResult:" # debug_show (statusCodeRecordResult));
                                                    return #Err(error);
                                                };
                                                case (#Ok(_)) {
                                                    // all good, continue with next chunk
                                                    D.print("Challenger: generateChallenge - upload of Judge prompt cache chunk successful: " # debug_show (statusCodeRecordResult));
                                                };
                                            };
                                        };

                                        let finishUploadJudgePromptCacheInput : Types.FinishUploadJudgePromptCacheInput = {
                                            judgePromptId : Text = judgePromptId;
                                            promptText: Text = judgePrompt.promptText;
                                            promptCacheSha256: Text = judgePrompt.promptCacheSha256;
                                            promptCacheFilename: Text = judgePrompt.promptCacheFilename;
                                        };
                                        let finishUploadJudgePromptCacheRecordResult : Types.StatusCodeRecordResult = await gameStateCanisterActor.finishUploadJudgePromptCache(finishUploadJudgePromptCacheInput);
                                        switch (finishUploadJudgePromptCacheRecordResult) {
                                            case (#Err(error)) {
                                                D.print("Challenger: generateChallenge -  ERROR during call to gameStateCanisterActor.finishUploadJudgePromptCacheRecordResult - statusCodeRecordResult:" # debug_show (error));
                                                return #Err(error);
                                            };
                                            case (#Ok(finishUploadJudgePromptCacheRecord)) {
                                                // all good, done uploading the Judge prompt cache
                                                D.print("Challenger: generateChallenge - call to gameStateCanisterActor.finishUploadJudgePromptCacheRecordResult successful: " # debug_show (finishUploadJudgePromptCacheRecord));
                                            };
                                        };

                                        // The mAiner and the Judge prompts, with their prompt cache, are now uploaded to the GameState canister
                                        // Store challenge, which references the mAIner & Judge prompt
                                        let pushResult = putGeneratedChallenge(generatedChallenge);

                                        // Add challenge to Game State canister
                                        let newChallenge : Types.NewChallengeInput = {
                                            challengeTopic : Text = challengeTopic.challengeTopic;
                                            challengeTopicId : Text = challengeTopic.challengeTopicId;
                                            challengeTopicCreationTimestamp : Nat64 = challengeTopic.challengeTopicCreationTimestamp;
                                            challengeTopicStatus : Types.ChallengeTopicStatus = challengeTopic.challengeTopicStatus;
                                            cyclesGenerateChallengeGsChctrl : Nat = challengeTopic.cyclesGenerateChallengeGsChctrl;
                                            cyclesGenerateChallengeChctrlChllm : Nat = challengeTopic.cyclesGenerateChallengeChctrlChllm;
                                            challengeQuestion : Text = generatedChallenge.generatedChallengeText;
                                            challengeQuestionSeed : Nat32 = generatedChallenge.generationSeed;
                                            mainerPromptId : Text = mainerPromptId;
                                            mainerMaxContinueLoopCount : Nat = 3;
                                            mainerNumTokens : Nat64 = 1024;
                                            mainerTemp : Float = 0.8;
                                            judgePromptId : Text = judgePromptId;
                                        };

                                        D.print("Challenger: calling addChallenge of gameStateCanisterActor = " # Principal.toText(Principal.fromActor(gameStateCanisterActor)));
                                        let additionResult : Types.ChallengeAdditionResult = await gameStateCanisterActor.addChallenge(newChallenge);
                                        D.print("Challenger: generateChallenge generatedChallengeOutput Ok additionResult");
                                        print(debug_show (additionResult));
                                        switch (additionResult) {
                                            case (#Err(error)) {
                                                // TODO - Error Handling (e.g. put into queue and try again later)
                                            };
                                            case (#Ok(addedChallenge)) {
                                                // TODO - Design: decide if returned challenge entry should be stored as well
                                            };
                                        };
                                        return generatedChallengeOutput;
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
    };

    // Uploads a chunk of the mAIner prompt cache file to the GameState canister
    private func retryGameStateMainerPromptCacheChunkUploadWithDelay(gameStateCanisterActor : Types.GameStateCanister_Actor, uploadMainerPromptCacheBytesChunkInput : Types.UploadMainerPromptCacheBytesChunkInput, attempts : Nat, delay : Nat) : async Types.StatusCodeRecordResult {
        if (attempts > 0) {
            try {
                D.print("Challenger: calling gameStateCanisterActor.uploadMainerPromptCacheBytesChunk for mainerPromptId, chunkID = " # debug_show (uploadMainerPromptCacheBytesChunkInput.mainerPromptId) # ", " # debug_show (uploadMainerPromptCacheBytesChunkInput.chunkID));
                let statusCodeRecordResult : Types.StatusCodeRecordResult = await gameStateCanisterActor.uploadMainerPromptCacheBytesChunk(uploadMainerPromptCacheBytesChunkInput);
                return statusCodeRecordResult;
                
            } catch (e) {
                D.print("gameStateCanisterActor.uploadMainerPromptCacheBytesChunk failed with catch error " # Error.message(e) # ", retrying in " # debug_show(delay) # " nanoseconds");
                
                // TODO - Implementation: introduce a delay using a timer...
                // Just retry immediately with decremented attempts
                return await retryGameStateMainerPromptCacheChunkUploadWithDelay(gameStateCanisterActor, uploadMainerPromptCacheBytesChunkInput, attempts - 1, delay);
            };
        } else {
            D.print("Max retry attempts reached");
            return #Err(#Other("Max retry attempts reached"));
        };
    };

    // Downloads a chunk of the mAIner prompt cache file from the LLM canister
    private func retryLlmMainerPromptCacheChunkDownloadWithDelay(llmCanister : Types.LLMCanister, downloadPromptCacheInputRecord : Types.DownloadPromptCacheInputRecord, attempts : Nat, delay : Nat) : async Types.FileDownloadRecordResult {
        if (attempts > 0) {
            try {
                D.print("Challenger: calling gameStateCanisterActor.download_prompt_cache_chunk for offset = " # debug_show (downloadPromptCacheInputRecord.offset) );
                let fileDownloadRecordResult : Types.FileDownloadRecordResult = await llmCanister.download_prompt_cache_chunk(downloadPromptCacheInputRecord);
                return fileDownloadRecordResult;
                
            } catch (e) {
                D.print("gameStateCanisterActor.download_prompt_cache_chunk failed with catch error " # Error.message(e) # ", retrying in " # debug_show(delay) # " nanoseconds");
                
                // TODO - Implementation: introduce a delay using a timer...
                // Just retry immediately with decremented attempts
                return await retryLlmMainerPromptCacheChunkDownloadWithDelay(llmCanister, downloadPromptCacheInputRecord, attempts - 1, delay);
            };
        } else {
            D.print("Max retry attempts reached");
            return #Err(#Other("Max retry attempts reached"));
        };
    };

    // This function is identical to mAIner.respondToChallengeDoIt_ , up to the prompt ingestion part
    private func mAInerPromptGenerationDoIt_(mainerPromptGenerationInput : Types.MainerPromptGenerationInput) : async Types.MainerPromptGenerationRecordResult {
        let maxContinueLoopCount : Nat = 6; // After this many calls to run_update, we stop.
        let num_tokens : Nat64 = 1; // We do NOT want the LLM to generate any tokens, just to ingest the prompt
        let temp : Float = 0.8;

        var promptRepetitive : Text = "<|im_start|>user\nAnswer the following question as brief as possible. This is the question: ";
        var prompt : Text = promptRepetitive # mainerPromptGenerationInput.generatedChallenge.generatedChallengeText # "\n<|im_end|>\n<|im_start|>assistant\n";
        let promptText : Text = prompt; // for sending in return

        let llmCanister = _getRoundRobinCanister();

        D.print("Challenger: mAInerPromptGenerationDoIt_ - llmCanister = " # Principal.toText(Principal.fromActor(llmCanister)));

        // Check health of llmCanister
        // D.print("Challenger: mAInerPromptGenerationDoIt_ - calling health endpoint of LLM");
        let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.health();
        // D.print("Challenger: mAInerPromptGenerationDoIt_ - returned from health endpoint of LLM with : ");
        // D.print("Challenger: mAInerPromptGenerationDoIt_ - statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
        switch (statusCodeRecordResult) {
            case (#Err(error)) {
                return #Err(error);
            };
            case (#Ok(_statusCodeRecord)) {
                D.print("Challenger: mAInerPromptGenerationDoIt_ - LLM is healthy");
            };
        };

        let generationId : Text = await Utils.newRandomUniqueId();

        // Use the generationId to create a highly variable seed for the LLM
        let seed : Nat32 = Utils.getRandomLlmSeed(generationId);
        D.print("Challenger: mAInerPromptGenerationDoIt_ - seed = " # debug_show(seed));

        var generationOutput : Text = "";
        let generationPrompt : Text = prompt;

        // The prompt cache file
        let promptCache : Text = generationId # ".cache";

        // Start the generation for this challengeQueueInput
        var num_update_calls : Nat64 = 0;

        // data returned from new_chat
        var status_code : Nat16 = 0;
        var output : Text = "";
        var conversation : Text = "";
        var error : Text = "";
        var prompt_remaining : Text = "";
        var generated_eog : Bool = false;

        // ----------------------------------------------------------------------
        // Step 0
        // Restore a previously saved prompt cache file
        let promptSaveCache : Text = Nat32.toText(Text.hash(promptRepetitive)) # ".cache";
        var foundPromptSaveCache : Bool = false;

        try {
            let copyPromptCacheInputRecord : Types.CopyPromptCacheInputRecord = { 
                from = promptSaveCache; 
                to =  promptCache
            };
            D.print("Challenger: mAInerPromptGenerationDoIt_ - calling copy_prompt_cache to restore a previously saved promptCache if it exists. promptSaveCache: " # promptSaveCache);
            num_update_calls += 1;
            let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.copy_prompt_cache(copyPromptCacheInputRecord);
            D.print("Challenger: mAInerPromptGenerationDoIt_ - returned from copy_prompt_cache with statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
            switch (statusCodeRecordResult) {
                case (#Err(_)) {
                    foundPromptSaveCache := false;
                };
                case (#Ok(_)) {
                    foundPromptSaveCache := true;
                };
            };
        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("Challenger: mAInerPromptGenerationDoIt_ - catch error when calling copy_prompt_cache : ");
            D.print("Challenger: mAInerPromptGenerationDoIt_ - error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to copy_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };

        // ----------------------------------------------------------------------
        // Step 1
        // Call new_chat - this resets the prompt-cache for this conversation
        try {
            let args : [Text] = [
                "--prompt-cache",
                promptCache,
            ];
            let inputRecord : Types.InputRecord = { args = args };
            D.print("Challenger: mAInerPromptGenerationDoIt_ - calling new_chat...");
            // D.print(debug_show (args));
            num_update_calls += 1;
            let outputRecordResult : Types.OutputRecordResult = await llmCanister.new_chat(inputRecord);
            // D.print("Challenger: mAInerPromptGenerationDoIt_ - returned from new_chat with outputRecordResult: ");
            // D.print(debug_show (outputRecordResult));

            switch (outputRecordResult) {
                case (#Err(error)) {
                    return #Err(error);
                };
                case (#Ok(outputRecord)) {
                    // the generated tokens
                    status_code := outputRecord.status_code;
                    output := outputRecord.output;
                    conversation := outputRecord.conversation;
                    error := outputRecord.error;
                    prompt_remaining := outputRecord.prompt_remaining;
                    generated_eog := outputRecord.generated_eog;
                    // D.print("Challenger: mAInerPromptGenerationDoIt_ - status_code      : " # debug_show (status_code));
                    D.print("Challenger: mAInerPromptGenerationDoIt_ - output           : " # debug_show (output));
                    // D.print("Challenger: mAInerPromptGenerationDoIt_ - conversation     : " # debug_show (conversation));
                    // D.print("Challenger: mAInerPromptGenerationDoIt_ - error            : " # debug_show (error));
                    // D.print("Challenger: mAInerPromptGenerationDoIt_ - prompt_remaining : " # debug_show (prompt_remaining));
                    // D.print("Challenger: mAInerPromptGenerationDoIt_ - generated_eog    : " # debug_show (generated_eog));
                };
            };
        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("Challenger: mAInerPromptGenerationDoIt_ - catch error when calling new_chat : ");
            D.print("Challenger: mAInerPromptGenerationDoIt_ - error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to new_chat of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };

        // ----------------------------------------------------------------------
        // Step 2
        // (A) Ingest the prompt into the prompt-cache, using multiple update calls
        //      (-) Repeat call with full prompt until `prompt_remaining` in the response is empty.
        //      (-) The first part of the challengeQueueInput will be generated too.
        // -> Stop here, we only need the prompt cache after the prompt ingestion

        // Avoid endless loop by limiting the number of iterations
        var continueLoopCount : Nat = 0;
        label continueLoop while (continueLoopCount < maxContinueLoopCount) {
            try {
                let args = [
                    "--prompt-cache",
                    promptCache,
                    "--prompt-cache-all",
                    "--simple-io",
                    "--no-display-prompt", // only return generated text
                    "-n",
                    Nat64.toText(num_tokens),
                    "--seed",
                    Nat32.toText(seed),
                    "--temp",
                    Float.toText(temp),
                    "-p",
                    prompt,
                ];
                let inputRecord : Types.InputRecord = { args = args };
                D.print("Challenger: mAInerPromptGenerationDoIt_ - calling run_update...");
                // D.print(debug_show (args));
                num_update_calls += 1;
                if (num_update_calls > 30) {
                    D.print("Challenger: mAInerPromptGenerationDoIt_ - too many calls run_update - Breaking out of loop...");
                    break continueLoop; // Protective break for endless loop.
                };
                let outputRecordResult : Types.OutputRecordResult = await llmCanister.run_update(inputRecord);
                // D.print("Challenger: mAInerPromptGenerationDoIt_ - INGESTING PROMPT:returned from run_update with outputRecordResult: ");
                // D.print(debug_show (outputRecordResult));

                switch (outputRecordResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case (#Ok(outputRecord)) {
                        // the generated tokens
                        status_code := outputRecord.status_code;
                        output := outputRecord.output;
                        conversation := outputRecord.conversation;
                        error := outputRecord.error;
                        prompt_remaining := outputRecord.prompt_remaining;
                        generated_eog := outputRecord.generated_eog;
                        // D.print("Challenger: mAInerPromptGenerationDoIt_ - status_code      : " # debug_show (status_code));
                        D.print("Challenger: mAInerPromptGenerationDoIt_ - output           : " # debug_show (output));
                        // D.print("Challenger: mAInerPromptGenerationDoIt_ - conversation     : " # debug_show (conversation));
                        // D.print("Challenger: mAInerPromptGenerationDoIt_ - error            : " # debug_show (error));
                        // D.print("Challenger: mAInerPromptGenerationDoIt_ - prompt_remaining : " # debug_show (prompt_remaining));
                        // D.print("Challenger: mAInerPromptGenerationDoIt_ - generated_eog    : " # debug_show (generated_eog));

                        generationOutput := generationOutput # output;
                        // D.print("Challenger: mAInerPromptGenerationDoIt_ - generationOutput : " # debug_show (generationOutput));

                        if (prompt_remaining == "") {
                            prompt := ""; // Send empty prompt - the prompt ingestion is done.
                            continueLoopCount += 1; // We count the actual generation steps
                            // -----
                            // Prompt ingestion is finished. If it was not yet there, save the prompt cache for reuse with next submission
                            if (not foundPromptSaveCache) {
                                try {
                                    let copyPromptCacheInputRecord : Types.CopyPromptCacheInputRecord = { 
                                        from = promptCache; 
                                        to =  promptSaveCache
                                    };
                                    D.print("Challenger: mAInerPromptGenerationDoIt_ - calling copy_prompt_cache to save the promptCache to promptSaveCache: " # promptSaveCache);
                                    num_update_calls += 1;
                                    let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.copy_prompt_cache(copyPromptCacheInputRecord);
                                    D.print("Challenger: mAInerPromptGenerationDoIt_ - returned from copy_prompt_cache with statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
                                    // We do not care what the result is, as it is just a possible optimization operation
                                } catch (error : Error) {
                                    // Handle errors, such as llm canister not responding
                                    D.print("Challenger: mAInerPromptGenerationDoIt_ - catch error when calling copy_prompt_cache : ");
                                    D.print("Challenger: mAInerPromptGenerationDoIt_ - error: " # Error.message(error));
                                    return #Err(
                                        #Other(
                                            "Failed call to copy_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                                            " with error: " # Error.message(error)
                                        )
                                    );
                                };
                            };
                            break continueLoop; // Exit the loop - the prompt ingestion is done.
                        };
                        if (generated_eog) {
                            break continueLoop; // Exit the loop - the mAIner response is generated.
                        };
                    };
                };
            } catch (error : Error) {
                // Handle errors, such as llm canister not responding
                D.print("Challenger: mAInerPromptGenerationDoIt_ - catch error when calling new_chat : ");
                D.print("Challenger: mAInerPromptGenerationDoIt_ - error: " # Error.message(error));
                return #Err(
                    #Other(
                        "Failed call to run_update of " # Principal.toText(Principal.fromActor(llmCanister)) #
                        " with error: " # Error.message(error)
                    )
                );
            };
        };

        // ----------------------------------------------------------------------
        // Download the prompt cache file from the LLM
        let mainerPromptCacheBuffer : Buffer.Buffer<Blob> = Buffer.Buffer<Blob>(0);
        var downloadDone : Bool = false;
        let maxDownloadCalls : Nat = 100; // protect against an endless loop
        var numDownloadCalls : Nat = 0;
        var offset : Nat64 = 0;
        while (not downloadDone) {
            try {
                let downloadPromptCacheInputRecord : Types.DownloadPromptCacheInputRecord = { 
                    promptcache : Text = promptCache;
                    chunksize : Nat64 = mainerPromptGenerationInput.chunkSizePrompCacheDownload;
                    offset : Nat64 = offset;
                };
                numDownloadCalls += 1;
                if (numDownloadCalls > maxDownloadCalls) {
                    D.print("Challenger: mAInerPromptGenerationDoIt_ - too many calls download_prompt_cache_chunk - Breaking out of loop...");
                    return #Err(#Other("Too many calls to download_prompt_cache_chunk"));
                };
                var delay : Nat = 2_000_000_000; // 2 seconds
                let maxAttempts : Nat = 8;
                let fileDownloadRecordResult : Types.FileDownloadRecordResult = await retryLlmMainerPromptCacheChunkDownloadWithDelay(llmCanister, downloadPromptCacheInputRecord, maxAttempts, delay);

                switch (fileDownloadRecordResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case (#Ok(fileDownloadRecord)) {
                        D.print("Challenger: mAInerPromptGenerationDoIt_ - received a mAIner prompt cache chunk of size: " # debug_show (fileDownloadRecord.chunksize));
                        mainerPromptCacheBuffer.add(fileDownloadRecord.chunk);
                        if (fileDownloadRecord.done) {
                            downloadDone := true;
                        };
                        offset += mainerPromptGenerationInput.chunkSizePrompCacheDownload;
                    };
                };
            } catch (error : Error) {
                // Handle errors, such as llm canister not responding
                D.print("Challenger: mAInerPromptGenerationDoIt_ - catch error when calling download_prompt_cache_chunk : ");
                D.print("Challenger: mAInerPromptGenerationDoIt_ - error: " # Error.message(error));
                return #Err(
                    #Other(
                        "Failed call to download_prompt_cache_chunk of " # Principal.toText(Principal.fromActor(llmCanister)) #
                        " with error: " # Error.message(error)
                    )
                );
            };
        }; 

        // Delete the prompt cache in the LLM
        try {
            let args : [Text] = [
                "--prompt-cache",
                promptCache,
            ];
            let inputRecord : Types.InputRecord = { args = args };
            // D.print("Challenger: mAInerPromptGenerationDoIt_ - calling remove_prompt_cache with args: ");
            // D.print(debug_show (args));
            num_update_calls += 1;
            let outputRecordResult : Types.OutputRecordResult = await llmCanister.remove_prompt_cache(inputRecord);
            // D.print("Challenger: mAInerPromptGenerationDoIt_ - returned from remove_prompt_cache with outputRecordResult: ");
            // D.print(debug_show (outputRecordResult));

        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("Challenger: mAInerPromptGenerationDoIt_ - catch error when calling remove_prompt_cache : ");
            D.print("Challenger: mAInerPromptGenerationDoIt_ - error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to remove_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };


        // ----------------------------------------------------------------------
        // Return the result
        let mainerPrompt: Types.MainerPrompt = {
            promptText : Text = promptText;
            promptCacheChunks : [Blob] = Buffer.toArray<Blob>(mainerPromptCacheBuffer);
            promptCacheSha256 : Text = ""; // TODO - calculate the sha256 hash of the prompt cache
            promptCacheFilename : Text = promptCache;
            promptCacheNumberOfChunks : Nat = mainerPromptCacheBuffer.size();
        };
        let mainerPromptGenerationRecord : Types.MainerPromptGenerationRecord = {
            generationId : Text = generationId;
            generationSeed : Nat32 = seed;
            generatedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            generatedByLlmId : Text = Principal.toText(Principal.fromActor(llmCanister));
            generationPrompt : Text = generationPrompt;
            mainerPrompt: Types.MainerPrompt = mainerPrompt;
        };
        return #Ok(mainerPromptGenerationRecord);
    };

    // Uploads a chunk of the Judge prompt cache file to the GameState canister
    private func retryGameStateJudgePromptCacheChunkUploadWithDelay(gameStateCanisterActor : Types.GameStateCanister_Actor, uploadJudgePromptCacheBytesChunkInput : Types.UploadJudgePromptCacheBytesChunkInput, attempts : Nat, delay : Nat) : async Types.StatusCodeRecordResult {
        if (attempts > 0) {
            try {
                D.print("Challenger: calling gameStateCanisterActor.uploadJudgePromptCacheBytesChunk for judgePromptId, chunkID = " # debug_show (uploadJudgePromptCacheBytesChunkInput.judgePromptId) # ", " # debug_show (uploadJudgePromptCacheBytesChunkInput.chunkID));
                let statusCodeRecordResult : Types.StatusCodeRecordResult = await gameStateCanisterActor.uploadJudgePromptCacheBytesChunk(uploadJudgePromptCacheBytesChunkInput);
                return statusCodeRecordResult;
                
            } catch (e) {
                D.print("gameStateCanisterActor.uploadJudgePromptCacheBytesChunk failed with catch error " # Error.message(e) # ", retrying in " # debug_show(delay) # " nanoseconds");
                
                // TODO - Implementation: introduce a delay using a timer...
                // Just retry immediately with decremented attempts
                return await retryGameStateJudgePromptCacheChunkUploadWithDelay(gameStateCanisterActor, uploadJudgePromptCacheBytesChunkInput, attempts - 1, delay);
            };
        } else {
            D.print("Max retry attempts reached");
            return #Err(#Other("Max retry attempts reached"));
        };
    };

    // Downloads a chunk of the Judge prompt cache file from the LLM canister
    private func retryLlmJudgePromptCacheChunkDownloadWithDelay(llmCanister : Types.LLMCanister, downloadPromptCacheInputRecord : Types.DownloadPromptCacheInputRecord, attempts : Nat, delay : Nat) : async Types.FileDownloadRecordResult {
        if (attempts > 0) {
            try {
                D.print("Challenger: calling gameStateCanisterActor.download_prompt_cache_chunk for offset = " # debug_show (downloadPromptCacheInputRecord.offset) );
                let fileDownloadRecordResult : Types.FileDownloadRecordResult = await llmCanister.download_prompt_cache_chunk(downloadPromptCacheInputRecord);
                return fileDownloadRecordResult;
                
            } catch (e) {
                D.print("gameStateCanisterActor.download_prompt_cache_chunk failed with catch error " # Error.message(e) # ", retrying in " # debug_show(delay) # " nanoseconds");
                
                // TODO - Implementation: introduce a delay using a timer...
                // Just retry immediately with decremented attempts
                return await retryLlmJudgePromptCacheChunkDownloadWithDelay(llmCanister, downloadPromptCacheInputRecord, attempts - 1, delay);
            };
        } else {
            D.print("Max retry attempts reached");
            return #Err(#Other("Max retry attempts reached"));
        };
    };

    // This function is identical to Judge.respondToChallengeDoIt_ , up to the prompt ingestion part
    private func judgePromptGenerationDoIt_(judgePromptGenerationInput : Types.JudgePromptGenerationInput) : async Types.JudgePromptGenerationRecordResult {
        let maxContinueLoopCount : Nat = 6; // After this many calls to run_update, we stop.
        let num_tokens : Nat64 = 1; // We do NOT want the LLM to generate any tokens, just to ingest the prompt
        let seed : Nat32 = 42; // fixed seed for reproducibility
        let temp : Float = 0.0; // zero temperature for deterministic output

        var promptRepetitive : Text = "<|im_start|>system\n" #
        "You grade answers based on its correctness to the question: \n" #
        " \n" #
        "- ";
        var prompt : Text = promptRepetitive # judgePromptGenerationInput.generatedChallenge.generatedChallengeText # "\n" #
        " \n" #
        "Grade the answer between 1 and 5\n" #
        "1 = completely wrong\n" #
        "2 = mostly wrong\n" #
        "3 = partially correct\n" #
        "4 = mostly correct\n" #
        "5 = completely correct\n" #
        " \n" #
        "<|im_end|> \n" #
        "<|im_start|>user\n" #
        "Grade this answer based on its correctness: \n" #
        " \n";

        let promptText : Text = prompt; // for sending in return

        let llmCanister = _getRoundRobinCanister();

        D.print("Challenger: JudgePromptGenerationDoIt_ - llmCanister = " # Principal.toText(Principal.fromActor(llmCanister)));

        // Check health of llmCanister
        // D.print("Challenger: JudgePromptGenerationDoIt_ - calling health endpoint of LLM");
        let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.health();
        // D.print("Challenger: JudgePromptGenerationDoIt_ - returned from health endpoint of LLM with : ");
        // D.print("Challenger: JudgePromptGenerationDoIt_ - statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
        switch (statusCodeRecordResult) {
            case (#Err(error)) {
                return #Err(error);
            };
            case (#Ok(_statusCodeRecord)) {
                D.print("Challenger: JudgePromptGenerationDoIt_ - LLM is healthy");
            };
        };

        let generationId : Text = await Utils.newRandomUniqueId();
        var generationOutput : Text = "";
        let generationPrompt : Text = prompt;

        // The prompt cache file
        let promptCache : Text = generationId # ".cache";

        // Start the generation for this challengeQueueInput
        var num_update_calls : Nat64 = 0;

        // data returned from new_chat
        var status_code : Nat16 = 0;
        var output : Text = "";
        var conversation : Text = "";
        var error : Text = "";
        var prompt_remaining : Text = "";
        var generated_eog : Bool = false;

        // ----------------------------------------------------------------------
        // Step 0
        // Restore a previously saved prompt cache file
        let promptSaveCache : Text = Nat32.toText(Text.hash(promptRepetitive)) # ".cache";
        var foundPromptSaveCache : Bool = false;

        try {
            let copyPromptCacheInputRecord : Types.CopyPromptCacheInputRecord = { 
                from = promptSaveCache; 
                to =  promptCache
            };
            D.print("Challenger: JudgePromptGenerationDoIt_ - calling copy_prompt_cache to restore a previously saved promptCache if it exists. promptSaveCache: " # promptSaveCache);
            num_update_calls += 1;
            let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.copy_prompt_cache(copyPromptCacheInputRecord);
            D.print("Challenger: JudgePromptGenerationDoIt_ - returned from copy_prompt_cache with statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
            switch (statusCodeRecordResult) {
                case (#Err(_)) {
                    foundPromptSaveCache := false;
                };
                case (#Ok(_)) {
                    foundPromptSaveCache := true;
                };
            };
        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("Challenger: JudgePromptGenerationDoIt_ - catch error when calling copy_prompt_cache : ");
            D.print("Challenger: JudgePromptGenerationDoIt_ - error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to copy_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };

        // ----------------------------------------------------------------------
        // Step 1
        // Call new_chat - this resets the prompt-cache for this conversation
        try {
            let args : [Text] = [
                "--prompt-cache",
                promptCache,
            ];
            let inputRecord : Types.InputRecord = { args = args };
            D.print("Challenger: JudgePromptGenerationDoIt_ - calling new_chat...");
            // D.print(debug_show (args));
            num_update_calls += 1;
            let outputRecordResult : Types.OutputRecordResult = await llmCanister.new_chat(inputRecord);
            // D.print("Challenger: JudgePromptGenerationDoIt_ - returned from new_chat with outputRecordResult: ");
            // D.print(debug_show (outputRecordResult));

            switch (outputRecordResult) {
                case (#Err(error)) {
                    return #Err(error);
                };
                case (#Ok(outputRecord)) {
                    // the generated tokens
                    status_code := outputRecord.status_code;
                    output := outputRecord.output;
                    conversation := outputRecord.conversation;
                    error := outputRecord.error;
                    prompt_remaining := outputRecord.prompt_remaining;
                    generated_eog := outputRecord.generated_eog;
                    // D.print("Challenger: JudgePromptGenerationDoIt_ - status_code      : " # debug_show (status_code));
                    D.print("Challenger: JudgePromptGenerationDoIt_ - output           : " # debug_show (output));
                    // D.print("Challenger: JudgePromptGenerationDoIt_ - conversation     : " # debug_show (conversation));
                    // D.print("Challenger: JudgePromptGenerationDoIt_ - error            : " # debug_show (error));
                    // D.print("Challenger: JudgePromptGenerationDoIt_ - prompt_remaining : " # debug_show (prompt_remaining));
                    // D.print("Challenger: JudgePromptGenerationDoIt_ - generated_eog    : " # debug_show (generated_eog));
                };
            };
        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("Challenger: JudgePromptGenerationDoIt_ - catch error when calling new_chat : ");
            D.print("Challenger: JudgePromptGenerationDoIt_ - error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to new_chat of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };

        // ----------------------------------------------------------------------
        // Step 2
        // (A) Ingest the prompt into the prompt-cache, using multiple update calls
        //      (-) Repeat call with full prompt until `prompt_remaining` in the response is empty.
        //      (-) The first part of the challengeQueueInput will be generated too.
        // -> Stop here, we only need the prompt cache after the prompt ingestion

        // Avoid endless loop by limiting the number of iterations
        var continueLoopCount : Nat = 0;
        label continueLoop while (continueLoopCount < maxContinueLoopCount) {
            try {
                let args = [
                    "--prompt-cache",
                    promptCache,
                    "--prompt-cache-all",
                    "--simple-io",
                    "--no-display-prompt", // only return generated text
                    "-n",
                    Nat64.toText(num_tokens),
                    "--seed",
                    Nat32.toText(seed),
                    "--temp",
                    Float.toText(temp),
                    "-p",
                    prompt,
                ];
                let inputRecord : Types.InputRecord = { args = args };
                D.print("Challenger: JudgePromptGenerationDoIt_ - calling run_update...");
                // D.print(debug_show (args));
                num_update_calls += 1;
                if (num_update_calls > 30) {
                    D.print("Challenger: JudgePromptGenerationDoIt_ - too many calls run_update - Breaking out of loop...");
                    break continueLoop; // Protective break for endless loop.
                };
                let outputRecordResult : Types.OutputRecordResult = await llmCanister.run_update(inputRecord);
                // D.print("Challenger: JudgePromptGenerationDoIt_ - INGESTING PROMPT:returned from run_update with outputRecordResult: ");
                // D.print(debug_show (outputRecordResult));

                switch (outputRecordResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case (#Ok(outputRecord)) {
                        // the generated tokens
                        status_code := outputRecord.status_code;
                        output := outputRecord.output;
                        conversation := outputRecord.conversation;
                        error := outputRecord.error;
                        prompt_remaining := outputRecord.prompt_remaining;
                        generated_eog := outputRecord.generated_eog;
                        // D.print("Challenger: JudgePromptGenerationDoIt_ - status_code      : " # debug_show (status_code));
                        D.print("Challenger: JudgePromptGenerationDoIt_ - output           : " # debug_show (output));
                        // D.print("Challenger: JudgePromptGenerationDoIt_ - conversation     : " # debug_show (conversation));
                        // D.print("Challenger: JudgePromptGenerationDoIt_ - error            : " # debug_show (error));
                        // D.print("Challenger: JudgePromptGenerationDoIt_ - prompt_remaining : " # debug_show (prompt_remaining));
                        // D.print("Challenger: JudgePromptGenerationDoIt_ - generated_eog    : " # debug_show (generated_eog));

                        generationOutput := generationOutput # output;
                        // D.print("Challenger: JudgePromptGenerationDoIt_ - generationOutput : " # debug_show (generationOutput));

                        if (prompt_remaining == "") {
                            prompt := ""; // Send empty prompt - the prompt ingestion is done.
                            continueLoopCount += 1; // We count the actual generation steps
                            // -----
                            // Prompt ingestion is finished. If it was not yet there, save the prompt cache for reuse with next submission
                            if (not foundPromptSaveCache) {
                                try {
                                    let copyPromptCacheInputRecord : Types.CopyPromptCacheInputRecord = { 
                                        from = promptCache; 
                                        to =  promptSaveCache
                                    };
                                    D.print("Challenger: JudgePromptGenerationDoIt_ - calling copy_prompt_cache to save the promptCache to promptSaveCache: " # promptSaveCache);
                                    num_update_calls += 1;
                                    let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.copy_prompt_cache(copyPromptCacheInputRecord);
                                    D.print("Challenger: JudgePromptGenerationDoIt_ - returned from copy_prompt_cache with statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
                                    // We do not care what the result is, as it is just a possible optimization operation
                                } catch (error : Error) {
                                    // Handle errors, such as llm canister not responding
                                    D.print("Challenger: JudgePromptGenerationDoIt_ - catch error when calling copy_prompt_cache : ");
                                    D.print("Challenger: JudgePromptGenerationDoIt_ - error: " # Error.message(error));
                                    return #Err(
                                        #Other(
                                            "Failed call to copy_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                                            " with error: " # Error.message(error)
                                        )
                                    );
                                };
                            };
                            break continueLoop; // Exit the loop - the prompt ingestion is done.
                        };
                        if (generated_eog) {
                            break continueLoop; // Exit the loop - the Judge response is generated.
                        };
                    };
                };
            } catch (error : Error) {
                // Handle errors, such as llm canister not responding
                D.print("Challenger: JudgePromptGenerationDoIt_ - catch error when calling new_chat : ");
                D.print("Challenger: JudgePromptGenerationDoIt_ - error: " # Error.message(error));
                return #Err(
                    #Other(
                        "Failed call to run_update of " # Principal.toText(Principal.fromActor(llmCanister)) #
                        " with error: " # Error.message(error)
                    )
                );
            };
        };

        // ----------------------------------------------------------------------
        // Download the prompt cache file from the LLM
        let judgePromptCacheBuffer : Buffer.Buffer<Blob> = Buffer.Buffer<Blob>(0);
        var downloadDone : Bool = false;
        let maxDownloadCalls : Nat = 100; // protect against an endless loop
        var numDownloadCalls : Nat = 0;
        var offset : Nat64 = 0;
        while (not downloadDone) {
            try {
                let downloadPromptCacheInputRecord : Types.DownloadPromptCacheInputRecord = { 
                    promptcache : Text = promptCache;
                    chunksize : Nat64 = judgePromptGenerationInput.chunkSizePrompCacheDownload;
                    offset : Nat64 = offset;
                };
                numDownloadCalls += 1;
                if (numDownloadCalls > maxDownloadCalls) {
                    D.print("Challenger: JudgePromptGenerationDoIt_ - too many calls download_prompt_cache_chunk - Breaking out of loop...");
                    return #Err(#Other("Too many calls to download_prompt_cache_chunk"));
                };
                var delay : Nat = 2_000_000_000; // 2 seconds
                let maxAttempts : Nat = 8;
                let fileDownloadRecordResult : Types.FileDownloadRecordResult = await retryLlmJudgePromptCacheChunkDownloadWithDelay(llmCanister, downloadPromptCacheInputRecord, maxAttempts, delay);

                switch (fileDownloadRecordResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case (#Ok(fileDownloadRecord)) {
                        D.print("Challenger: JudgePromptGenerationDoIt_ - received a Judge prompt cache chunk of size: " # debug_show (fileDownloadRecord.chunksize));
                        judgePromptCacheBuffer.add(fileDownloadRecord.chunk);
                        if (fileDownloadRecord.done) {
                            downloadDone := true;
                        };
                        offset += judgePromptGenerationInput.chunkSizePrompCacheDownload;
                    };
                };
            } catch (error : Error) {
                // Handle errors, such as llm canister not responding
                D.print("Challenger: JudgePromptGenerationDoIt_ - catch error when calling download_prompt_cache_chunk : ");
                D.print("Challenger: JudgePromptGenerationDoIt_ - error: " # Error.message(error));
                return #Err(
                    #Other(
                        "Failed call to download_prompt_cache_chunk of " # Principal.toText(Principal.fromActor(llmCanister)) #
                        " with error: " # Error.message(error)
                    )
                );
            };
        }; 

        // Delete the prompt cache in the LLM
        try {
            let args : [Text] = [
                "--prompt-cache",
                promptCache,
            ];
            let inputRecord : Types.InputRecord = { args = args };
            // D.print("Challenger: JudgePromptGenerationDoIt_ - calling remove_prompt_cache with args: ");
            // D.print(debug_show (args));
            num_update_calls += 1;
            let outputRecordResult : Types.OutputRecordResult = await llmCanister.remove_prompt_cache(inputRecord);
            // D.print("Challenger: JudgePromptGenerationDoIt_ - returned from remove_prompt_cache with outputRecordResult: ");
            // D.print(debug_show (outputRecordResult));

        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("Challenger: JudgePromptGenerationDoIt_ - catch error when calling remove_prompt_cache : ");
            D.print("Challenger: JudgePromptGenerationDoIt_ - error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to remove_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };


        // ----------------------------------------------------------------------
        // Return the result
        let judgePrompt: Types.JudgePrompt = {
            promptText : Text = promptText;
            promptCacheChunks : [Blob] = Buffer.toArray<Blob>(judgePromptCacheBuffer);
            promptCacheSha256 : Text = ""; // TODO - calculate the sha256 hash of the prompt cache
            promptCacheFilename : Text = promptCache;
            promptCacheNumberOfChunks : Nat = judgePromptCacheBuffer.size();
        };
        let judgePromptGenerationRecord : Types.JudgePromptGenerationRecord = {
            generationId : Text = generationId;
            generationSeed : Nat32 = seed;
            generatedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            generatedByLlmId : Text = Principal.toText(Principal.fromActor(llmCanister));
            generationPrompt : Text = generationPrompt;
            judgePrompt: Types.JudgePrompt = judgePrompt;
        };
        return #Ok(judgePromptGenerationRecord);
    };

    private func challengeGenerationDoIt_(challengeTopic : Types.ChallengeTopic) : async Types.GeneratedChallengeResult {
        let maxContinueLoopCount : Nat = 30; // After this many calls to run_update, we stop.
        let num_tokens : Nat64 = 1024;
        let temp : Float = 0.7;

        let startsWithOptions : [Text] = [
            "What",
            "Who",
            "Where",
            "When",
            "Why",
            "How",
            "Which",
            "Can",
            "Is",
            "Do",
        ];
        var challengePromptStartsWith : Text = startsWithOptions[0];
        let randomInt : ?Int = await Utils.nextRandomInt(0, startsWithOptions.size()-1);
        switch (randomInt) {
            case (?intToUse) {
                challengePromptStartsWith := startsWithOptions[Int.abs(intToUse)];
            };
            case (_) { // continue with default
            };
        };
        D.print("Challenger: challengeGenerationDoIt_ - challengePromptStartsWith: " # debug_show(challengePromptStartsWith));

        var promptRepetitive : Text = "<|im_start|>user\nAsk a question that can be answered with common knowledge. Do NOT give the answer. Ask me a question about ";
        var prompt : Text = promptRepetitive #
        challengeTopic.challengeTopic # ", and start the question with " # challengePromptStartsWith # "." #
        "\n<|im_end|>\n<|im_start|>assistant\n";

        let llmCanister = _getRoundRobinCanister();
        let llmCanisterPrincipal : Principal = Principal.fromActor(llmCanister);

        D.print("Challenger: challengeGenerationDoIt_ - llmCanister = " # debug_show(llmCanisterPrincipal));

        // Check health of llmCanister
        D.print("Challenger: challengeGenerationDoIt_ - calling health endpoint of LLM");
        let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.health();
        D.print("Challenger: challengeGenerationDoIt_ - returned from health endpoint of LLM with : ");
        D.print("Challenger: challengeGenerationDoIt_ - statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
        switch (statusCodeRecordResult) {
            case (#Err(error)) {
                return #Err(error);
            };
            case (#Ok(_statusCodeRecord)) {
                D.print("Challenger: challengeGenerationDoIt_ - LLM is healthy");
            };
        };

        // First send cycles to the LLM
        let cyclesAdded = challengeTopic.cyclesGenerateChallengeChctrlChllm;
        try {
            D.print("Challenger: challengeGenerationDoIt_ - calling Cycles.add for = " # debug_show(cyclesAdded) # " Cycles");
            Cycles.add<system>(cyclesAdded);

            let deposit_cycles_args = { canister_id : Principal = llmCanisterPrincipal; };
            let _ = await IC0.deposit_cycles(deposit_cycles_args);

            D.print("Challenger: challengeGenerationDoIt_ - Successfully deposited " # debug_show(cyclesAdded) # " cycles to LLM canister " # debug_show(llmCanisterPrincipal) ); 
        } catch (e) {
            D.print("Challenger: challengeGenerationDoIt_ - Failed to deposit " # debug_show(cyclesAdded) # " cycles to LLM canister " # debug_show(llmCanisterPrincipal));
            D.print("Challenger: challengeGenerationDoIt_ - Failed to deposit error is" # Error.message(e));

            return #Err(#FailedOperation);
        };    

        let generationId : Text = await Utils.newRandomUniqueId();
        
        // Use the generationId to create a highly variable seed for the LLM
        let seed : Nat32 = Utils.getRandomLlmSeed(generationId);
        D.print("Challenger: challengeGenerationDoIt_ - seed = " # debug_show(seed));

        var generationOutput : Text = "";
        let generationPrompt : Text = prompt;

        // The prompt cache file
        let promptCache : Text = generationId # ".cache";

        // Start the generation for this challenge
        var num_update_calls : Nat64 = 0;

        // data returned from new_chat
        var status_code : Nat16 = 0;
        var output : Text = "";
        var conversation : Text = "";
        var error : Text = "";
        var prompt_remaining : Text = "";
        var generated_eog : Bool = false;

        // ----------------------------------------------------------------------
        // Step 0
        // Restore a previously saved prompt cache file
        let promptSaveCache : Text = Nat32.toText(Text.hash(promptRepetitive)) # ".cache";
        var foundPromptSaveCache : Bool = false;

        try {
            let copyPromptCacheInputRecord : Types.CopyPromptCacheInputRecord = { 
                from = promptSaveCache; 
                to =  promptCache
            };
            D.print("Challenger: challengeGenerationDoIt_ - calling copy_prompt_cache to restore a previously saved promptCache if it exists. promptSaveCache: " # promptSaveCache);
            num_update_calls += 1;
            let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.copy_prompt_cache(copyPromptCacheInputRecord);
            D.print("Challenger: challengeGenerationDoIt_ - returned from copy_prompt_cache with statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
            switch (statusCodeRecordResult) {
                case (#Err(_)) {
                    foundPromptSaveCache := false;
                };
                case (#Ok(_)) {
                    foundPromptSaveCache := true;
                };
            };
        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("Challenger: challengeGenerationDoIt_ - catch error when calling copy_prompt_cache : ");
            D.print("Challenger: challengeGenerationDoIt_ - error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to copy_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };

        // ----------------------------------------------------------------------
        // Step 1
        // Call new_chat - this resets the prompt-cache for this conversation
        try {
            let args : [Text] = [
                "--prompt-cache",
                promptCache,
            ];
            let inputRecord : Types.InputRecord = { args = args };
            D.print("Challenger: calling new_chat...");
            // D.print(debug_show (args));
            num_update_calls += 1;
            let outputRecordResult : Types.OutputRecordResult = await llmCanister.new_chat(inputRecord);
            // D.print("Challenger: returned from new_chat with outputRecordResult: ");
            // D.print(debug_show (outputRecordResult));

            switch (outputRecordResult) {
                case (#Err(error)) {
                    return #Err(error);
                };
                case (#Ok(outputRecord)) {
                    // the generated tokens
                    status_code := outputRecord.status_code;
                    output := outputRecord.output;
                    conversation := outputRecord.conversation;
                    error := outputRecord.error;
                    prompt_remaining := outputRecord.prompt_remaining;
                    generated_eog := outputRecord.generated_eog;
                    // D.print("Challenger: status_code      : " # debug_show (status_code));
                    D.print("Challenger: output           : " # debug_show (output));
                    // D.print("Challenger: conversation     : " # debug_show (conversation));
                    // D.print("Challenger: error            : " # debug_show (error));
                    // D.print("Challenger: prompt_remaining : " # debug_show (prompt_remaining));
                    // D.print("Challenger: generated_eog    : " # debug_show (generated_eog));
                };
            };
        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            // D.print("Challenger: catch error when calling new_chat : ");
            // D.print("Challenger: error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to new_chat of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };

        // ----------------------------------------------------------------------
        // Step 2
        // (A) Ingest the prompt into the prompt-cache, using multiple update calls
        //      (-) Repeat call with full prompt until `prompt_remaining` in the response is empty.
        //      (-) The first part of the challenge will be generated too.
        // (B) Generate rest of challenge, using multiple update calls
        //      (-) Repeat call with empty prompt until `generated_eog` in the response is `true`.
        //      (-) The rest of the challenge will be generated.

        // Avoid endless loop by limiting the number of iterations
        var continueLoopCount : Nat = 0;
        label continueLoop while (continueLoopCount < maxContinueLoopCount) {
            try {
                let args = [
                    "--prompt-cache",
                    promptCache,
                    "--prompt-cache-all",
                    "--simple-io",
                    "--no-display-prompt", // only return generated text
                    "-n",
                    Nat64.toText(num_tokens),
                    "--seed",
                    Nat32.toText(seed),
                    "--temp",
                    Float.toText(temp),
                    "-p",
                    prompt,
                ];
                let inputRecord : Types.InputRecord = { args = args };
                D.print("Challenger: calling run_update...");
                // D.print(debug_show (args));
                num_update_calls += 1;
                if (num_update_calls > 30) {
                    D.print("Challenger:  too many calls run_update - Breaking out of loop...");
                    break continueLoop; // Protective break for endless loop.
                };
                let outputRecordResult : Types.OutputRecordResult = await llmCanister.run_update(inputRecord);
                // D.print("Challenger: INGESTING PROMPT:returned from run_update with outputRecordResult: ");
                // D.print(debug_show (outputRecordResult));

                switch (outputRecordResult) {
                    case (#Err(error)) {
                        return #Err(error);
                    };
                    case (#Ok(outputRecord)) {
                        // the generated tokens
                        status_code := outputRecord.status_code;
                        output := outputRecord.output;
                        conversation := outputRecord.conversation;
                        error := outputRecord.error;
                        prompt_remaining := outputRecord.prompt_remaining;
                        generated_eog := outputRecord.generated_eog;
                        // D.print("Challenger: status_code      : " # debug_show (status_code));
                        D.print("Challenger: output           : " # debug_show (output));
                        // D.print("Challenger: conversation     : " # debug_show (conversation));
                        // D.print("Challenger: error            : " # debug_show (error));
                        // D.print("Challenger: prompt_remaining : " # debug_show (prompt_remaining));
                        // D.print("Challenger: generated_eog    : " # debug_show (generated_eog));

                        generationOutput := generationOutput # output;
                        // D.print("Challenger: generationOutput : " # debug_show (generationOutput));

                        if (prompt_remaining == "") {
                            prompt := ""; // Send empty prompt - the prompt ingestion is done.
                            continueLoopCount += 1; // We count the actual generation steps

                            // -----
                            // Prompt ingestion is finished. If it was not yet there, save the prompt cache for reuse with next submission
                            if (not foundPromptSaveCache) {
                                try {
                                    let copyPromptCacheInputRecord : Types.CopyPromptCacheInputRecord = { 
                                        from = promptCache; 
                                        to =  promptSaveCache
                                    };
                                    D.print("Challenger:  calling copy_prompt_cache to save the promptCache to promptSaveCache: " # promptSaveCache);
                                    num_update_calls += 1;
                                    let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.copy_prompt_cache(copyPromptCacheInputRecord);
                                    D.print("Challenger:  returned from copy_prompt_cache with statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
                                    // We do not care what the result is, as it is just a possible optimization operation
                                } catch (error : Error) {
                                    // Handle errors, such as llm canister not responding
                                    D.print("Challenger:  catch error when calling copy_prompt_cache : ");
                                    D.print("Challenger:  error: " # Error.message(error));
                                    return #Err(
                                        #Other(
                                            "Failed call to copy_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                                            " with error: " # Error.message(error)
                                        )
                                    );
                                };
                            };
                        };
                        if (generated_eog) {
                            break continueLoop; // Exit the loop - the challenge is generated.
                        };
                    };
                };
            } catch (error : Error) {
                // Handle errors, such as llm canister not responding
                D.print("Challenger: catch error when calling new_chat : ");
                D.print("Challenger: error: " # Error.message(error));
                return #Err(
                    #Other(
                        "Failed call to run_update of " # Principal.toText(Principal.fromActor(llmCanister)) #
                        " with error: " # Error.message(error)
                    )
                );
            };
        };

        // Delete the prompt cache in the LLM
        try {
            let args : [Text] = [
                "--prompt-cache",
                promptCache,
            ];
            let inputRecord : Types.InputRecord = { args = args };
            // D.print("Challenger: calling remove_prompt_cache with args: ");
            // D.print("Challenger: " # debug_show (args));
            num_update_calls += 1;
            let outputRecordResult : Types.OutputRecordResult = await llmCanister.remove_prompt_cache(inputRecord);
            // D.print("Challenger: returned from remove_prompt_cache with outputRecordResult: ");
            // D.print(debug_show (outputRecordResult));

        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("Challenger: catch error when calling remove_prompt_cache : ");
            D.print("Challenger: error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to remove_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };

        // Return the generated challenge
        let generatedChallenge : Types.GeneratedChallenge = {
            generationId : Text = generationId;
            generationSeed : Nat32 = seed;
            generatedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            generatedByLlmId : Text = Principal.toText(Principal.fromActor(llmCanister));
            generationPrompt : Text = generationPrompt;
            generatedChallengeText : Text = generationOutput;
        };
        return #Ok(generatedChallenge);
    };

    public shared query (msg) func getRoundRobinCanister() : async Types.CanisterIDRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        let canisterIDRecord : Types.CanisterIDRecord = {
            canister_id = Principal.toText(Principal.fromActor(_getRoundRobinCanister()));
        };
        return #Ok(canisterIDRecord);
    };

    private func _getRoundRobinCanister() : Types.LLMCanister {
        D.print("Challenger: _getRoundRobinCanister: using roundRobinIndex " # Nat.toText(roundRobinIndex));
        let canister = llmCanisters.get(roundRobinIndex);
        roundRobinIndex += 1;

        var roundRobinIndexTurn = llmCanisters.size();
        if (roundRobinUseAll == false) {
            roundRobinIndexTurn := Utils.minNat(roundRobinIndexTurn, roundRobinLLMs);
        };

        if (roundRobinIndex >= roundRobinIndexTurn) {
            roundRobinIndex := 0;
        };

        return canister;
    };

    // Timer
    let actionRegularityInSeconds = 60;

    private func triggerRecurringAction() : async () {
        D.print("Challenger: Recurring action was triggered");
        //ignore generateChallenge(); TODO - Testing
        let result = await generateChallenge();
        D.print("Challenger: Recurring action result");
        D.print(debug_show (result));
        D.print("Challenger: Recurring action result");
    };

    public shared (msg) func startTimerExecutionAdmin() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        ignore setTimer<system>(#seconds 5,
            func () : async () {
                D.print("Challenger: setTimer");
                let id = recurringTimer<system>(#seconds actionRegularityInSeconds, triggerRecurringAction);
                D.print("Challenger: Successfully start timer with id = " # debug_show (id));
                recurringTimerId := ?id;
                await triggerRecurringAction();
        });
        let authRecord = { auth = "You started the timer." };
        return #Ok(authRecord);
    };

    public shared (msg) func stopTimerExecutionAdmin() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };

        switch (recurringTimerId) {
            case (?id) {
                D.print("Challenger: Stopping timer with id = " # debug_show (id));
                Timer.cancelTimer(id);
                recurringTimerId := null;
                D.print("Challenger: Timer stopped successfully.");
                
                return #Ok({ auth = "Timer stopped successfully." });
            };
            case null {
                return #Ok({ auth = "There is no active timer. Nothing to do." });
            };
        };
    };
};
