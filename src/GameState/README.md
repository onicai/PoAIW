# Build, Deploy and Verify

```bash
# Build wasm with Docker (reproducible build)
# The base image is shared across all canisters. Once built, it can be reused.
make docker-build-base
make docker-build-wasm

# Deploy the pre-built wasm
# Note: Post-SNS, this step is replaced with SNS governed deployment.
icp canister stop game_state_canister -e $NETWORK
icp canister snapshot create game_state_canister -e $NETWORK
icp canister install game_state_canister --wasm out/game_state_canister.wasm \
    -e $NETWORK --mode upgrade --wasm-memory-persistence keep -y
icp canister start game_state_canister -e $NETWORK

# Verify the deployed wasm matches the Docker build
make docker-verify-wasm VERIFY_NETWORK=$NETWORK
```

# Available Makefile targets

```bash
make help
```

See also instructions in `PoAIW/README.md`

```bash
# Run these commands from the folder: funnAI

# ----------------------------------------
# mAIner of type Own
icp canister call game_state_canister createUserMainerAgent '(record { paymentTransactionBlockId = 11; mainerConfig = record { mainerAgentCanisterType = variant {Own}; selectedLLM = opt variant {Qwen2_5_500M}; }; })'

### Copy the output from above command as the argument for next command
icp canister call game_state_canister spinUpMainerControllerCanister '(record { status = variant { Paid }; canisterType = variant { MainerAgent = variant { Own } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_745_075_669_143_980_013 : nat64; createdBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; mainerConfig = record { selectedLLM = opt variant { Qwen2_5_500M }; mainerAgentCanisterType = variant { Own };  }; address = "";  } )'

### Copy the output from above command as the argument for next command
icp canister call game_state_canister setUpMainerLlmCanister '(record { status = variant { ControllerCreated }; canisterType = variant { MainerAgent = variant { Own } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_745_075_669_143_980_013 : nat64;  createdBy = principal "be2us-64aaa-aaaaa-qaabq-cai";       mainerConfig = record { selectedLLM = opt variant { Qwen2_5_500M }; mainerAgentCanisterType = variant { Own }; }; address = "cuj6u-c4aaa-aaaaa-qaajq-cai"; } )'

### To add another LLM, call this method with same argument
icp canister call game_state_canister addLlmCanisterToMainer '(record { status = variant { ControllerCreated }; canisterType = variant { MainerAgent = variant { Own } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_745_075_669_143_980_013 : nat64;  createdBy = principal "be2us-64aaa-aaaaa-qaabq-cai";       mainerConfig = record { selectedLLM = opt variant { Qwen2_5_500M }; mainerAgentCanisterType = variant { Own }; }; address = "cuj6u-c4aaa-aaaaa-qaajq-cai"; } )'

# ----------------------------------------
# mAIner of type ShareService
# Only a controller can make these calls when the mainerAgentCanisterType = variant {ShareService}
# - No payment is due, so set paymentTransactionBlockId = 0
icp canister call game_state_canister createUserMainerAgent '(record { paymentTransactionBlockId = 0; mainerConfig = record { mainerAgentCanisterType = variant {ShareService}; selectedLLM = opt variant {Qwen2_5_500M}; }; })'

### Copy the output from above command as the argument for next command
icp canister call game_state_canister spinUpMainerControllerCanister '(record { status = variant { Paid }; canisterType = variant { MainerAgent = variant { ShareService } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_745_075_669_143_980_013 : nat64; createdBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; mainerConfig = record { selectedLLM = opt variant { Qwen2_5_500M }; mainerAgentCanisterType = variant { ShareService };  }; address = "";  } )'

### Copy the output from above command as the argument for next command
icp canister call game_state_canister setUpMainerLlmCanister '(record { status = variant { ControllerCreated }; canisterType = variant { MainerAgent = variant { ShareService } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_745_075_669_143_980_013 : nat64;  createdBy = principal "be2us-64aaa-aaaaa-qaabq-cai";       mainerConfig = record { selectedLLM = opt variant { Qwen2_5_500M }; mainerAgentCanisterType = variant { ShareService }; }; address = "cuj6u-c4aaa-aaaaa-qaajq-cai"; } )'

### To add another LLM, call this method with same argument
icp canister call game_state_canister addLlmCanisterToMainer '(record { status = variant { ControllerCreated }; canisterType = variant { MainerAgent = variant { ShareService } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_745_075_669_143_980_013 : nat64;  createdBy = principal "be2us-64aaa-aaaaa-qaabq-cai";       mainerConfig = record { selectedLLM = opt variant { Qwen2_5_500M }; mainerAgentCanisterType = variant { ShareService }; }; address = "cuj6u-c4aaa-aaaaa-qaajq-cai"; } )'

# ----------------------------------------
# mAIner of type ShareAgent

## Register ShareService if not done yet
## NOTE: When deploying with the scripts described in funnAI/README.md, this is already done...
# icp canister call game_state_canister addOfficialCanister "(record { address = \"aax3a-h4aaa-aaaaa-qaahq-cai\"; canisterType = variant {MainerAgent = variant {ShareService}}; })"

## Create ShareAgent
icp canister call game_state_canister createUserMainerAgent '(record { paymentTransactionBlockId = 12; mainerConfig = record { mainerAgentCanisterType = variant {ShareAgent}; selectedLLM = null; }; })'

### Copy the output from above command as the argument for next command
icp canister call game_state_canister spinUpMainerControllerCanister '(record {status = variant { Paid }; canisterType = variant { MainerAgent = variant { ShareAgent } }; ownedBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; creationTimestamp = 1_745_076_185_351_556_204 : nat64; createdBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe"; mainerConfig = record {       selectedLLM = null; mainerAgentCanisterType = variant { ShareAgent }; }; address = ""; } )'

## Fix issues
#
# Modify this, or use the parametrized version shown directly below
#
icp canister call game_state_canister spinUpMainerControllerCanisterForUserAdmin '(record {        status = variant { Paid };        canisterType = variant { MainerAgent = variant { ShareAgent } };        ownedBy = principal "qhvia-unzwx-ewoal-5yepy-o577x-fc4dc-qzqm3-zqirv-j3icu-3h5jj-oqe";        creationTimestamp = 1_751_064_920_866_195_118 : nat64;        createdBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe";        mainerConfig = record {          selectedLLM = null;          subnetLlm = "";          mainerAgentCanisterType = variant { ShareAgent };          cyclesForMainer = 17_185_500_000_000 : nat;          subnetCtrl = "snjp4-xlbw4-mnbog-ddwy6-6ckfd-2w5a2-eipqo-7l436-pxqkh-l6fuv-vae";        };        subnet = "";        address = "";      } )' -e $NETWORK
#
# Parametrized version of spinUpMainerControllerCanisterForUserAdmin call
#
# set the subnet where ShareAgent controllers are deployed
SUBNET=snjp4-xlbw4-mnbog-ddwy6-6ckfd-2w5a2-eipqo-7l436-pxqkh-l6fuv-vae  # prd
SUBNET=yinp6-35cfo-wgcd2-oc4ty-2kqpf-t4dul-rfk33-fsq3r-mfmua-m2ngh-jqe  # testing
SUBNET=qdvhd-os4o2-zzrdw-xrcv4-gljou-eztdp-bj326-e6jgr-tkhuc-ql6v2-yqe  # demo & development
# set the owner of the ShareAgent -> Use IConfucius for testing
OWNER=xijdk-rtoet-smgxl-a4apd-ahchq-bslha-ope4a-zlpaw-ldxat-prh6f-jqe   # IConfucius on prd         (https://funnai.onicai.com)
OWNER=xzgcn-xbt3r-nhvsl-52jlc-nl5dc-zxkbo-2ghyc-z72s5-htxbe-se35n-jqe   # IConfucius on testing     (https://6twm3-uqaaa-aaaam-qd2xa-cai.icp0.io)
OWNER=krkm3-yt4kk-ysww5-csra3-qp4an-slxy5-x2o7r-3txbe-vrr76-hle55-2ae   # IConfucius on demo        (https://l556b-uaaaa-aaaai-q3xta-cai.icp0.io)
OWNER=uim2h-2cvtu-oe76k-3mpof-t7nfe-nfr2j-ren66-as6pd-z45pc-rduv2-7ae   # IConfucius on development (https://zlbtt-2yaaa-aaaak-qufwa-cai.icp0.io)
# set the creator -> Use our admin identities for testing
CREATOR=cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe # Patrick
CREATOR=$(icp identity principal)   # your own principal
#
# Cycles to send to the mAIner during creation (sent by gamestate)
CYCLES=2_000_000_000_000
### Create a new mAIner for a user (Monitor logs of both GameState & mAInerCreator to ensure it all works)
icp canister call game_state_canister spinUpMainerControllerCanisterForUserAdmin '(record {        status = variant { Paid };        canisterType = variant { MainerAgent = variant { ShareAgent } };        ownedBy = principal "'$OWNER'";        creationTimestamp = 1_751_064_920_866_195_118 : nat64;        createdBy = principal "'$CREATOR'";        mainerConfig = record {          selectedLLM = null;          subnetLlm = "";          mainerAgentCanisterType = variant { ShareAgent };          cyclesForMainer = '$CYCLES' : nat;          subnetCtrl = "'$SUBNET'";        };        subnet = "";        address = "";      } )' -e $NETWORK

### Finish the setup of a user's mAIner that had an issue (get the mAIner entry to fix as parameter for the call, especially the creationTimestamp which is used as identifier for the mAIner entry)
### This is always on prd -> Make sure to replace the ownedBy & createdBy before running it
icp canister call game_state_canister completeMainerSetupForUserAdmin '(record {        status = variant { Paid };        canisterType = variant { MainerAgent = variant { ShareAgent } };        ownedBy = principal "kpxiy-zhtf2-dbvq6-pwk7l-rm6nz-24mmb-qojc6-fgxs6-653ef-w5lqf-dae";        creationTimestamp = 1_756_472_106_967_051_969 : nat64;        createdBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe";        mainerConfig = record {          selectedLLM = null;          subnetLlm = "";          mainerAgentCanisterType = variant { ShareAgent };          cyclesForMainer = 39_985_500_000_000 : nat;          subnetCtrl = "snjp4-xlbw4-mnbog-ddwy6-6ckfd-2w5a2-eipqo-7l436-pxqkh-l6fuv-vae";        };        subnet = "";        address = "";      } )' -e $NETWORK

## Topup issue
TRANSACTIONINDEX=31456220
MAINERADDRESS=2calm-zyaaa-aaaam-qeooq-cai
OWNER=xzgcn-xbt3r-nhvsl-52jlc-nl5dc-zxkbo-2ghyc-z72s5-htxbe-se35n-jqe
icp canister call game_state_canister completeTopUpCyclesForMainerAgentAdmin '(record { paymentTransactionBlockId = '$TRANSACTIONINDEX'; mainerAgent = record {        status = variant { Running };        canisterType = variant { MainerAgent = variant { ShareAgent } };        ownedBy = principal "'$OWNER'";        creationTimestamp = 1_756_472_106_967_051_969 : nat64;        createdBy = principal "cda4n-7jjpo-s4eus-yjvy7-o6qjc-vrueo-xd2hh-lh5v2-k7fpf-hwu5o-yqe";        mainerConfig = record {          selectedLLM = null;          subnetLlm = "";          mainerAgentCanisterType = variant { ShareAgent };          cyclesForMainer = 39_985_500_000_000 : nat;          subnetCtrl = "snjp4-xlbw4-mnbog-ddwy6-6ckfd-2w5a2-eipqo-7l436-pxqkh-l6fuv-vae";        };        subnet = "";        address = "'$MAINERADDRESS'";      }; } )' -e $NETWORK
# ----------------------------------------

## Derive new mAIner wasm hash
icp canister call game_state_canister deriveNewMainerAgentCanisterWasmHashAdmin '(record {address = "canister id of new mAIner"; textNote = "Info on update"; } )'
e.g.
icp canister call game_state_canister deriveNewMainerAgentCanisterWasmHashAdmin '(record {address = "dmalx-m4aaa-aaaaa-qaanq-cai"; textNote = "After new addCycle function"; } )'
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
icp canister call game_state_canister unlockUserMainerAgent '(record { paymentTransactionBlockId = 0;  owner = opt principal "fmx2v-tpf3n-ihkag-gag34-oknfv-tbujq-ke4oe-r42z2-lwclp-fnff3-bqe"; mainerConfig = record { mainerAgentCanisterType = variant {ShareAgent}; selectedLLM = null; cyclesForMainer = 0; subnetCtrl = ""; subnetLlm = ""; }; })' -e $NETWORK

icp canister call game_state_canister getMainerAgentCanistersAdmin -e $NETWORK

icp canister call game_state_canister getMainerAgentCanistersForUserAdmin '"dno55-cf4cu-q2wwf-udihm-tq4ul-76yti-ywaee-khuyf-urcfy-r2vcz-hae"' -e $NETWORK --output json

icp canister call game_state_canister getNumMainerAgentCanistersForUserAdmin '"dno55-cf4cu-q2wwf-udihm-tq4ul-76yti-ywaee-khuyf-urcfy-r2vcz-hae"' -e $NETWORK

## Set price of mAIner
### ShareAgent
icp canister call game_state_canister setIcpForShareAgentAdmin '10' -e $NETWORK
icp canister call game_state_canister getPriceForShareAgent -e $NETWORK
#### whitelist
icp canister call game_state_canister setIcpForWhitelistShareAgentAdmin '5' -e $NETWORK
icp canister call game_state_canister getWhitelistPriceForShareAgent -e $NETWORK

### Own
icp canister call game_state_canister setIcpForOwnMainerAdmin '1000' -e $NETWORK
icp canister call game_state_canister getPriceForOwnMainer -e $NETWORK
#### whitelist
icp canister call game_state_canister setIcpForWhitelistOwnMainerAdmin '500' -e $NETWORK
icp canister call game_state_canister getWhitelistPriceForOwnMainer -e $NETWORK

## Set limit how many mAIners may be created
### Buffer
icp canister call game_state_canister getBufferMainerCreation -e $NETWORK
icp canister call game_state_canister setBufferMainerCreation '100' -e $NETWORK
### ShareAgent
icp canister call game_state_canister getNumberMainerAgentsAdmin '(record { mainerType = variant {ShareAgent}; })' -e $NETWORK
icp canister call game_state_canister getLimitForCreatingMainerAdmin '(record { mainerType = variant {ShareAgent}; })' -e $NETWORK
icp canister call game_state_canister setLimitForCreatingMainerAdmin '(record { mainerType = variant {ShareAgent}; newLimit = 697 })' -e $NETWORK
icp canister call game_state_canister shouldCreatingMainersBeStopped '(record { mainerType = variant {ShareAgent}; })' -e $NETWORK
### Own
icp canister call game_state_canister getNumberMainerAgentsAdmin '(record { mainerType = variant {Own}; })' -e $NETWORK
icp canister call game_state_canister getLimitForCreatingMainerAdmin '(record { mainerType = variant {Own}; })' -e $NETWORK
icp canister call game_state_canister setLimitForCreatingMainerAdmin '(record { mainerType = variant {Own}; newLimit = 0 })' -e $NETWORK
icp canister call game_state_canister shouldCreatingMainersBeStopped '(record { mainerType = variant {Own}; })' -e $NETWORK

## Update whitelist flags
### whitelist phase active
icp canister call game_state_canister toggleWhitelistPhaseActiveFlagAdmin -e $NETWORK
icp canister call game_state_canister getIsWhitelistPhaseActive -e $NETWORK
### whitelist mAIner creation (sale)
icp canister call game_state_canister togglePauseWhitelistMainerCreationFlagAdmin -e $NETWORK
icp canister call game_state_canister getPauseWhitelistMainerCreationFlag -e $NETWORK

## Update protocol flag
icp canister call game_state_canister togglePauseProtocolFlagAdmin -e $NETWORK
icp canister call game_state_canister getPauseProtocolFlag -e $NETWORK

## Cycles security buffer
### in trillion cycles
icp canister call game_state_canister setProtocolCyclesBalanceBuffer '500' -e $NETWORK
icp canister call game_state_canister getProtocolCyclesBalanceBuffer -e $NETWORK
```

