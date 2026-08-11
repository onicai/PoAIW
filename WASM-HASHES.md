# Wasm hash tracker — dfx → icp-cli migration

Baseline captured **2026-07-31**, before any migration change, with:

```bash
icp canister status <principal> -n ic -p --json    # .module_hash, no controller rights needed
```

## Why this file exists

The dfx → icp-cli migration replaces the build chain: `dfx build` (dfx 0.29.2, with its
bundled `moc`) becomes `icp build` → the `@dfinity/motoko` recipe → `mops build` + `ic-wasm
shrink`. That is a different compiler and a different pipeline, so **every Motoko wasm hash
changes**. This was an accepted, deliberate decision.

Consequence: `make docker-verify-wasm` and the `verify-wasm` CI workflow will report a
MISMATCH for every canister until that canister is redeployed with an icp-built wasm.

**Redeploying is NOT part of the migration project.** Nothing in the migration writes to
mainnet. The redeploys are a separate, later project, and this file is the handover artefact
for it — the "redeployed" boxes stay unticked until that project ticks them.

## Toolchain

|                    | before (deployed wasms) | after (this repo builds)         |
| ------------------ | ----------------------- | -------------------------------- |
| CLI                | dfx 0.29.2              | icp-cli 1.2.0                    |
| Motoko compiler    | bundled with dfx 0.29.2 | moc 1.4.1, pinned in `mops.toml` |
| package manager    | `mops sources` via dfx  | ic-mops 2.13.2                   |
| post-processing    | dfx internal            | `@icp-sdk/ic-wasm` 0.11.0 shrink |
| Node (build image) | 20                      | 22                               |
| llama_cpp_canister | v0.11.0                 | **v0.16.0** (re-vendored)        |

Both `moc` and `ic-wasm` are pinned because both change the module hash. Measured:
ic-wasm 0.9.11 vs 0.11.0 produce wasms differing by 1288 bytes in the **element section**
from byte-identical Motoko code, because `shrink` rewrites it.

## Why a local `icp build` will not match the Docker build

Motoko codegen *is* deterministic across platforms: for `challenger_ctrlb_canister`,
every wasm section built on darwin/arm64 is byte-identical to the linux/amd64 build —
code, elements, data, candid, stable-types, all of it.

The one exception is the 90-byte `icp:private moc:version` custom section. The
`@dfinity/motoko` recipe stamps `moc --version` into it verbatim, and moc reports a
build-specific hash that differs per platform:

```
linux/amd64 : Motoko compiler 1.4.1 (source k8r4z8c3-7zqv9is3-l7cx4q5j-651yrgww)
darwin/arm64: Motoko compiler 1.4.1 (source 0r7vgklj-w8ihnklx-w7qpgbif-wr0j195g)
```

So **the Docker linux/amd64 build is the canonical artifact**; `make build-wasm` is a
local convenience and will differ on macOS. `make docker-verify-wasm` always uses Docker.

## Motoko canisters

| canister                           | prd principal               | prd hash (dfx 0.29.2)                                              | new icp/mops hash                                                  | redeployed |
| ---------------------------------- | --------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------ | ---------- |
| `api_canister`                     | bgm6p-5aaaa-aaaaf-qbzda-cai | `13ef2f45052b5b914cb867a02b281440307ab6ce861ef489d34ab71a1ede5513` | TBD                                                                | ☐          |
| `archive_challenges_canister`      | yiobo-hyaaa-aaaaf-qdjnq-cai | `1220f961d72159c8ddbee7eb6f89ac71a1a054781e4db7ca90add749c37061b7` | TBD                                                                | ☐          |
| `archive_challenges_canister_orig` | 474n2-qiaaa-aaaaf-qasoq-cai | `5a5379f4117de7a6db80dcfdb0566b062b8b9ad5a64e1284b16925cceb4068fa` | n/a — retired                                                      | ☐          |
| `challenger_ctrlb_canister`        | rtoqq-yyaaa-aaaaa-qanba-cai | `47f386b76144ef1a0fccd20608c099de7c83480a9a7e87a8ae1fa64b10f97db1` | `32f74d735aceeb05668c1ed850217c5b551940ecb1a644630546e051e9aaf249` | ☐          |
| `game_state_canister`              | r5m5y-diaaa-aaaaa-qanaa-cai | `7bf1b4f185b2f7b469506b51a0d8e0bd1d9b57e5a193c4053ccc74e114c46ca6` | TBD                                                                | ☐          |
| `judge_ctrlb_canister`             | qmgdh-3aaaa-aaaaa-qanfq-cai | `24ade07da97f8e6026c15b150f81e6486360025fc846cf2eefa74bb195f7edd6` | TBD                                                                | ☐          |
| `funnai_treasury_canister`         | qbhxa-ziaaa-aaaaa-qbqza-cai | `df75427673a8a49c4cd03befdaf0c9b189e5e31e3e9f3481097ea8f5eaa006e7` | TBD                                                                | ☐          |
| `ck_signer_canister`               | g7qkb-iiaaa-aaaar-qb3za-cai | `5215cfc6bb10f5eab44a45fb3fa4813c4feb0d8bd4bec8bdd818b68929bd7c03` | TBD                                                                | ☐          |
| `mainer_creator_canister`          | r2n3m-oqaaa-aaaaa-qanaq-cai | `bc412edb423127b278b442366709a3e967687bd9143de41d3e077c49c63c195e` | TBD                                                                | ☐          |
| `mainer_service_canister`          | rilmv-caaaa-aaaaa-qandq-cai | `7e149b675f982bb948055326a22358508da2cbd472e7949aad1e2e40b0f3db6e` | TBD                                                                | ☐          |

