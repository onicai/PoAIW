# GameStateSidecar

Daily sweep for ICP top-up payments that have aged out of the ledger's live window.

## Why it exists

GameState credits a mAIner when someone pays ICP to its account with the mAIner's
canister-id prefix in the `icrc1_memo`, then calls `notifyMainerTopUp` with the
ledger block id.

The ICP ledger only serves a short live window. Measured on mainnet:

| | |
| ------------------- | ------------------------ |
| `chain_length`      | 38,035,664               |
| `first_block_index` | 38,034,000               |
| Live window         | 1,664 blocks             |
| In time             | 9,519 s ≈ **2 h 39 min** |

It is a sawtooth: the ledger flushes batches to the archive, so the window collapses
after each flush and regrows. Working range is roughly **1.5–3 hours**, shrinking as
ICP transaction volume rises. There is no time guarantee.

A payment not redeemed inside that window used to be unreachable through every path,
including the controller-only `completeTopUpCyclesForMainerAgentAdmin`. This
canister, plus GameState's archive-aware read, closes that.

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

The index is used for **discovery**: it resolves archived transactions transparently
and is queryable by account. The ledger's archive callback is used for
**verification**, because that is what GameState can check for itself.

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
path is exactly the path an abusive caller takes, so following the archive there
would double the ledger work an unauthenticated caller can force GameState to pay
for.

## Cursor and retries

The index has no forward pagination: `start` is exclusive and results come
newest-first. Each run pages backwards until it crosses the cursor, then offers
candidates oldest-first.

- **`scannedThroughBlockId`** — everything at or below is dealt with. Advances
  *unconditionally* past terminal outcomes.
- **`pendingRetries`** — blocks that failed for a *transient* reason, with an attempt
  count, self-evicting after 5 tries.

Both are needed. Advancing past a transient failure with no retry set would burn the
payment; refusing to advance would let one broken mAIner pin the cursor forever.

The cursor only advances if the run actually paged back to it. If it hits
`MAX_PAGES_PER_RUN` first there is an unexamined gap, and advancing would skip those
payments for good — `getSidecarStatusAdmin` surfaces this.

## Operating it

**Seed the cursor at deploy time.** It defaults to 0, and a first run from 0 would
walk GameState's entire account history:

```
dfx canister --network $NETWORK call $SIDECAR setScannedThroughBlockIdAdmin '(38034000 : nat64)'
```

**Register with GameState** (controller-only, on GameState). One sidecar only; an
occupied slot is refused, so rotating means `removeSidecarCanisterAdmin` first:

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
grant per day, and refuses when its own balance is below `SIDECAR_GRANT_FLOOR`. The
sidecar only reports that it is low, so it cannot enlarge its own ask. Grants are
recorded in a bounded ring readable via `getCyclesGrantsAdmin`.

`SIDECAR_GRANT_FLOOR` is separate from `PROTOCOL_CYCLES_BALANCE_BUFFER`, which also
drives the bonus-cycles percentage and the CMC-conversion trigger — tuning that one
to let a grant through would re-enable bonus cycles on every user top-up.

## Testing

```
make smoketest
```

Starts a clean local replica, deploys, and runs the pytest suite.

**Scope limit:** these tests cover the endpoint gates, the admin setters, the timer
lifecycle and the account-identifier derivation. The sweep itself is *not* exercised
— it needs the ICP index and a GameState canister, and a local dfx network has
neither.

The account-identifier test is the one piece of real sweep logic reachable locally.
The index takes the account as hex **text** while the ledger uses a 32-byte **blob**,
and it answers a wrong identifier with an *empty transaction list* rather than an
error, so a mistake there looks exactly like having nothing to sweep.

## Build

`make smoketest` builds with plain `dfx deploy`, unlike the sibling canisters. The
reproducible docker build runs `dfx build --network prd`, which needs a prd canister
id in `canister_ids.json`, and this canister has not been deployed anywhere yet.
Once it exists on a real network, switch the `smoketest` target to
`docker-build-wasm` + `dfx canister install`, matching `src/Challenger/Makefile`.