## Treasury
```bash
# same treasury for all stages
icp canister call game_state_canister setTreasuryCanisterId '"qbhxa-ziaaa-aaaaa-qbqza-cai"' -e $NETWORK
icp canister call game_state_canister getTreasuryCanisterId -e $NETWORK

icp canister call game_state_canister toggleDisburseFundsToTreasuryFlagAdmin -e $NETWORK
icp canister call game_state_canister getDisburseFundsToTreasuryFlag -e $NETWORK
```

# Top-up scenarios

GameState exposes two top-up endpoints:

- `topUpCyclesForMainerAgent` — owner-gated; only the mAIner's owner may call.
- `topUpCyclesForAnyMainerAgent` — ungated; any authenticated caller may call.

The **ungated** endpoint requires the ICP payment to include an ICRC-1 memo blob whose first byte is `0xAD` (the `MEMO_PAYMENT` marker) followed by the raw principal bytes of the target mAIner. Without this binding, the redeem is rejected. This prevents an attacker from front-running a third-party's transfer and redirecting the cycles to a different mAIner.

Errors that reject a memo include the offending block ID and target mAIner address, e.g. `Memo of payment block 12345 doesn't bind to target mAIner xxxxx-cai`.

## Rollout phases

The change rolls out in three phases:

- **Phase 1 — GameState upgraded, frontend not yet upgraded.** The new canister code is live: ungated `topUpCyclesForAnyMainerAgent` strictly requires the bound memo; gated `topUpCyclesForMainerAgent` accepts both the bound memo and the legacy 1-byte memo `[0xAD]`. The deployed frontend is still the old version, so it sends the legacy memo — that's fine because the gated endpoint dual-accepts.
- **Phase 2 — Frontend upgraded; migration window.** The new frontend is deployed and now sends the bound memo. Cached browsers may still have the old frontend, so the gated endpoint continues to dual-accept. This window stays open until legacy memo usage drops to ~zero (target ≥30 days, monitor `D.print` logs).
- **Phase 3 — Legacy memo turned off in GameState.** The gated endpoint is flipped to require the bound memo too (`requireBoundMemo = true`). Any cached frontend still sending the legacy memo will see `Err(Other("Memo of payment block <BLOCK> is missing or invalid for target mAIner <ADDRESS>"))` and need to refresh.

