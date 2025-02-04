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
import Float "mo:base/Float";
import Time "mo:base/Time";
import { print } = "mo:base/Debug";
import { setTimer; recurringTimer } = "mo:base/Timer";

import Types "Types";
import Utils "Utils";

actor class ChallengerCtrlbCanister() {

    stable var GAME_STATE_CANISTER_ID : Text = "b77ix-eeaaa-aaaaa-qaada-cai"; // local dev: "b77ix-eeaaa-aaaaa-qaada-cai";

    public shared (msg) func setGameStateCanisterId(_game_state_canister_id : Text) : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        GAME_STATE_CANISTER_ID := _game_state_canister_id;
        let authRecord = { auth = "You set the id for this canister." };
        return #Ok(authRecord);
    };

    public query (msg) func getGameStateCanisterId() : async Text {
        if (not Principal.isController(msg.caller)) {
            return "#Err(#StatusCode(401))";
        };

        return GAME_STATE_CANISTER_ID;
    };

    // Orthogonal Persisted Data storage

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

    public query (msg) func getChallengesAdmin() : async [Types.GeneratedChallenge] {
        if (not Principal.isController(msg.caller)) {
            return [];
        };

        return getGeneratedChallenges();
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

    // The llmCanisterIDs this challenger_ctrlb_canister can call
    private var llmCanisterIDs : Buffer.Buffer<Text> = Buffer.fromArray<Text>([]);

    // -------------------------------------------------------------------------------
    // The C++ LLM canisters that can be called

    private var llmCanisters : Buffer.Buffer<Types.LLMCanister> = Buffer.fromArray([]);

    // Resets llmCanisterIDs, and then adds the argument as the first llmCanisterId
    public shared (msg) func set_llm_canister_id(llmCanisterIdRecord : Types.CanisterIDRecord) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        llmCanisterIDs.clear();
        _add_llm_canister_id(llmCanisterIdRecord);
    };

    // Adds another llmCanisterIDs
    public shared (msg) func add_llm_canister_id(llmCanisterIdRecord : Types.CanisterIDRecord) : async Types.StatusCodeRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        _add_llm_canister_id(llmCanisterIdRecord);
    };

    // Resets llmCanisterIDs, and then adds the argument as the first llmCanisterId
    private func _add_llm_canister_id(llmCanisterIdRecord : Types.CanisterIDRecord) : Types.StatusCodeRecordResult {
        let llmCanister = actor (llmCanisterIdRecord.canister_id) : Types.LLMCanister;
        D.print("Inside function _add_llm_canister_id. Adding llm: " # Principal.toText(Principal.fromActor(llmCanister)));
        llmCanisters.add(llmCanister);

        // Print content of the llmCanisters Buffer:
        D.print("Content of llmCanisters after addition: ");
        Buffer.iterate(
            llmCanisters,
            func(canister : Types.LLMCanister) : () {
                D.print("Canister ID: " # Principal.toText(Principal.fromActor(canister)));
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

    private func generateChallenge() : async Types.GeneratedChallengeResult {
        D.print("############################generateChallenge############################");
        let generatedChallengeOutput : Types.GeneratedChallengeResult = await challengeGenerationDoIt_();
        D.print("############################generateChallenge generatedChallengeOutput############################");
        print(debug_show (generatedChallengeOutput));
        switch (generatedChallengeOutput) {
            case (#Err(error)) {
                D.print("############################generateChallenge generatedChallengeOutput error############################");
                print(debug_show (error));
                return #Err(error);
            };
            case (#Ok(generatedChallenge)) {
                D.print("############################generateChallenge generatedChallengeOutput Ok############################");
                print(debug_show (generatedChallenge));
                // Store challenge
                let pushResult = putGeneratedChallenge(generatedChallenge);
                D.print("############################generateChallenge generatedChallengeOutput Ok pushResult############################");
                print(debug_show (pushResult));

                // Add challenge to Game State canister
                let newChallenge : Types.NewChallengeInput = {
                    challengeQuestion : Text = generatedChallenge.generatedChallengeText;
                };

                let gameStateCanisterActor = actor (GAME_STATE_CANISTER_ID) : Types.GameStateCanister;

                let additionResult : Types.ChallengeAdditionResult = await gameStateCanisterActor.addChallenge(newChallenge);
                D.print("############################generateChallenge generatedChallengeOutput Ok additionResult############################");
                print(debug_show (additionResult));
                switch (additionResult) {
                    case (#Err(error)) {
                        // TODO: error handling (e.g. put into queue and try again later)
                    };
                    case (#Ok(addedChallenge)) {
                        // TODO: decide if returned challenge entry should be stored as well
                    };
                };
                return generatedChallengeOutput;
            };
        };
    };

    private func challengeGenerationDoIt_() : async Types.GeneratedChallengeResult {
        // TODO: probably need to improve the seed generation variability
        let num_tokens : Nat64 = 1024;
        let seed : Nat64 = getNextRngSeed();
        let temp : Float = 0.7;

        // TODO: introduce variability in prompt for Topic and PromptStartsWith
        var challengeTopic : Text = "crypto";
        var challengePromptStartsWith : Text = "What";
        var prompt : Text = "<|im_start|>user\nAsk a question about " #
        challengeTopic #
        ", that can be answered with common knowledge. Do NOT give the answer. Start the question with " #
        challengePromptStartsWith #
        "\n<|im_end|>\n<|im_start|>assistant\n";

        let llmCanister = _getRoundRobinCanister();

        D.print("Inside function challengeGenerationDoIt_. llmCanister = " # Principal.toText(Principal.fromActor(llmCanister)));

        // Check health of llmCanister
        D.print("---challenger_ctrlb_canister---");
        D.print("calling health endpoint of LLM");
        let statusCodeRecordResult : Types.StatusCodeRecordResult = await llmCanister.health();
        D.print("---challenger_ctrlb_canister---");
        D.print("returned from health endpoint of LLM with : ");
        D.print("statusCodeRecordResult: " # debug_show (statusCodeRecordResult));
        switch (statusCodeRecordResult) {
            case (#Err(error)) {
                return #Err(error);
            };
            case (#Ok(_statusCodeRecord)) {
                D.print("LLM is healthy");
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
            D.print("---challenger_ctrlb_canister---");
            D.print("calling new_chat with args: ");
            D.print(debug_show (args));
            num_update_calls += 1;
            let outputRecordResult : Types.OutputRecordResult = await llmCanister.new_chat(inputRecord);
            D.print("---challenger_ctrlb_canister---");
            D.print("returned from new_chat with outputRecordResult: ");
            D.print(debug_show (outputRecordResult));

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
                    D.print("status_code      : " # debug_show (status_code));
                    D.print("output           : " # debug_show (output));
                    D.print("conversation     : " # debug_show (conversation));
                    D.print("error            : " # debug_show (error));
                    D.print("prompt_remaining : " # debug_show (prompt_remaining));
                    D.print("generated_eog    : " # debug_show (generated_eog));
                };
            };
        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("---challenger_ctrlb_canister---");
            D.print("catch error when calling new_chat : ");
            D.print("error: " # Error.message(error));
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
        label continueLoop while (continueLoopCount < 30) {
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
                D.print("---challenger_ctrlb_canister---");
                D.print("INGESTING PROMPT: calling run_update with args: ");
                D.print(debug_show (args));
                num_update_calls += 1;
                let outputRecordResult : Types.OutputRecordResult = await llmCanister.run_update(inputRecord);
                D.print("---challenger_ctrlb_canister---");
                D.print("INGESTING PROMPT:returned from run_update with outputRecordResult: ");
                D.print(debug_show (outputRecordResult));

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
                        D.print("status_code      : " # debug_show (status_code));
                        D.print("output           : " # debug_show (output));
                        D.print("conversation     : " # debug_show (conversation));
                        D.print("error            : " # debug_show (error));
                        D.print("prompt_remaining : " # debug_show (prompt_remaining));
                        D.print("generated_eog    : " # debug_show (generated_eog));

                        generationOutput := generationOutput # output;
                        D.print("generationOutput : " # debug_show (generationOutput));

                        if (prompt_remaining == "") {
                            prompt := ""; // Send empty prompt - the prompt ingestion is done.
                        };
                        if (generated_eog) {
                            break continueLoop; // Exit the loop - the challenge is generated.
                        };
                    };
                };
            } catch (error : Error) {
                // Handle errors, such as llm canister not responding
                D.print("---challenger_ctrlb_canister---");
                D.print("catch error when calling new_chat : ");
                D.print("error: " # Error.message(error));
                return #Err(
                    #Other(
                        "Failed call to run_update of " # Principal.toText(Principal.fromActor(llmCanister)) #
                        " with error: " # Error.message(error)
                    )
                );
            };
            continueLoopCount += 1;
        };

        // Delete the prompt cache in the LLM
        try {
            let args : [Text] = [
                "--prompt-cache",
                promptCache,
            ];
            let inputRecord : Types.InputRecord = { args = args };
            D.print("---challenger_ctrlb_canister---");
            D.print("calling remove_prompt_cache with args: ");
            D.print(debug_show (args));
            num_update_calls += 1;
            let outputRecordResult : Types.OutputRecordResult = await llmCanister.remove_prompt_cache(inputRecord);
            D.print("---challenger_ctrlb_canister---");
            D.print("returned from remove_prompt_cache with outputRecordResult: ");
            D.print(debug_show (outputRecordResult));

        } catch (error : Error) {
            // Handle errors, such as llm canister not responding
            D.print("---challenger_ctrlb_canister---");
            D.print("catch error when calling remove_prompt_cache : ");
            D.print("error: " # Error.message(error));
            return #Err(
                #Other(
                    "Failed call to remove_prompt_cache of " # Principal.toText(Principal.fromActor(llmCanister)) #
                    " with error: " # Error.message(error)
                )
            );
        };

        // Return the generated challenge
        let challengeOutput : Types.GeneratedChallenge = {
            generationId : Text = generationId;
            generatedTimestamp : Nat64 = Nat64.fromNat(Int.abs(Time.now()));
            generatedByLlmId : Text = Principal.toText(Principal.fromActor(llmCanister));
            generationPrompt : Text = generationPrompt;
            generatedChallengeText : Text = generationOutput;
        };
        return #Ok(challengeOutput);
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
    let actionRegularityInSeconds = 300;

    private func triggerRecurringAction() : async () {
        print("############################Recurring action was triggered############################");
        D.print("############################Recurring action was triggered############################");
        //ignore generateChallenge(); TODO
        let result = await generateChallenge();
        print("############################Recurring action result############################");
        D.print("############################Recurring action result############################");
        print(debug_show (result));
        D.print(debug_show (result));
        print("############################Recurring action result############################");
        D.print("############################Recurring action result############################");
    };

    public shared (msg) func startTimerExecutionAdmin() : async Types.AuthRecordResult {
        if (not Principal.isController(msg.caller)) {
            return #Err(#StatusCode(401));
        };
        ignore setTimer<system>(#seconds 5,
            func () : async () {
                print("############################setTimer############################");
                D.print("############################setTimer############################");
                ignore recurringTimer<system>(#seconds actionRegularityInSeconds, triggerRecurringAction);
                await triggerRecurringAction();
        });
        let authRecord = { auth = "You started the timer." };
        return #Ok(authRecord);
    };
};
