See instructions in `PoAIW/README.md`

```bash
# Run these commands from the folder: funnAI

# ----------------------------------------
# mAIner of type Own
dfx canister call game_state_canister createUserMainerAgent '(record { paymentTransactionBlockId = 11; mainerConfig = record { mainerAgentCanisterType = variant {Own}; selectedLLM = opt variant {Qwen2_5_500M}; }; })'

### Copy the output from above command as the argument for next command
dfx canister call game_state_canister spinUpMainerControllerCanister '(record { status = variant { Paid }; canisterType = variant { MainerAgent = variant { Own } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_745_075_669_143_980_013 : nat64; createdBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; mainerConfig = record { selectedLLM = opt variant { Qwen2_5_500M }; mainerAgentCanisterType = variant { Own };  }; address = "";  } )'

### Copy the output from above command as the argument for next command
dfx canister call game_state_canister setUpMainerLlmCanister '(record { status = variant { ControllerCreated }; canisterType = variant { MainerAgent = variant { Own } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_745_075_669_143_980_013 : nat64;  createdBy = principal "be2us-64aaa-aaaaa-qaabq-cai";       mainerConfig = record { selectedLLM = opt variant { Qwen2_5_500M }; mainerAgentCanisterType = variant { Own }; }; address = "cuj6u-c4aaa-aaaaa-qaajq-cai"; } )'

### To add another LLM, call this method with same argument
dfx canister call game_state_canister addLlmCanisterToMainer '(record { status = variant { ControllerCreated }; canisterType = variant { MainerAgent = variant { Own } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_745_075_669_143_980_013 : nat64;  createdBy = principal "be2us-64aaa-aaaaa-qaabq-cai";       mainerConfig = record { selectedLLM = opt variant { Qwen2_5_500M }; mainerAgentCanisterType = variant { Own }; }; address = "cuj6u-c4aaa-aaaaa-qaajq-cai"; } )'

# ----------------------------------------
# mAIner of type ShareService
# Only a controller can make these calls when the mainerAgentCanisterType = variant {ShareService}
# - No payment is due, so set paymentTransactionBlockId = 0
dfx canister call game_state_canister createUserMainerAgent '(record { paymentTransactionBlockId = 0; mainerConfig = record { mainerAgentCanisterType = variant {ShareService}; selectedLLM = opt variant {Qwen2_5_500M}; }; })'

### Copy the output from above command as the argument for next command
dfx canister call game_state_canister spinUpMainerControllerCanister '(record { status = variant { Paid }; canisterType = variant { MainerAgent = variant { ShareService } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_745_075_669_143_980_013 : nat64; createdBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; mainerConfig = record { selectedLLM = opt variant { Qwen2_5_500M }; mainerAgentCanisterType = variant { ShareService };  }; address = "";  } )'

### Copy the output from above command as the argument for next command
dfx canister call game_state_canister setUpMainerLlmCanister '(record { status = variant { ControllerCreated }; canisterType = variant { MainerAgent = variant { ShareService } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_745_075_669_143_980_013 : nat64;  createdBy = principal "be2us-64aaa-aaaaa-qaabq-cai";       mainerConfig = record { selectedLLM = opt variant { Qwen2_5_500M }; mainerAgentCanisterType = variant { ShareService }; }; address = "cuj6u-c4aaa-aaaaa-qaajq-cai"; } )'

### To add another LLM, call this method with same argument
dfx canister call game_state_canister addLlmCanisterToMainer '(record { status = variant { ControllerCreated }; canisterType = variant { MainerAgent = variant { ShareService } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_745_075_669_143_980_013 : nat64;  createdBy = principal "be2us-64aaa-aaaaa-qaabq-cai";       mainerConfig = record { selectedLLM = opt variant { Qwen2_5_500M }; mainerAgentCanisterType = variant { ShareService }; }; address = "cuj6u-c4aaa-aaaaa-qaajq-cai"; } )'

# ----------------------------------------
# mAIner of type ShareAgent

## Register ShareService if not done yet
## NOTE: When deploying with the scripts described in funnAI/README.md, this is already done...
# dfx canister call game_state_canister addOfficialCanister "(record { address = \"aax3a-h4aaa-aaaaa-qaahq-cai\"; canisterType = variant {MainerAgent = variant {ShareService}}; })"

## Create ShareAgent
dfx canister call game_state_canister createUserMainerAgent '(record { paymentTransactionBlockId = 12; mainerConfig = record { mainerAgentCanisterType = variant {ShareAgent}; selectedLLM = null; }; })'

### Copy the output from above command as the argument for next command
dfx canister call game_state_canister spinUpMainerControllerCanister '(record {status = variant { Paid }; canisterType = variant { MainerAgent = variant { ShareAgent } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_745_076_185_351_556_204 : nat64; createdBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; mainerConfig = record {       selectedLLM = null; mainerAgentCanisterType = variant { ShareAgent }; }; address = ""; } )'

## Fix issues
### Create a new mAIner for a user 
dfx canister call game_state_canister spinUpMainerControllerCanisterForUserAdmin '(record {        status = variant { Paid };        canisterType = variant { MainerAgent = variant { ShareAgent } };        ownedBy = principal "qhvia-unzwx-ewoal-5yepy-o577x-fc4dc-qzqm3-zqirv-j3icu-3h5jj-oqe";        creationTimestamp = 1_751_064_920_866_195_118 : nat64;        createdBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe";        mainerConfig = record {          selectedLLM = null;          subnetLlm = "";          mainerAgentCanisterType = variant { ShareAgent };          cyclesForMainer = 17_185_500_000_000 : nat;          subnetCtrl = "snjp4-xlbw4-mnbog-ddwy6-6ckfd-2w5a2-eipqo-7l436-pxqkh-l6fuv-vae";        };        subnet = "";        address = "";      } )' --network $NETWORK
### Finish the setup of a user's mAIner that had an issue (get the mAIner entry to fix as parameter for the call, especially the creationTimestamp which is used as identifier for the mAIner entry)
dfx canister call game_state_canister completeMainerSetupForUserAdmin '(record {        status = variant { Paid };        canisterType = variant { MainerAgent = variant { ShareAgent } };        ownedBy = principal "7lxg5-etr52-tmtb5-7b4ul-zvhri-wdpvh-3a2lx-72r5k-owcdo-qlci5-pae";        creationTimestamp = 1_752_159_642_043_425_115 : nat64;        createdBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe";        mainerConfig = record {          selectedLLM = null;          subnetLlm = "";          mainerAgentCanisterType = variant { ShareAgent };          cyclesForMainer = 39_985_500_000_000 : nat;          subnetCtrl = "snjp4-xlbw4-mnbog-ddwy6-6ckfd-2w5a2-eipqo-7l436-pxqkh-l6fuv-vae";        };        subnet = "";        address = "";      } )' --network $NETWORK
# ----------------------------------------

## Derive new mAIner wasm hash
dfx canister call game_state_canister deriveNewMainerAgentCanisterWasmHashAdmin '(record {address = "canister id of new mAIner"; textNote = "Info on update"; } )'
e.g.
dfx canister call game_state_canister deriveNewMainerAgentCanisterWasmHashAdmin '(record {address = "dmalx-m4aaa-aaaaa-qaanq-cai"; textNote = "After new addCycle function"; } )'
Response:
(
  variant {
    Ok = record {
      creationTimestamp = 1_747_586_744_041_181_103 : nat64;
      wasmHash = blob "\f5\d5\ab\57\f4\be\2d\c1\b2\1e\eb\51\02\1f\95\74\1f\3f\72\39\c5\c9\31\b1\e9\15\7d\73\4c\fc\8e\d8";
      createdBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe";
      textNote = "After new addCycle function";
      version = 1 : nat;
    }
  },
)

# ----------------------------------------

## Add Unlocked mAIner
dfx canister call game_state_canister unlockUserMainerAgent '(record { paymentTransactionBlockId = 0;  owner = opt principal "fmx2v-tpf3n-ihkag-gag34-oknfv-tbujq-ke4oe-r42z2-lwclp-fnff3-bqe"; mainerConfig = record { mainerAgentCanisterType = variant {ShareAgent}; selectedLLM = null; cyclesForMainer = 0; subnetCtrl = ""; subnetLlm = ""; }; })' --network $NETWORK

dfx canister call game_state_canister getMainerAgentCanistersAdmin --network $NETWORK

dfx canister call game_state_canister getMainerAgentCanistersForUserAdmin '"x62bb-3lvfd-xosdw-6eydw-tticc-nyvhe-3hdst-fv2dn-fmsln-swrmw-uae"' --network $NETWORK

dfx canister call game_state_canister getNumMainerAgentCanistersForUserAdmin '"dno55-cf4cu-q2wwf-udihm-tq4ul-76yti-ywaee-khuyf-urcfy-r2vcz-hae"' --network $NETWORK

## Set price of mAIner
### ShareAgent
dfx canister call game_state_canister setIcpForShareAgentAdmin '10' --network $NETWORK
dfx canister call game_state_canister getPriceForShareAgent --network $NETWORK
#### whitelist
dfx canister call game_state_canister setIcpForWhitelistShareAgentAdmin '5' --network $NETWORK
dfx canister call game_state_canister getWhitelistPriceForShareAgent --network $NETWORK

### Own
dfx canister call game_state_canister setIcpForOwnMainerAdmin '1000' --network $NETWORK
dfx canister call game_state_canister getPriceForOwnMainer --network $NETWORK
#### whitelist
dfx canister call game_state_canister setIcpForWhitelistOwnMainerAdmin '500' --network $NETWORK
dfx canister call game_state_canister getWhitelistPriceForOwnMainer --network $NETWORK

## Set limit how many mAIners may be created
### Buffer
dfx canister call game_state_canister getBufferMainerCreation --network $NETWORK
dfx canister call game_state_canister setBufferMainerCreation '100' --network $NETWORK
### ShareAgent
dfx canister call game_state_canister getNumberMainerAgentsAdmin '(record { mainerType = variant {ShareAgent}; })' --network $NETWORK
dfx canister call game_state_canister getLimitForCreatingMainerAdmin '(record { mainerType = variant {ShareAgent}; })' --network $NETWORK
dfx canister call game_state_canister setLimitForCreatingMainerAdmin '(record { mainerType = variant {ShareAgent}; newLimit = 697 })' --network $NETWORK
dfx canister call game_state_canister shouldCreatingMainersBeStopped '(record { mainerType = variant {ShareAgent}; })' --network $NETWORK
### Own
dfx canister call game_state_canister getNumberMainerAgentsAdmin '(record { mainerType = variant {Own}; })' --network $NETWORK
dfx canister call game_state_canister getLimitForCreatingMainerAdmin '(record { mainerType = variant {Own}; })' --network $NETWORK
dfx canister call game_state_canister setLimitForCreatingMainerAdmin '(record { mainerType = variant {Own}; newLimit = 0 })' --network $NETWORK
dfx canister call game_state_canister shouldCreatingMainersBeStopped '(record { mainerType = variant {Own}; })' --network $NETWORK

## Update whitelist flags
### whitelist phase active
dfx canister call game_state_canister toggleWhitelistPhaseActiveFlagAdmin --network $NETWORK
dfx canister call game_state_canister getIsWhitelistPhaseActive --network $NETWORK
### whitelist mAIner creation (sale)
dfx canister call game_state_canister togglePauseWhitelistMainerCreationFlagAdmin --network $NETWORK
dfx canister call game_state_canister getPauseWhitelistMainerCreationFlag --network $NETWORK

## Update protocol flag
dfx canister call game_state_canister togglePauseProtocolFlagAdmin --network $NETWORK
dfx canister call game_state_canister getPauseProtocolFlag --network $NETWORK

## Cycles security buffer
### in trillion cycles
dfx canister call game_state_canister setProtocolCyclesBalanceBuffer '500' --network $NETWORK
dfx canister call game_state_canister getProtocolCyclesBalanceBuffer --network $NETWORK
```

## Treasury
```bash
# same treasury for all stages
dfx canister call game_state_canister setTreasuryCanisterId '"qbhxa-ziaaa-aaaaa-qbqza-cai"' --network $NETWORK
dfx canister call game_state_canister getTreasuryCanisterId --network $NETWORK

dfx canister call game_state_canister toggleDisburseFundsToTreasuryFlagAdmin --network $NETWORK
dfx canister call game_state_canister getDisburseFundsToTreasuryFlag --network $NETWORK
```