## Scenarios

| # | Scenario | Endpoint | Phase 1 (canister upgraded, old FE) | Phase 2 (new FE, dual-accept window) | Phase 3 (legacy off) |
| - | -------- | -------- | ----------------------------------- | ------------------------------------ | -------------------- |
| 1 | Owner tops up their own mAIner with the bound memo (manually via the CLI in Phase 1; via UI from Phase 2 onward) | `topUpCyclesForMainerAgent` | `Ok` | `Ok` | `Ok` |
| 2 | Owner tops up their own mAIner with the legacy memo `[0xAD]` (deployed frontend in Phase 1; cached old frontend in Phase 2) | `topUpCyclesForMainerAgent` | `Ok` | `Ok` | `Err(Other("Memo of payment block <BLOCK> is missing or invalid for target mAIner <ADDRESS>"))` |
| 3 | Anyone tops up someone else's mAIner with the bound memo (gift) | `topUpCyclesForAnyMainerAgent` | `Ok` | `Ok` | `Ok` |
| 4 | Replay: same `paymentTransactionBlockId` redeemed twice | either | second call → `Err(Other("Already redeemd this transaction block"))` | same | same |
| 5 | Front-run: attacker redeems a third-party's block to a different mAIner | `topUpCyclesForAnyMainerAgent` | `Err(Other("Memo of payment block <BLOCK> doesn't bind to target mAIner <ADDRESS>"))` | same | same |
| 6 | Missing or invalid memo on ungated endpoint | `topUpCyclesForAnyMainerAgent` | `Err(Other("Memo of payment block <BLOCK> is missing or invalid for target mAIner <ADDRESS>"))` | same | same |
| 7 | Anonymous caller | either | `Err(Unauthorized)` | same | same |

