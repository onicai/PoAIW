See instructions in `PoAIW/README.md`

dfx canister call game_state_canister createUserMainerAgent '(record { paymentTransactionBlockId = 11; mainerConfig = record { mainerAgentCanisterType = variant {Own}; selectedLLM = opt variant {Qwen2_5_500M}; }; })'

# Copy the output from about command as the argument for next command
dfx canister call game_state_canister spinUpMainerControllerCanister '(record { status = variant { Paid }; canisterType = variant { MainerAgent = variant { Own } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_744_901_041_887_471_597 : nat64; createdBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; mainerConfig = record { selectedLLM = opt variant { Qwen2_5_500M }; mainerAgentCanisterType = variant { Own };  }; address = "";  } )'

# Copy the output from about command as the argument for next command
dfx canister call game_state_canister setUpMainerLlmCanister '(record { status = variant { ControllerCreated }; canisterType = variant { MainerAgent = variant { Own } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_744_901_041_887_471_597 : nat64;  createdBy = principal "be2us-64aaa-aaaaa-qaabq-cai";       mainerConfig = record { selectedLLM = opt variant { Qwen2_5_500M }; mainerAgentCanisterType = variant { Own }; }; address = "dccg7-xmaaa-aaaaa-qaamq-cai"; } )'
