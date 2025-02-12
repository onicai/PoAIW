import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import D "mo:base/Debug";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Bool "mo:base/Bool";
// import HashMap "mo:base/HashMap";
import List "mo:base/List";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Char "mo:base/Char";
import Float "mo:base/Float";
import Cycles "mo:base/ExperimentalCycles";
import { print } = "mo:base/Debug";
import { setTimer; recurringTimer } = "mo:base/Timer";
import Timer "mo:base/Timer";

import Types "Types";
import Utils "Utils";

actor class MainerAgentCtrlbCanister() = this {

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

    public query (msg) func getGameStateCanisterId() : async Text {
        if (not Principal.isController(msg.caller)) {
            return "#Err(#StatusCode(401))";
        };

        return GAME_STATE_CANISTER_ID;
    };

    // Orthogonal Persisted Data storage

    // timer ID, so we can stop it after starting
    stable var recurringTimerId : ?Timer.TimerId = null;

    // Record of settings
    stable var agentSettings : List.List<Types.MainerAgentSettings> = List.nil<Types.MainerAgentSettings>();

    private func putAgentSettings(settingsEntry : Types.MainerAgentSettings) : Bool {
        agentSettings := List.push<Types.MainerAgentSettings>(settingsEntry, agentSettings);
        return true;
    };

    private func getCurrentAgentSettings() : ?Types.MainerAgentSettings {
        return List.get<Types.MainerAgentSettings>(agentSettings, 0);
    };

    // Record of generated responses
    stable var generatedResponses : List.List<Types.ChallengeResponse> = List.nil<Types.ChallengeResponse>();

    private func putGeneratedResponse(responseEntry : Types.ChallengeResponse) : Bool {
        generatedResponses := List.push<Types.ChallengeResponse>(responseEntry, generatedResponses);
        return true;
    };

    private func getGeneratedResponse(challengeId : Text) : ?Types.ChallengeResponse {
        return List.find<Types.ChallengeResponse>(generatedResponses, func(responseEntry : Types.ChallengeResponse) : Bool { responseEntry.challengeId == challengeId });
    };

    private func getGeneratedResponses() : [Types.ChallengeResponse] {
        return List.toArray<Types.ChallengeResponse>(generatedResponses);
    };

    private func removeGeneratedResponse(challengeId : Text) : Bool {
        generatedResponses := List.filter(generatedResponses, func(responseEntry : Types.ChallengeResponse) : Bool { responseEntry.challengeId != challengeId });
        return true;
    };

    // Record of submitted responses
    stable var submittedResponses : List.List<Types.ChallengeResponseSubmission> = List.nil<Types.ChallengeResponseSubmission>();

    private func putSubmittedResponse(responseEntry : Types.ChallengeResponseSubmission) : Bool {
        submittedResponses := List.push<Types.ChallengeResponseSubmission>(responseEntry, submittedResponses);
        return true;
    };

    private func getSubmittedResponse(submissionId : Text) : ?Types.ChallengeResponseSubmission {
        return List.find<Types.ChallengeResponseSubmission>(submittedResponses, func(responseEntry : Types.ChallengeResponseSubmission) : Bool { responseEntry.submissionId == submissionId });
    };

    private func getSubmittedResponses() : [Types.ChallengeResponseSubmission] {
        return List.toArray<Types.ChallengeResponseSubmission>(submittedResponses);
    };

    private func removeSubmittedResponse(submissionId : Text) : Bool {
        submittedResponses := List.filter(submittedResponses, func(responseEntry : Types.ChallengeResponseSubmission) : Bool { responseEntry.submissionId != submissionId });
        return true;
    };

    public shared query (msg) func getSubmittedResponsesAdmin() : async Types.ChallengeResponseSubmissionsResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#Unauthorized);
        };
        let submissions : [Types.ChallengeResponseSubmission] = getSubmittedResponses();
        return #Ok(submissions);
    };

    // Round-robin load balancer for LLM canisters to call
    private var roundRobinIndex : Nat = 0;
    private var roundRobinUseAll : Bool = true;
    private var roundRobinLLMs : Nat = 0; // Only used when roundRobinUseAll is false

    // Generate the array of values from 0 to 100000 in steps of 11
    let seedValues : [Nat64] = Array.tabulate(
        100000,
        func(index : Nat) : Nat64 {
            return Nat64.fromNat(index * 11);
        },
    );

    // Variable to track the current index
    var currentSeedIndex : Nat = 0;

    // Function to get the next rng_seed
    private func getNextRngSeed() : Nat64 {
        let seed = seedValues[currentSeedIndex];
        // Update the index to the next value, cycling back to 0
        currentSeedIndex := (currentSeedIndex + 1) % seedValues.size();
        return seed;
    };

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
        D.print("mAIner: Inside function _add_llm_canister_id. Adding llm: " # Principal.toText(Principal.fromActor(llmCanister)));
        llmCanisters.add(llmCanister);

        // Print content of the llmCanisters Buffer:
        D.print("mAIner: Content of llmCanisters after addition: ");
        Buffer.iterate(
            llmCanisters,
            func(canister : Types.LLMCanister) : () {
                D.print("mAIner: Canister ID: " # Principal.toText(Principal.fromActor(canister)));
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

    // Admin function to verify that mainer_ctrlb_canister is a controller of all the llm canisters
    public shared (msg) func checkAccessToLLMs() : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };

        // Call all the llm canisters to verify that mainer_ctrlb_canister is a controller
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

    // Settings

    public shared (msg) func updateAgentSettings(settingsInput : Types.MainerAgentSettingsInput) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        let settingsEntry : Types.MainerAgentSettings = {
            cyclesBurnRate : Types.CyclesBurnRate = settingsInput.cyclesBurnRate;
            creationTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            createdBy : Principal = msg.caller;
        };
        let putResult = putAgentSettings(settingsEntry);
        if (not putResult) {
            return #Err(#StatusCode(500));
        };
        return #Ok({ status_code = 200 });
    };

    // Respond to challenges

    private func getChallengeFromGameStateCanister() : async Types.ChallengeResult {
        D.print("mAIner:  calling getRandomOpenChallenge of gameStateCanisterActor = " # Principal.toText(Principal.fromActor(gameStateCanisterActor)));
        let result : Types.ChallengeResult = await gameStateCanisterActor.getRandomOpenChallenge();
        D.print("mAIner:  getRandomOpenChallenge returned.");
        return result;
    };

    private func processRespondingToChallenge(challenge : Types.Challenge) : async () {
        D.print("mAIner:  processRespondingToChallenge - calling respondToChallengeDoIt_");
        let respondingResult : Types.ChallengeResponseResult = await respondToChallengeDoIt_(challenge);
        D.print("mAIner:  processRespondingToChallenge - returned from respondToChallengeDoIt_");
        D.print("mAIner: respondingResult = " # debug_show (respondingResult));

        switch (respondingResult) {
            case (#Err(error)) {
                D.print("mAIner:  processRespondingToChallenge error");
                D.print(debug_show (error));
                // TODO: error handling
            };
            case (#Ok(respondingOutput : Types.ChallengeResponse)) {
                D.print("mAIner:  processRespondingToChallenge - calling putGeneratedResponse");
                D.print("mAIner:  respondingOutput = " # debug_show (respondingOutput));
                // Store response
                let storeResult : Bool = putGeneratedResponse(respondingOutput);
                D.print("mAIner:  processRespondingToChallenge - returned from putGeneratedResponse");

                switch (storeResult) {
                    case (false) {
                        D.print("mAIner:  storeResult error");
                        // TODO: error handling
                    };
                    case (true) {
                        // Submit response to Game State canister
                        let submittedBy : Principal = Principal.fromActor(this);
                        let challengeResponseSubmissionInput : Types.ChallengeResponseSubmissionInput = {
                            challengeId : Text = challenge.challengeId;
                            submittedBy : Principal = submittedBy;
                            challengeQuestion : Text = challenge.challengeQuestion;
                            challengeAnswer : Text = respondingOutput.generatedResponseText;
                        };
                        D.print("mAIner:  processRespondingToChallenge- calling getSubmissionCyclesRequired of gameStateCanisterActor = " # Principal.toText(Principal.fromActor(gameStateCanisterActor)));
                        // Add the desired amount of cycles
                        let submissionCyclesRequired : Nat = await gameStateCanisterActor.getSubmissionCyclesRequired();
                        D.print("mAIner:  processRespondingToChallenge- submissionCyclesRequired = " # debug_show(submissionCyclesRequired));
                        Cycles.add<system>(submissionCyclesRequired);

                        D.print("mAIner:  processRespondingToChallenge- calling submitChallengeResponse of gameStateCanisterActor = " # Principal.toText(Principal.fromActor(gameStateCanisterActor)));
                        let submitMetadaResult : Types.ChallengeResponseSubmissionMetadataResult = await gameStateCanisterActor.submitChallengeResponse(challengeResponseSubmissionInput);
                        D.print("mAIner:  processRespondingToChallenge - returned from gameStateCanisterActor.submitChallengeResponse");
                        switch (submitMetadaResult) {
                            case (#Err(error)) {
                                D.print("mAIner:  submitMetada error");
                                D.print(debug_show (error));
                                // TODO: error handling
                            };
                            case (#Ok(submitMetada : Types.ChallengeResponseSubmissionMetadata)) {
                                // Successfully submitted to Game State
                                let challengeResponseSubmission : Types.ChallengeResponseSubmission = {
                                    challengeId : Text = challengeResponseSubmissionInput.challengeId;
                                    submittedBy : Principal = challengeResponseSubmissionInput.submittedBy;
                                    challengeQuestion : Text = challengeResponseSubmissionInput.challengeQuestion;
                                    challengeAnswer : Text = challengeResponseSubmissionInput.challengeAnswer;
                                    submissionId : Text = submitMetada.submissionId;
                                    submittedTimestamp : Nat64 = submitMetada.submittedTimestamp;
                                    status : Types.ChallengeResponseSubmissionStatus = submitMetada.status;
                                };
                                D.print("mAIner:  processRespondingToChallenge - calling putSubmittedResponse");
                                let putResult = putSubmittedResponse(challengeResponseSubmission);
                                D.print("mAIner:  processRespondingToChallenge - return from putSubmittedResponse");
                                switch (putResult) {
                                    case (false) {
                                        D.print("mAIner:  putResult error");
                                        // TODO: error handling
                                    };
                                    case (true) {};
                                };
                            };
                        };
                    };
                };
            };
        };
    };

    private func respondToChallengeDoIt_(challenge : Types.Challenge) : async Types.ChallengeResponseResult {
        // TODO: probably need to improve the seed generation variability
        let maxContinueLoopCount : Nat = 3; // After this many calls to run_update, we stop.
        let num_tokens : Nat64 = 1024;
        let seed : Nat64 = getNextRngSeed();
        let temp : Float = 0.8;

        let challengeQuestion : Text = challenge.challengeQuestion;
        var prompt : Text = "<|im_start|>user\n" #
        "Answer this question as brief as possible.\n" #
        "This is the question: " # challengeQuestion # "\n" #
        "<|im_end|>\n<|im_start|>assistant\n";

        let llmCanister = _getRoundRobinCanister();

        D.print("mAIner:  llmCanister = " # Principal.toText(Principal.fromActor(llmCanister)));

        // Check health of llmCanister
        // D.print("mAIner:  calling health endpoint of LLM");
        let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.health();
        // D.print("mAIner:  returned from health endpoint of LLM with : ");
        // D.print("mAIner:  statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
        switch (statusCodeRecordResult) {
            case (#Err(error)) {
                return #Err(error);
            };
            case (#Ok(_statusCodeRecord)) {
                D.print("mAIner:  LLM is healthy");
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
        // Step 1
        // Call new_chat - this resets the prompt-cache for this conversation
        try {
            let args : [Text] = [
                "--prompt-cache",
                promptCache,
            ];
            let inputRecord : Types.InputRecord = { args = args };
            D.print("mAIner:  calling new_chat...");
            // D.print(debug_show (args));
            num_update_calls += 1;
            let outputRecordResult : Types.OutputRecordResult = await llmCanister.new_chat(inputRecord);
            // D.print("mAIner:  returned from new_chat with outputRecordResult: ");
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
                    // D.print("mAIner:  status_code      : " # debug_show (status_code));
                    D.print("mAIner:  output           : " # debug_show (output));
                    // D.print("mAIner:  conversation     : " # debug_show (conversation));
                    // D.print("mAIner:  error            : " # debug_show (error));
                    // D.print("mAIner:  prompt_remaining : " # debug_show (prompt_remaining));
                    // D.print("mAIner:  generated_eog    : " # debug_show (generated_eog));
                };
            };
        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("mAIner:  catch error when calling new_chat : ");
            D.print("mAIner:  error: " # Error.message(error));
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
                    Nat64.toText(seed),
                    "--temp",
                    Float.toText(temp),
                    "-p",
                    prompt,
                ];
                let inputRecord : Types.InputRecord = { args = args };
                D.print("mAIner:  calling run_update...");
                // D.print(debug_show (args));
                num_update_calls += 1;
                if (num_update_calls > 30) {
                    D.print("mAIner:  too many calls run_update - Breaking out of loop...");
                    break continueLoop; // Protective break for endless loop.
                };
                let outputRecordResult : Types.OutputRecordResult = await llmCanister.run_update(inputRecord);
                // D.print("mAIner:  INGESTING PROMPT:returned from run_update with outputRecordResult: ");
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
                        // D.print("mAIner:  status_code      : " # debug_show (status_code));
                        D.print("mAIner:  output           : " # debug_show (output));
                        // D.print("mAIner:  conversation     : " # debug_show (conversation));
                        // D.print("mAIner:  error            : " # debug_show (error));
                        // D.print("mAIner:  prompt_remaining : " # debug_show (prompt_remaining));
                        // D.print("mAIner:  generated_eog    : " # debug_show (generated_eog));

                        generationOutput := generationOutput # output;
                        // D.print("mAIner:  generationOutput : " # debug_show (generationOutput));

                        if (prompt_remaining == "") {
                            prompt := ""; // Send empty prompt - the prompt ingestion is done.
                            continueLoopCount += 1; // We count the actual generation steps
                        };
                        if (generated_eog) {
                            break continueLoop; // Exit the loop - the challenge is generated.
                        };
                    };
                };
            } catch (error : Error) {
                // Handle errors, such as llm canister not responding
                D.print("mAIner:  catch error when calling new_chat : ");
                D.print("mAIner:  error: " # Error.message(error));
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
            // D.print("mAIner:  calling remove_prompt_cache with args: ");
            // D.print(debug_show (args));
            num_update_calls += 1;
            let outputRecordResult : Types.OutputRecordResult = await llmCanister.remove_prompt_cache(inputRecord);
            // D.print("mAIner:  returned from remove_prompt_cache with outputRecordResult: ");
            // D.print(debug_show (outputRecordResult));

        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("mAIner:  catch error when calling remove_prompt_cache : ");
            D.print("mAIner:  error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to remove_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };

        D.print("mAIner:  generationOutput: " # generationOutput);
        let filteredOutput = filterText(generationOutput);
        D.print("mAIner:  filteredOutput  : " # filteredOutput);


        // Return the generated response
        let responseOutput : Types.ChallengeResponse = {
            challengeId :Text = challenge.challengeId;
            generationId : Text = generationId;
            generatedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            generatedByLlmId : Text = Principal.toText(Principal.fromActor(llmCanister));
            generationPrompt : Text = generationPrompt;
            generatedResponseText : Text = filteredOutput;
        };
        return #Ok(responseOutput);
    };

    private func respondToNextChallenge() : async () {
        D.print("mAIner:  respondToNextChallenge");
        // TODO: incorporate cycles burn rate setting

        // Get the next challenge to respond to
        D.print("mAIner:  respondToNextChallenge - calling getChallengeFromGameStateCanister.");
        let challengeResult : Types.ChallengeResult = await getChallengeFromGameStateCanister();
        D.print("mAIner:  respondToNextChallenge - received challengeResult from getChallengeFromGameStateCanister: " # debug_show (challengeResult));
        switch (challengeResult) {
            case (#Err(error)) {
                D.print("mAIner:  respondToNextChallenge - challengeResult error : " # debug_show (error));
                // TODO: error handling
            };
            case (#Ok(nextChallenge : Types.Challenge)) {
                D.print("mAIner:  respondToNextChallenge challengeResult nextChallenge");
                D.print(debug_show (nextChallenge));
                // Process the challenge
                // Sanity checks
                if (nextChallenge.challengeId == "" or nextChallenge.challengeQuestion == "") {
                    return;
                };
                switch (nextChallenge.status) {
                    case (#Open) {
                        // continue
                    };
                    case (_) { return };
                };
                switch (nextChallenge.closedTimestamp) {
                    case (null) {
                        // continue
                    };
                    case (_) { return };
                };

                // Get response generated for challenge and submit it
                ignore processRespondingToChallenge(nextChallenge);
                return;
            };
        };
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
        D.print("mAIner: _getRoundRobinCanister: using roundRobinIndex " # Nat.toText(roundRobinIndex));
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

    func filterText(text : Text) : Text {
        // Only keep the first line of the answer
        let firstLine = switch (Text.split(text, #text("\n")).next()) {
            case (?line) line;
            case null "";
        };

        // Remove quotes and backslashes
        let withoutQuotes = Text.replace(firstLine, #text("\""), "");
        let withoutSingleQuotes = Text.replace(withoutQuotes, #text("'"), "");
        let withoutBackslashes = Text.replace(withoutSingleQuotes, #text("\\"), "");

        // Remove leading and trailing whitespaces
        let trimmed = Text.trim(withoutBackslashes, #text(" \t\n\r"));

        // Remove [end of text]
        let withoutEndText = Text.replace(trimmed, #text("[end of text]"), "");

        // Remove non-ASCII characters (simplified version)
        let filteredChars = Iter.filter(Text.toIter(withoutEndText), func (c : Char) : Bool {
            let code = Char.toNat32(c);
            code >= 32 and code <= 126
        });

        return Text.fromIter(filteredChars);
    };

// Timer
    stable var actionRegularityInSeconds = 60; // TODO: set based on user setting for cycles burn rate

    private func triggerRecurringAction() : async () {
        D.print("mAIner:  Recurring action was triggered");
        //ignore respondToNextChallenge(); TODO
        let result = await respondToNextChallenge();
        D.print("mAIner:  Recurring action result");
        print(debug_show (result));
        D.print(debug_show (result));
        D.print("mAIner:  Recurring action result");
    };

    public shared (msg) func startTimerExecutionAdmin() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        ignore setTimer<system>(#seconds 5,
            func () : async () {
                D.print("mAIner:  setTimer");
                let id =  recurringTimer<system>(#seconds actionRegularityInSeconds, triggerRecurringAction);
                D.print("mAIner: Successfully start timer with id = " # debug_show (id));
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
                D.print("mAIner: Stopping timer with id = " # debug_show (id));
                Timer.cancelTimer(id);
                recurringTimerId := null;
                D.print("mAIner: Timer stopped successfully.");
                
                return #Ok({ auth = "Timer stopped successfully." });
            };
            case null {
                return #Ok({ auth = "There is no active timer. Nothing to do." });
            };
        };
    };

    // TODO: remove; testing function for admin
    public shared (msg) func triggerChallengeResponseAdmin() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        let result = await respondToNextChallenge();
        let authRecord = { auth = "You triggered the response generation." };
        return #Ok(authRecord);
    };
};