## Testing

Tests are split by which entry point they exercise:

- **Gated endpoint (Scenarios 1 & 2):** must be tested **via the UI** — see the note in the "Positive tests" section.
- **Ungated endpoint and adversarial cases (Scenarios 3–8):** tested with the CLI and a fresh `topup-tester` identity, as detailed below.

Source `scripts/canister_ids-$NETWORK.env` from the funnAI repo root and use `$SUBNET_0_1_GAMESTATE` in commands below.

### One-time setup

```bash
# Create a brand-new identity
icp identity new topup-tester --storage plaintext

TOPUP_TESTER_PRINCIPAL=$(icp identity principal --identity topup-tester)
TOPUP_TESTER_ACCOUNT=$(icp identity account-id --identity topup-tester)
echo "topup-tester principal: $TOPUP_TESTER_PRINCIPAL"
echo "topup-tester account:   $TOPUP_TESTER_ACCOUNT"

# Fund it with 1 ICP - Just sent it from any wallet or you can also sent it 

# Export a plaintext PEM for the Python `pay_topup` helper (used in Scenarios 3, 4,
# 6, 7). icp-cli may have stored the identity encrypted in your OS keyring; this command
# decrypts it (you'll be prompted for the password) and writes a plaintext PEM.
# It does NOT change how icp-cli itself uses the identity — icp-cli still reads from the
# keyring when --identity topup-tester is passed.
icp identity export topup-tester > ~/.config/icp/identity/topup-tester/identity.pem
chmod 600 ~/.config/icp/identity/topup-tester/identity.pem

# Set the ICP ledger canister id (mainnet / testing — same canister id on every network)
ICP_LEDGER=ryjl3-tyaaa-aaaaa-aaaba-cai
```