`archive_challenges_canister_orig` uses classical persistence and is not carried into
`icp.yaml`; it is addressed by principal only.

> ⚠️ **`mainer_creator_canister` now differs by more than the toolchain.** Its source was
> changed after this baseline was taken: `src/Main.mo` sent `#upgrade(null)` to
> `install_chunked_code`, which the IC rejects for the enhanced-orthogonal-persistence mAIner
> wasm ("Missing upgrade option"), so `upgradeMainerctrl` failed on every call. It now sends
> `#upgrade(?{wasm_memory_persistence = ?#keep; skip_pre_upgrade = ?false})`. Verified on the
> local network: before the change the mAIner stayed at `"Controller Upgrade in Progress"`
> forever; after it, the upgrade completes. So the eventual hash for this row reflects a
> **functional fix as well as** the build-chain change — do not treat a mismatch here as
> toolchain-only.

## mAIner controller fleet

**744** `mainer_ctrlb_canister_N` on prd, built from the same
`PoAIW/src/mAIner/src/Main.mo` source. An 8-canister spread sample (indices 0, 1, 10, 97, 98,
99, 433, 434) is **uniform**:

|                                   | hash                                                               | redeployed |
| --------------------------------- | ------------------------------------------------------------------ | ---------- |
| all 744 `mainer_ctrlb_canister_N` | `1e07714848844284e2292de9f9fdb0d36ac94f3c8052cf41f89e39b79cd850d7` | ☐ 0 / 744  |

Note this differs from `mainer_service_canister`'s hash above — the two run different builds.

## Downloaded ICRC canisters (not built here)

| canister                 | prd principal               | prd hash                                                           |
| ------------------------ | --------------------------- | ------------------------------------------------------------------ |
| `funnAI_ledger_canister` | vpyot-zqaaa-aaaaa-qavaq-cai | `3b03d1bb1145edbcd11101ab2788517bc0f427c3bd7b342b9e3e7f42e29d5822` |
| `funnAI_index_canister`  | mziuv-biaaa-aaaaa-qccrq-cai | `e155db9d06b6147ece4f9defe599844f132a7db21693265671aa6ac60912935f` |

Unaffected by the build-chain change — nothing in this repo rebuilds them.

## LLM fleet (llama_cpp_canister)

The vendored tree is now **v0.16.0** (`PoAIW/llms/llama_cpp_canister/`), verified against
the release asset's published sha256. The prd canisters still run **v0.11.0** — upgrading
them is a mainnet operation and is deliberately not done here.

Interface delta v0.11.0 → v0.16.0, checked against every method funnAI calls:

* **additive**: 5 `opt nat64` exact-token-accounting fields on the run-success record, and
  `get_memory_status`. 125 → 133 methods; **nothing was removed**.
* **one rename**: `timestamp_ns` → `timestamp`, inside the `get_chats` record only.
  Grepped both repos: there are no `get_chats` callers, so nothing is affected.

Proven on the local e2e network, not just inspected: the deployed module hash matches the
release sha, `get_memory_status` (absent in v0.11.0) answers, and the v0.16.0 behavioural
fix works — multi-call prompt ingestion advances **without** `--prompt-cache-all`, with
`n_prompt_tokens_remaining` going 13 → 1 → 0 across successive `run_update` calls before
generation starts. That path stalls under v0.11.0.

| controller | canister | prd principal               |
| ---------- | -------- | --------------------------- |
| Challenger | `llm_0`  | psgg4-iqaaa-aaaac-qgtza-cai |
| Judge      | `llm_0`  | pvhai-fiaaa-aaaac-qgtzq-cai |
| Judge      | `llm_1`  | tem27-5yaaa-aaaam-ajawq-cai |
| Judge      | `llm_2`  | ftzot-hiaaa-aaaah-avtja-cai |
| Judge      | `llm_3`  | lk5m5-hqaaa-aaaad-agqwa-cai |
| mAIner     | `llm_0`  | q6xar-uyaaa-aaaag-ayxxq-cai |
| mAIner     | `llm_1`  | k26rl-vqaaa-aaaai-rakcq-cai |
| mAIner     | `llm_2`  | tb4fe-6qaaa-aaaac-be5tq-cai |
| mAIner     | `llm_3`  | 6tx5a-raaaa-aaaan-q6hfa-cai |

|                             | hash                                                                        | redeployed |
| --------------------------- | --------------------------------------------------------------------------- | ---------- |
| deployed on prd (v0.11.0)   | `625bf21898eb892fc822bae294439a8da0f0b5ed6240911e41d03ea45c1e9798`          |            |
| **vendored now (v0.16.0)**  | `3fd9704fd99688536527f866dad8532e2bc26f0b453de94a92bc0f3213dedec1`          | ☐ 0 / 9    |
| v0.14.0 / v0.15.0 (skipped) | `7ef7c0a1cd71717bef0641035b4b5be80f9f771e88a38de1c16d8dd114903f74` (0.14.0) |            |

The 9 prd LLM canisters each need the full sequence when that mainnet work happens:
stop → snapshot → install → start → health → `load_model` → `set_max_tokens` → pause →
re-`assignAdminRole` → re-register. All of it is exercised locally by the funnAI repo's
e2e harness: `make e2e-start-clean && make e2e-install && make e2e-test`.
