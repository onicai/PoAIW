# GameStateSidecar

Daily sweep for ICP top-up payments that have aged out of the ledger's live window.

## Why it exists

GameState credits a mAIner when someone pays ICP to its account with the mAIner's
canister-id prefix in the `icrc1_memo`, then calls `notifyMainerTopUp` with the
ledger block id.

The problem is how short the ledger's live window is. Measured on mainnet:

| | |
| ------------------- | ------------------------ |
| `chain_length`      | 38,035,664               |
| `first_block_index` | 38,034,000               |
| Live window         | 1,664 blocks             |
| In time             | 9,519 s ≈ **2 h 39 min** |

It is a sawtooth, not a constant — the ledger flushes batches to the archive, so the
window collapses after each flush and regrows. Working range is roughly **1.5–3
hours**, and it shrinks as ICP transaction volume rises. There is no time guarantee.

A payment not redeemed inside that window used to be unreachable through *every*
path, including the controller-only `completeTopUpCyclesForMainerAgentAdmin`, which
read the ledger the same way. This canister, plus GameState's archive-aware read,
closes that.

## How it works

```
        ┌──────────────────┐   1. get_account_identifier_transactions
        │ GameStateSidecar │ ─────────────────────────────────────────▶ ICP index
        │   (24h timer)    │ ◀───────────────────────────────────────── qhbym-…-cai
        └────────┬─────────┘      TransactionWithId { id, transaction }
                 │
                 │ 2. sweepArchivedTopUp({ blockId })    ← block id ONLY
                 ▼
        ┌──────────────────┐   3. query_blocks → archived_blocks.callback
        │    GameState     │ ─────────────────────────────────────────▶ ICP ledger
        │                  │ ◀───────────────────────────────────────── ryjl3-…-cai
        └──────────────────┘   4. resolve memo → deliver cycles to mAIner
```

The index is used for **discovery** — it resolves archived transactions
transparently and is queryable by account. The ledger's own archive callback is used
for **verification**, because that is what GameState can check for itself.

Only **archived** blocks are swept. Anything still in the live window belongs to the
public `notifyMainerTopUp` endpoint, so the two never race. Coverage is still
complete: a block skipped today as "still live" has aged into the archive by the next
run.

## The security boundary

**The sidecar sends a block id and nothing else.** It never tells GameState which
mAIner a payment belongs to — GameState re-reads the block and resolves the memo
itself, exactly as it does for the public endpoint.

That makes this canister a *scheduler*, not something trusted with attribution. A
compromised or buggy sidecar can waste cycles pointing at junk blocks; it cannot
redirect anyone's payment. If a future change has it pass a mAIner address, that
argument collapses — don't.

The archive read is deliberately **not** exposed on the public endpoint. The miss
path is exactly the path an abusive caller picks (nobody spamming block ids sends a
live valid one), so following the archive there would double the ledger work an
unauthenticated caller can force GameState to pay for.

## Cursor and retries

The index has no forward pagination: `start` is exclusive and results come
newest-first. So each run pages backwards until it crosses the cursor, then offers
candidates oldest-first.

- **`scannedThroughBlockId`** — everything at or below is dealt with. It advances
  *unconditionally* past terminal outcomes.
- **`pendingRetries`** — blocks that failed for a *transient* reason, with an attempt
  count, self-evicting after 5 tries.

Both are needed. Advancing past a transient failure with no retry set would burn the
payment; refusing to advance would let one permanently-broken mAIner pin the cursor
forever while each run re-scans a growing tail.

The cursor only advances if the run actually paged back to it. If it hits
`MAX_PAGES_PER_RUN` first there is an unexamined gap, and advancing would skip those
payments for good — `getSidecarStatusAdmin` surfaces this so a stalled backfill is
visible rather than silent.

## Operating it

**Seed the cursor at deploy time.** It defaults to 0, and a first run from 0 would
walk GameState's entire account history:

```
dfx canister --network $NETWORK call $SIDECAR setScannedThroughBlockIdAdmin '(38034000 : nat64)'
```

**Register with GameState** (controller-only, on GameState):

```
dfx canister --network $NETWORK call $SUBNET_0_1_GAMESTATE addSidecarCanisterAdmin '("<sidecar-canister-id>")'
```

**Point it at GameState and arm the timer:**

```
dfx canister --network $NETWORK call $SIDECAR setGameStateCanisterId '("<gamestate-canister-id>")'
dfx canister --network $NETWORK call $SIDECAR startTimerExecutionAdmin
```

**⚠️ The timer does not survive an upgrade.** Only the stable timer *id* persists;
the IC's registration does not. Re-arm with `startTimerExecutionAdmin` after **every**
upgrade, the same as Challenger, Judge and ShareService. A dead sweep timer looks
exactly like a sweep with nothing to do, which is why `ready` reports an unarmed
timer as not-ready and `getSidecarStatusAdmin` reports `timerIsArmed`.

**Check on it:**

```
dfx canister --network $NETWORK call $SIDECAR getSidecarStatusAdmin
```

Alert on `lastRunAt` older than 48 h.

## Cycles

The sidecar cannot earn cycles, so GameState funds it. Once a day, at the end of its
sweep, it checks its own balance and — if below `MIN_CYCLES_BALANCE_SIDECAR`
(default 5 T) — calls `requestCyclesForSidecar()`.

GameState owns the policy: it sets the amount (default 10 T), rate limits to one
grant per sidecar per day, and refuses outright when its own balance is below
`SIDECAR_GRANT_FLOOR`. The sidecar only reports that it is low, so a compromised one
cannot enlarge its own ask. Grants are recorded in a bounded ring readable via
`getCyclesGrantsAdmin`.

`SIDECAR_GRANT_FLOOR` is deliberately separate from `PROTOCOL_CYCLES_BALANCE_BUFFER`.
That one also drives the bonus-cycles percentage and the CMC-conversion trigger, so
tuning it to let a grant through would silently re-enable bonus cycles on every user
top-up.

## Testing

```
make smoketest
```

Starts a clean local replica, deploys, and runs the pytest suite.

**Scope limit, stated plainly:** these tests cover the endpoint gates, the admin
setters, the timer lifecycle and the account-identifier derivation. The sweep itself
is *not* exercised — it needs the ICP index and a GameState canister, and the local
dfx network has neither. That is left to a deployed environment rather than faked
with an assertion that always passes.

The account-identifier test is the one piece of real sweep logic reachable locally,
and it earns its place: the index takes the account as hex **text** while the ledger
uses a 32-byte **blob**, and the index answers a wrong identifier with an *empty
transaction list* rather than an error. A mistake there would look exactly like
having nothing to sweep.

## Build

`make smoketest` builds with plain `dfx deploy`, unlike the sibling canisters. The
reproducible docker build runs `dfx build --network prd`, which needs a prd canister
id in `canister_ids.json`, and this canister has not been deployed anywhere yet.
Once it has been created on a real network, switch the `smoketest` target to
`docker-build-wasm` + `dfx canister install`, matching `src/Challenger/Makefile`.
