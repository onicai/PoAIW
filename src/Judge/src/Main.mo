import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import D "mo:base/Debug";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Bool "mo:base/Bool";
import Float "mo:base/Float";
// import HashMap "mo:base/HashMap";
import List "mo:base/List";
import Int "mo:base/Int";
import Time "mo:base/Time";
import { setTimer; recurringTimer } = "mo:base/Timer";
import Timer "mo:base/Timer";

import Types "../../common/Types";
import Utils "Utils";

actor class JudgeCtrlbCanister() = this {

    stable var GAME_STATE_CANISTER_ID : Text = "bkyz2-fmaaa-aaaaa-qaaaq-cai"; // local dev: "bkyz2-fmaaa-aaaaa-qaaaq-cai";
    stable var gameStateCanisterActor = actor (GAME_STATE_CANISTER_ID) : Types.GameStateCanister_Actor;

    public shared (msg) func setGameStateCanisterId(_game_state_canister_id : Text) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        GAME_STATE_CANISTER_ID := _game_state_canister_id;
        gameStateCanisterActor := actor (GAME_STATE_CANISTER_ID);
        return #Ok({ status_code = 200 });
    };

    // Orthogonal Persisted Data storage

    // timer ID, so we can stop it after starting
    stable var recurringTimerId : ?Timer.TimerId = null;

    // Record of recently score responses
    stable var scoredResponses : List.List<Types.ScoredResponseByJudge> = List.nil<Types.ScoredResponseByJudge>();

    private func putScoredResponse(scoredResponseEntry : Types.ScoredResponseByJudge) : Bool {
        scoredResponses := List.push<Types.ScoredResponseByJudge>(scoredResponseEntry, scoredResponses);
        return true;
    };

    private func getScoredResponse(submissionId : Text) : ?Types.ScoredResponseByJudge {
        return List.find<Types.ScoredResponseByJudge>(scoredResponses, func(scoredResponseEntry : Types.ScoredResponseByJudge) : Bool { scoredResponseEntry.submissionId == submissionId });
    };

    private func getScoredResponses() : [Types.ScoredResponseByJudge] {
        return List.toArray<Types.ScoredResponseByJudge>(scoredResponses);
    };

    private func removeScoredResponse(submissionId : Text) : Bool {
        scoredResponses := List.filter(scoredResponses, func(scoredResponseEntry : Types.ScoredResponseByJudge) : Bool { scoredResponseEntry.submissionId != submissionId });
        return true;
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
        D.print("Judge: Inside function _add_llm_canister_id. Adding llm: " # Principal.toText(Principal.fromActor(llmCanister)));
        llmCanisters.add(llmCanister);

        // Print content of the llmCanisters Buffer:
        D.print("Judge: Content of llmCanisters after addition: ");
        Buffer.iterate(
            llmCanisters,
            func(canister : Types.LLMCanister) : () {
                D.print("Judge: Canister ID: " # Principal.toText(Principal.fromActor(canister)));
            },
        );
        return #Ok({ status_code = 200 });
    };

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

    // Admin function to verify that judge_ctrlb_canister is a controller of all the llm canisters
    public shared (msg) func checkAccessToLLMs() : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };

        // Call all the llm canisters to verify that judge_ctrlb_canister is a controller
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

    private func sendScoredResponseToGameStateCanister(scoredResponse : Types.ScoredResponse) : async Types.ScoredResponseResult {
        let scoredResponseInput : Types.ScoredResponseInput = {
            challengeTopic : Text = scoredResponse.challengeTopic;
            challengeTopicId : Text = scoredResponse.challengeTopicId;
            challengeTopicCreationTimestamp : Nat64 = scoredResponse.challengeTopicCreationTimestamp;
            challengeTopicStatus : Types.ChallengeTopicStatus = scoredResponse.challengeTopicStatus;
            challengeQuestion : Text = scoredResponse.challengeQuestion;
            challengeQuestionSeed : Nat32 = scoredResponse.challengeQuestionSeed;
            challengeId : Text = scoredResponse.challengeId;
            challengeCreationTimestamp : Nat64 = scoredResponse.challengeCreationTimestamp;
            challengeCreatedBy : Types.CanisterAddress = scoredResponse.challengeCreatedBy;
            challengeStatus : Types.ChallengeStatus = scoredResponse.challengeStatus;
            challengeClosedTimestamp : ?Nat64 = scoredResponse.challengeClosedTimestamp;
            submissionCyclesRequired : Nat = scoredResponse.submissionCyclesRequired;
            challengeQueuedId : Text = scoredResponse.challengeQueuedId;
            challengeQueuedBy : Principal = scoredResponse.challengeQueuedBy;
            challengeQueuedTo : Principal = scoredResponse.challengeQueuedTo;
            challengeQueuedTimestamp : Nat64 = scoredResponse.challengeQueuedTimestamp;
            challengeAnswer : Text = scoredResponse.challengeAnswer;
            challengeAnswerSeed : Nat32 = scoredResponse.challengeAnswerSeed;
            submittedBy : Principal = scoredResponse.submittedBy;
            submissionId : Text = scoredResponse.submissionId;
            submittedTimestamp : Nat64 = scoredResponse.submittedTimestamp;
            submissionStatus: Types.ChallengeResponseSubmissionStatus = scoredResponse.submissionStatus;
            judgedBy : Principal = scoredResponse.judgedBy;
            score : Nat = scoredResponse.score;
            scoreSeed : Nat32 = scoredResponse.scoreSeed;
        };
        D.print("Judge: calling addScoredResponse of gameStateCanisterActor = " # Principal.toText(Principal.fromActor(gameStateCanisterActor)));
        let result : Types.ScoredResponseResult = await gameStateCanisterActor.addScoredResponse(scoredResponseInput);
        return result;
    };

    // Score submissions

    private func getSubmissionFromGameStateCanister() : async Types.ChallengeResponseSubmissionResult {
        D.print("Judge:  calling getNextSubmissionToJudge of gameStateCanisterActor = " # Principal.toText(Principal.fromActor(gameStateCanisterActor)));
        let result : Types.ChallengeResponseSubmissionResult = await gameStateCanisterActor.getNextSubmissionToJudge();
        D.print("Judge:  getNextSubmissionToJudge returned.");
        return result;
    };

    private func processSubmission(submissionEntry : Types.ChallengeResponseSubmission) : async () {
        D.print("Judge: processSubmission");
        let judgingResult : Types.JudgeChallengeResponseResult = await judgeChallengeResponseDoIt_(submissionEntry);
        D.print("Judge: processSubmission judgingResult");
        D.print(debug_show (judgingResult));
        switch (judgingResult) {
            case (#Err(error)) {
                D.print("Judge: processSubmission error");
                D.print(debug_show (error));
                // TODO: error handling
            };
            case (#Ok(scoringOutput)) {
                // Store record of scoring the response
                let scoredResponseEntry : Types.ScoredResponseByJudge = {
                    challengeTopic : Text = submissionEntry.challengeTopic;
                    challengeTopicId : Text = submissionEntry.challengeTopicId;
                    challengeTopicCreationTimestamp : Nat64 = submissionEntry.challengeTopicCreationTimestamp;
                    challengeTopicStatus : Types.ChallengeTopicStatus = submissionEntry.challengeTopicStatus;
                    challengeQuestion : Text = submissionEntry.challengeQuestion;
                    challengeQuestionSeed : Nat32 = submissionEntry.challengeQuestionSeed;
                    challengeId : Text = submissionEntry.challengeId;
                    challengeCreationTimestamp : Nat64 = submissionEntry.challengeCreationTimestamp;
                    challengeCreatedBy : Types.CanisterAddress = submissionEntry.challengeCreatedBy;
                    challengeStatus : Types.ChallengeStatus = submissionEntry.challengeStatus;
                    challengeClosedTimestamp : ?Nat64 = submissionEntry.challengeClosedTimestamp;
                    submissionCyclesRequired : Nat = submissionEntry.submissionCyclesRequired;
                    challengeQueuedId : Text = submissionEntry.challengeQueuedId;
                    challengeQueuedBy : Principal = submissionEntry.challengeQueuedBy;
                    challengeQueuedTo : Principal = submissionEntry.challengeQueuedTo;
                    challengeQueuedTimestamp : Nat64 = submissionEntry.challengeQueuedTimestamp;
                    challengeAnswer : Text = submissionEntry.challengeAnswer;
                    challengeAnswerSeed : Nat32 = submissionEntry.challengeAnswerSeed;
                    submittedBy : Principal = submissionEntry.submittedBy;
                    submissionId : Text = submissionEntry.submissionId;
                    submittedTimestamp : Nat64 = submissionEntry.submittedTimestamp;
                    submissionStatus: Types.ChallengeResponseSubmissionStatus = #Judged;
                    judgedBy : Principal = Principal.fromActor(this);
                    score : Nat = scoringOutput.generatedScore;
                    scoreSeed : Nat32 = scoringOutput.generationSeed;
                    judgedTimestamp : Nat64 = scoringOutput.generatedTimestamp;
                    judgeScoreRecord : Types.JudgeScore = scoringOutput;
                };
                let pushResult = putScoredResponse(scoredResponseEntry);

                switch (pushResult) {
                    case (false) {
                        D.print("Judge: pushResult error");
                        // TODO: error handling
                    };
                    case (true) {
                        // Send scored response to Game State canister
                        let scoredResponse : Types.ScoredResponse = {
                            challengeTopic : Text = submissionEntry.challengeTopic;
                            challengeTopicId : Text = submissionEntry.challengeTopicId;
                            challengeTopicCreationTimestamp : Nat64 = submissionEntry.challengeTopicCreationTimestamp;
                            challengeTopicStatus : Types.ChallengeTopicStatus = submissionEntry.challengeTopicStatus;
                            challengeQuestion : Text = submissionEntry.challengeQuestion;
                            challengeQuestionSeed : Nat32 = submissionEntry.challengeQuestionSeed;
                            challengeId : Text = submissionEntry.challengeId;
                            challengeCreationTimestamp : Nat64 = submissionEntry.challengeCreationTimestamp;
                            challengeCreatedBy : Types.CanisterAddress = submissionEntry.challengeCreatedBy;
                            challengeStatus : Types.ChallengeStatus = submissionEntry.challengeStatus;
                            challengeClosedTimestamp : ?Nat64 = submissionEntry.challengeClosedTimestamp;
                            submissionCyclesRequired : Nat = submissionEntry.submissionCyclesRequired;
                            challengeQueuedId : Text = submissionEntry.challengeQueuedId;
                            challengeQueuedBy : Principal = submissionEntry.challengeQueuedBy;
                            challengeQueuedTo : Principal = submissionEntry.challengeQueuedTo;
                            challengeQueuedTimestamp : Nat64 = submissionEntry.challengeQueuedTimestamp;
                            challengeAnswer : Text = submissionEntry.challengeAnswer;
                            challengeAnswerSeed : Nat32 = submissionEntry.challengeAnswerSeed;
                            submittedBy : Principal = submissionEntry.submittedBy;
                            submissionId : Text = submissionEntry.submissionId;
                            submittedTimestamp : Nat64 = submissionEntry.submittedTimestamp;
                            submissionStatus: Types.ChallengeResponseSubmissionStatus = #Judged;
                            judgedBy : Principal = Principal.fromActor(this);
                            score : Nat = scoringOutput.generatedScore;
                            scoreSeed : Nat32 = scoringOutput.generationSeed;
                            judgedTimestamp : Nat64 = scoringOutput.generatedTimestamp;
                        };
                        let sendResult : Types.ScoredResponseResult = await sendScoredResponseToGameStateCanister(scoredResponse);
                        switch (sendResult) {
                            case (#Err(error)) {
                                D.print("Judge: sendResult error");
                                D.print(debug_show (error));
                                // TODO: error handling
                            };
                            case (_) {
                                // Successfully processed and sent to Game State
                            };
                        };
                    };
                };
            };
        };
    };

    private func judgeChallengeResponseDoIt_(submissionEntry : Types.ChallengeResponseSubmission) : async Types.JudgeChallengeResponseResult {
        let maxContinueLoopCount : Nat = 1; // After this many calls to run_update, we stop.
        let num_tokens : Nat64 = 1024;
        let seed : Nat32 = 42; // fixed seed for reproducibility
        let temp : Float = 0.0; // zero temperature for deterministic output

        let challengeQuestion : Text = submissionEntry.challengeQuestion;
        var challengeAnswer : Text = submissionEntry.challengeAnswer;
        var promptRepetitive : Text = "<|im_start|>system\n" #
        "You grade answers based on its correctness to the question: \n" #
        " \n" #
        "- " # challengeQuestion # "\n" #
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
        var prompt : Text = promptRepetitive #
        "- " # challengeAnswer # "\n" #
        " \n" #
        "Respond with the grade only, nothing else.\n" #
        "\n<|im_end|>\n<|im_start|>assistant\n";

        let llmCanister = _getRoundRobinCanister();

        D.print("Judge: Inside function challengeGenerationDoIt_. llmCanister = " # Principal.toText(Principal.fromActor(llmCanister)));

        // Check health of llmCanister
        // D.print("Judge: ---judge_ctrlb_canister---");
        // D.print("Judge: calling health endpoint of LLM");
        let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.health();
        // D.print("Judge: ---judge_ctrlb_canister---");
        // D.print("Judge: returned from health endpoint of LLM with : ");
        // D.print("Judge: statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
        switch (statusCodeRecordResult) {
            case (#Err(error)) {
                return #Err(error);
            };
            case (#Ok(_statusCodeRecord)) {
                D.print("Judge: LLM is healthy");
            };
        };

        let generationId : Text = await Utils.newRandomUniqueId();
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
            D.print("Judge:  calling copy_prompt_cache to restore a previously saved promptCache if it exists. promptSaveCache: " # promptSaveCache);
            num_update_calls += 1;
            let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.copy_prompt_cache(copyPromptCacheInputRecord);
            D.print("Judge:  returned from copy_prompt_cache with statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
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
            D.print("Judge:  catch error when calling copy_prompt_cache : ");
            D.print("Judge:  error: " # Error.message(error));
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
            D.print("Judge: calling new_chat...");
            // D.print(debug_show (args));
            num_update_calls += 1;
            let outputRecordResult : Types.OutputRecordResult = await llmCanister.new_chat(inputRecord);
            // D.print("Judge: returned from new_chat with outputRecordResult: ");
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
                    // D.print("Judge: status_code      : " # debug_show (status_code));
                    D.print("Judge: output           : " # debug_show (output));
                    // D.print("Judge: conversation     : " # debug_show (conversation));
                    // D.print("Judge: error            : " # debug_show (error));
                    // D.print("Judge: prompt_remaining : " # debug_show (prompt_remaining));
                    // D.print("Judge: generated_eog    : " # debug_show (generated_eog));
                };
            };
        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("Judge: catch error when calling new_chat : ");
            D.print("Judge: error: " # Error.message(error));
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
                D.print("Judge: calling run_update...");
                // D.print(debug_show (args));
                num_update_calls += 1;
                if (num_update_calls > 30) {
                    D.print("Judge:  too many calls run_update - Breaking out of loop...");
                    break continueLoop; // Protective break for endless loop.
                };
                let outputRecordResult : Types.OutputRecordResult = await llmCanister.run_update(inputRecord);
                // D.print("Judge: INGESTING PROMPT:returned from run_update with outputRecordResult: ");
                // D.print("Judge: " # debug_show (outputRecordResult));

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
                        // D.print("Judge: status_code      : " # debug_show (status_code));
                        D.print("Judge: output           : " # debug_show (output));
                        // D.print("Judge: conversation     : " # debug_show (conversation));
                        // D.print("Judge: error            : " # debug_show (error));
                        // D.print("Judge: prompt_remaining : " # debug_show (prompt_remaining));
                        // D.print("Judge: generated_eog    : " # debug_show (generated_eog));

                        generationOutput := generationOutput # output;
                        // D.print("Judge: generationOutput : " # debug_show (generationOutput));

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
                                    D.print("Judge:  calling copy_prompt_cache to save the promptCache to promptSaveCache: " # promptSaveCache);
                                    num_update_calls += 1;
                                    let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.copy_prompt_cache(copyPromptCacheInputRecord);
                                    D.print("Judge:  returned from copy_prompt_cache with statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
                                    // We do not care what the result is, as it is just a possible optimization operation
                                } catch (error : Error) {
                                    // Handle errors, such as llm canister not responding
                                    D.print("Judge:  catch error when calling copy_prompt_cache : ");
                                    D.print("Judge:  error: " # Error.message(error));
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
                D.print("Judge: catch error when calling new_chat : ");
                D.print("Judge: error: " # Error.message(error));
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
            // D.print("Judge: calling remove_prompt_cache with args: ");
            // D.print(debug_show (args));
            num_update_calls += 1;
            let outputRecordResult : Types.OutputRecordResult = await llmCanister.remove_prompt_cache(inputRecord);
            // D.print("Judge: returned from remove_prompt_cache with outputRecordResult: ");
            // D.print(debug_show (outputRecordResult));

        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("Judge: catch error when calling remove_prompt_cache : ");
            D.print("Judge: error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to remove_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };

        // Convert the score from Text to Nat, with 0 if conversion fails
        let generatedScore : Nat = switch (Nat.fromText(generationOutput)) {
            case (null) 0; // Conversion failed, set to 0
            case (?value) value; // Successful conversion, use the value
        };

        // Return the scored response
        let scoringOutput : Types.JudgeScore = {
            generationId : Text = generationId;
            generationSeed : Nat32 = seed;
            generatedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            generatedByLlmId : Text = Principal.toText(Principal.fromActor(llmCanister));
            generationPrompt : Text = generationPrompt;
            generatedScoreText : Text = generationOutput;
            generatedScore : Nat = generatedScore;
        };
        return #Ok(scoringOutput);
    };

    // Score a mAIner's response to a challenge
    private func scoreNextSubmission() : async () {
        D.print("Judge: scoreNextSubmission - entered");

        // Get the next submission to score
        D.print("Judge:  scoreNextSubmission - calling getSubmissionFromGameStateCanister.");
        let submissionResult : Types.ChallengeResponseSubmissionResult = await getSubmissionFromGameStateCanister();
        D.print("Judge:  scoreNextSubmission - received submissionResult from getSubmissionFromGameStateCanister: " # debug_show (submissionResult));
        switch (submissionResult) {
            case (#Err(error)) {
                D.print("Judge:  scoreNextSubmission - submissionResult error : " # debug_show (error));
                // TODO: error handling
            };
            case (#Ok(submissionEntry : Types.ChallengeResponseSubmission)) {
                D.print("Judge:  scoreNextSubmission submissionResult submissionEntry");
                D.print(debug_show (submissionEntry));

                // Sanity checks on submitted response
                if (submissionEntry.submissionStatus != #Judging or submissionEntry.submissionId == "" or submissionEntry.challengeId == "" or submissionEntry.challengeQuestion == "" or submissionEntry.challengeAnswer == "") {
                    D.print("Judge: scoreNextSubmission - 02 - submissionEntry error - submissionEntry: " # debug_show (submissionEntry));
                    // TODO: error handling ... If this happens, we need to call the Game State canister to update the submissionStatus of the submission to #Error
                    return;
                };

                // Trigger processing submission but don't wait on result
                D.print("Judge: scoreNextSubmission - calling ignore processSubmission");
                ignore processSubmission(submissionEntry);
                return;
            };
        }
    };

    public shared query (msg) func getRoundRobinCanister() : async Types.CanisterIDRecordResult {
        let canisterIDRecord : Types.CanisterIDRecord = {
            canister_id = Principal.toText(Principal.fromActor(_getRoundRobinCanister()));
        };
        return #Ok(canisterIDRecord);
    };

    private func _getRoundRobinCanister() : Types.LLMCanister {
        D.print("_getRoundRobinCanister: using roundRobinIndex " # Nat.toText(roundRobinIndex));
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
    stable var actionRegularityInSeconds = 60; // TODO: set based on user setting for cycles burn rate

    private func triggerRecurringAction() : async () {
        D.print("Judge:  Recurring action was triggered");
        //ignore scoreNextSubmission(); TODO
        let result = await scoreNextSubmission();
        D.print("Judge:  Recurring action result");
        D.print(debug_show (result));
        D.print("Judge:  Recurring action result");
    };

    public shared (msg) func startTimerExecutionAdmin() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        ignore setTimer<system>(#seconds 5,
            func () : async () {
                D.print("Judge:  setTimer");
                let id =  recurringTimer<system>(#seconds actionRegularityInSeconds, triggerRecurringAction);
                D.print("Judge: Successfully start timer with id = " # debug_show (id));
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
                D.print("Judge: Stopping timer with id = " # debug_show (id));
                Timer.cancelTimer(id);
                recurringTimerId := null;
                D.print("Judge: Timer stopped successfully.");
                
                return #Ok({ auth = "Timer stopped successfully." });
            };
            case null {
                return #Ok({ auth = "There is no active timer. Nothing to do." });
            };
        };
    };

    // TODO: remove; testing function for admin
    public shared (msg) func triggerScoreSubmissionAdmin() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        let result = await scoreNextSubmission();
        let authRecord = { auth = "You triggered the score generation." };
        return #Ok(authRecord);
    };
};
