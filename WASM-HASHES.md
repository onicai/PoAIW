# Deployed wasm hashes

The record of **which build is deployed where**, so anyone — team or community — can
verify a canister is running the code this repo claims.

Read a deployed hash with no special rights:

```bash
dfx canister --network <network> info <canister-id>   # prints "Module hash: 0x..."
```

## Why the commit column matters

`src/mAIner/src/Main.mo` serves **two roles on different release cadences**: the
ShareService is upgraded often, the ShareAgent mAIners rarely. So the two are
normally on **different hashes**, and that is correct rather than drift.

A consequence: verifying ShareAgents means reproducing a build from a commit that
`main` has already moved past. A bare hash cannot be reproduced — the commit can:

```bash
git checkout <commit>
cd src/mAIner && make docker-build-wasm     # prints the sha256; must equal the table below
```

## How to verify

| role | where the EXPECTED hash lives | trust needed |
| ---- | ----------------------------- | ------------ |
| **ShareAgent** | **on-chain**: mAInerCreator `getSha256HashesAdmin` → `mainerControllerWasmSha256` (any non-anonymous caller may read it) | none — expected and actual are both on-chain |
| **ShareService** | this file only | you must reproduce the build from the recorded commit |

ShareAgents are the better-verifiable role, which matters because they are the ones
users own.

Verify any deployed mAIner against a local reproducible build:

```bash
cd src/mAIner
make docker-verify-wasm VERIFY_NETWORK=prd                                     # the ShareService
make docker-verify-wasm VERIFY_NETWORK=prd VERIFY_CANISTER=<mAIner-canister-id>  # any ShareAgent
```

## Artifact naming

One source builds one artifact, named after the source rather than either role:

```
src/mAIner/src/Main.mo
  └─ make docker-build-wasm → out/mainer_canister.wasm
       ├─ ShareService : dfx canister install --wasm out/mainer_canister.wasm ... <ShareService>
       └─ ShareAgents  : cp out/mainer_canister.wasm mAInerCreator/files/mainer_ctrlb_canister.wasm
                         └─ uploaded to mAInerCreator, then rolled out by scripts/upgrade_mainers.sh
```

The copy into `mAInerCreator/files/` is a **promotion gate**: it is the moment a build
becomes what ShareAgents run, and it keeps the role-specific name because
mAInerCreator deliberately holds a pinned, older build.

Calling the artifact `mainer_service_canister.wasm` (as it was until 2026-08-20)
implied it belonged to the ShareService alone — which is how ShareAgents came to be
built by a separate, non-reproducible `dfx deploy` path and drifted to a different
hash.

## mAIner (src/mAIner)

| role | deployed hash | commit | date | networks |
| ---- | ------------- | ------ | ---- | -------- |
| ShareService | `117eacbeefa5267edfb83c3a2bd9f8fcb42466935ab5fc92b05257cb5592bc7a` | *(unrecorded — predates this file)* | ? | prd, testing |
| ShareAgent | `1e07714848844284e2292de9f9fdb0d36ac94f3c8052cf41f89e39b79cd850d7` | *(unrecorded — predates this file)* | 2026-04-16 | prd, testing |

> The two hashes above differ because ShareAgents were last built via `dfx deploy`
> from `upgrade_mainers.sh`, not from the reproducible Docker build. From the next
> ShareAgent rollout onward both roles come from `make docker-build-wasm`, so every
> row below is reproducible from its commit.

## Protocol canisters

| canister | deployed hash | commit | date | networks |
| -------- | ------------- | ------ | ---- | -------- |
| GameState | | | | |
| mAInerCreator | | | | |

Add a row per rollout. Record the commit you built from, not just the hash.