> **The transfer step uses Python (`icp-py-core`), not the CLI.** Rationale and the `pay_topup` helper are a few sections below ("Send the ICP via `icp-py-core`"). The redeem step still uses `icp canister call ... topUpCyclesForAnyMainerAgent` since that argument has no blob escapes.

### Memo helper

```bash
# Requires icp-py-core in the active conda env: pip install icp-py-core
# Note: the funnAI conda env has it already installed
make_memo() {
    local target="$1"
    python3 -c "
from icp_principal import Principal
target = Principal.from_str('$target')
memo = bytes([0xAD]) + target.bytes
print(''.join(f'\\\\\\\\{b:02X}' for b in memo))
"
}
# test usage:
TARGET_MAINER=xxxxxx-cai
MEMO=$(make_memo "$TARGET_MAINER")
echo $MEMO
```

### Sanity-check the memo

Before sending ICP, decode the memo bytes back to a principal and confirm they match `$TARGET_MAINER`. Catches typos, accidental shell-escaping, or wrong-target memos before any funds move.

```bash
verify_memo() {
    local memo="$1"
    python3 -c "
import re
from icp_principal import Principal
memo = r'''$memo'''
hex_bytes = re.findall(r'\\\\([0-9A-Fa-f]{2})', memo)
raw = bytes(int(b, 16) for b in hex_bytes)
print(f'marker byte:    0x{raw[0]:02X} (expected 0xAD)')
print(f'target decoded: {Principal(raw[1:]).to_str()}')
"
}

# Usage:
verify_memo "$MEMO"
# Expected output:
#   marker byte:    0xAD (expected 0xAD)
#   target decoded: <should match $TARGET_MAINER>
```

### Send the ICP via `icp-py-core` (`scripts/pay_topup.py`)

> **Why Python instead of the CLI?** Both CLI paths were tried under dfx and both failed
> (this predates the icp-cli migration and has not been re-tested since):
> - `dfx ledger transfer` (legacy) only accepts an 8-byte `--memo <Nat64>`, so it can't carry the bound memo at all.
> - `dfx canister call <ICP_LEDGER> icrc1_transfer "(record { ... memo = opt blob \"\AD\00...\"; ... })"` looks correct on paper, but **dfx 0.29.x mis-parses the blob hex-escape syntax** — an 11-byte memo (1 marker + 10 principal bytes) is inflated past the ICP ledger's 32-byte `MEMO_SIZE_BYTES` limit and triggers the trap `the memo field is too large`. Verified via `icp-py-core`: the same 11-byte memo is accepted (the only error is `Err(InsufficientFunds)` from the unfunded test identity), proving the encoding is what's wrong, not the memo itself.
>
> The redeem step (`icp canister call <GameState> topUpCyclesForAnyMainerAgent ...`) works fine because its argument doesn't include a blob escape.

The transfer is implemented in `PoAIW/src/GameState/scripts/pay_topup.py`. It always uses the `topup-tester` identity (loaded from the exported plaintext PEM at `~/.config/icp/identity/topup-tester/identity.pem`) and sends 0.1 ICP. The two arguments are the target mAIner canister id and GameState's canister id; on success it prints the ICP-ledger block index on stdout (capture-friendly).

Define a tiny shell wrapper so the scenarios stay short — paste this once at the top of your testing session:

```bash
# Resolve the script path relative to the PoAIW repo root (PoAIW is a
# separate git repo nested inside funnAI/, so git rev-parse from anywhere
# under PoAIW returns the PoAIW directory). Works from any subdirectory
# inside PoAIW, including PoAIW/src/GameState/ where you'll likely be running.
PAY_TOPUP_PY="$(git rev-parse --show-toplevel)/src/GameState/scripts/pay_topup.py"
pay_topup() { python3 "$PAY_TOPUP_PY" "$1" "$SUBNET_0_1_GAMESTATE"; }

# Sanity check
BLOCK=$(pay_topup "$TARGET_MAINER")
echo "Block index: $BLOCK"
```

---

## Positive tests (these should all succeed)

These exercise the legitimate flows and confirm the new memo-binding logic doesn't regress them.

> **Note on the gated endpoint (Scenarios 1 & 2):** these must be tested **through the UI**, not from the command line. The gated `topUpCyclesForMainerAgent` requires (a) the caller to be the mAIner owner and (b) a full `OfficialMainerAgentCanister` record passed as `mainerAgent` — the frontend already has both, but constructing the record by hand in `dfx` is impractical. The legacy-vs-bound memo behavior is the responsibility of the deployed frontend version, so the UI is what we want to exercise.

### Scenario 1 — Owner tops up their own mAIner via gated endpoint using bound memo — test via UI once UI is upgraded

This is the happy path for the deployed **new** frontend (Phase 2 onward).

1. Open the production frontend in a **fresh** browser session (clear cache or use a private window so you definitely load the new build).
2. Log in as the owner of one of your mAIners (e.g. via Internet Identity).
3. Open the **Top up** modal for that mAIner. The target canister id shown in the modal is what the memo will bind to.
4. Choose a token (ICP, ckBTC, …), enter an amount, confirm.
5. Wait for the success toast. The mAIner's cycle balance should increase by roughly the converted amount (`icp canister status <mAIner -e $NETWORK canister id> | grep Balance` before/after).
6. Inspect the resulting ICP-ledger block (block index visible in the success notification or the browser console). The `icrc1_memo` field must be `[0xAD] ++ <target principal bytes>` — i.e. byte 0 = `0xAD`, bytes 1..N match `Principal.toBlob(<target mAIner canister id>)`.

### Scenario 2 — Owner tops up with legacy memo (gated, Phase-1/2 dual-accept) — test via UI before UI upgrade

This validates the migration window: the **old** frontend (or a cached copy of it) keeps working until Phase 3.

1. Reproduce a session running the old frontend.
2. Log in as the owner; top up one of your mAIners through the UI.
3. **Expected (Phase 1 & Phase 2):** redeem succeeds; the resulting ledger block carries the legacy 1-byte memo `[0xAD]`. GameState's `D.print` log shows `verifyIncomingPayment - #MainerTopUp legacy memo accepted (Phase 1 dual-accept)`.
4. **Expected (Phase 3, after the legacy switch is flipped):** the redeem fails with `Err(Other("Memo of payment block <BLOCK> is missing or invalid for target mAIner <OWN_MAINER>"))`. The user must hard-refresh to pick up the new frontend.

### Scenario 3 — `topup-tester` tops up someone else's mAIner (ungated, gift)

```bash
# 1. (Optional) sanity-check the bound memo
MEMO=$(make_memo "$TARGET_MAINER")
verify_memo "$MEMO"

# 2. Verify topup-tester has funds
icp token balance -n ic

# 3. Send 0.1 ICP via icp-py-core; pay_topup prints the block index on success
BLOCK=$(pay_topup "$TARGET_MAINER")
echo "Block: $BLOCK"

# 4. Redeem on the ungated endpoint
icp canister call "$SUBNET_0_1_GAMESTATE" topUpCyclesForAnyMainerAgent -n ic \
    "(record { mainerAgentAddress = \"$TARGET_MAINER\"; paymentTransactionBlockId = $BLOCK : nat64 })"
# expect: Ok with cyclesAdded > 0 and mainerAgentAddress == TARGET_MAINER
```

---

## Adversarial tests (these should all be rejected)

These confirm the new defenses fire and the existing ones still work. Run them as `topup-tester` to simulate a third party who isn't the mAIner owner.

### Scenario 4 — Replay rejected

```bash
# Re-run any successful redeem from above with the same BLOCK
icp canister call "$SUBNET_0_1_GAMESTATE" topUpCyclesForAnyMainerAgent -n ic \
    "(record { mainerAgentAddress = \"$TARGET\"; paymentTransactionBlockId = $BLOCK : nat64 })"
# expect: Err(Other("Already redeemd this transaction block"))
```

### Scenario 5 — Misdirection attempt rejected (ungated)

```bash
LEGIT_TARGET="$TARGET_MAINER"
ATTACKER_TARGET="xxxxx-cai"  # some other mAIner

# 1. (Optional) sanity-check the memo will bind to LEGIT_TARGET
MEMO=$(make_memo "$LEGIT_TARGET")
verify_memo "$MEMO"

# 2. Send the ICP with memo bound to LEGIT_TARGET
BLOCK=$(pay_topup "$LEGIT_TARGET")
echo "Block: $BLOCK"

# 3. Try to misdirect the redeem to ATTACKER_TARGET
icp canister call "$SUBNET_0_1_GAMESTATE" topUpCyclesForAnyMainerAgent -n ic \
    "(record { mainerAgentAddress = \"$ATTACKER_TARGET\"; paymentTransactionBlockId = $BLOCK : nat64 })"
# expect: Err(Other("Memo of payment block <BLOCK> doesn't bind to target mAIner <ATTACKER_TARGET>"))

# 4. Redeem to the correct (memo-bound) target — succeeds
icp canister call "$SUBNET_0_1_GAMESTATE" topUpCyclesForAnyMainerAgent -n ic \
    "(record { mainerAgentAddress = \"$LEGIT_TARGET\"; paymentTransactionBlockId = $BLOCK : nat64 })"
# expect: Ok
```

### Scenario 6 — Missing / invalid memo rejected (ungated)

`pay_topup` always sets the bound memo, so for this rejection test we use a sibling helper, `scripts/pay_topup_test_no_memo.py`, that sends the same 0.1 ICP transfer **without any memo**. Define a thin shell wrapper alongside `pay_topup`:

```bash
# Resolve relative to the PoAIW repo root (same convention as PAY_TOPUP_PY)
PAY_TOPUP_NO_MEMO_PY="$(git rev-parse --show-toplevel)/src/GameState/scripts/pay_topup_test_no_memo.py"
pay_topup_test_no_memo() { python3 "$PAY_TOPUP_NO_MEMO_PY" "$SUBNET_0_1_GAMESTATE"; }
```

Then run the scenario:

```bash
# 1. Send 0.1 ICP with NO memo; capture the block index
BLOCK=$(pay_topup_test_no_memo)
echo "Block: $BLOCK"

# 2. Try to redeem — should fail because the memo is missing
icp canister call "$SUBNET_0_1_GAMESTATE" topUpCyclesForAnyMainerAgent -n ic \
    "(record { mainerAgentAddress = \"$TARGET_MAINER\"; paymentTransactionBlockId = $BLOCK : nat64 })"
# expect: Err(Other("Memo of payment block <BLOCK> is missing or invalid for target mAIner <TARGET_MAINER>"))
```

### Scenario 7 — Anonymous caller rejected

```bash
icp canister call "$SUBNET_0_1_GAMESTATE" topUpCyclesForAnyMainerAgent -n ic --identity anonymous \
    "(record { mainerAgentAddress = \"$TARGET_MAINER\"; paymentTransactionBlockId = $BLOCK : nat64 })"
# expect: Err(Unauthorized)
```

---

### Cleanup

```bash
icp identity delete topup-tester
```

