# mAIning Pool Quick Reference

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      mAIning Pool Canister                   │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Current    │  │     Next     │  │   Archived   │     │
│  │ Participants │  │ Participants │  │    Cycles    │     │
│  │  (Active)    │  │ (Committed)  │  │  (History)   │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                              │
│  ┌──────────────────────────────────────────────────┐      │
│  │         Pool mAIners (3-20 controlled)           │      │
│  │  mAIner1, mAIner2, mAIner3, ... mAInerN         │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
         ▲                    │                    ▲
         │                    │                    │
    ICP  │              FUNNAI│               Cycles│
Contributions          Rewards            (from ICP)
         │                    │                    │
┌────────┴────────┐  ┌────────▼────────┐  ┌────────┴────────┐
│  Participants   │  │  Participants   │  │  Game State     │
│   (Users)       │  │   (Rewards)     │  │   Canister      │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

## Weekly Timeline

```
Sunday        Monday         Tuesday - Sunday       Sunday (EOD)
   |             |                  |                    |
   |             |                  |                    |
   v             v                  v                    v
Commit      Cycle Start         mAIning             Commit
Deadline    - Distribute        Continues           Deadline
            - Archive           - Earn FUNNAI       (Next Week)
            - Topup mAIners     - Burn cycles
            - Set burn rates
```

## Function Categories

### 👤 User Functions (Public)
- `contributeToNextPool(icpAmountE8S, burnFunnai)` - Commit ICP for next week
- `getMyCurrentPoolContribution()` - View active contribution
- `getMyNextPoolContribution()` - View next week commitment
- `getMyHistory()` - View all past participation

### 📊 Query Functions (Public)
- `getCurrentPoolStats()` - Active pool statistics
- `getNextPoolStats()` - Next pool commitments
- `getPoolConfiguration()` - Pool settings and limits
- `getAggregatedHistory()` - Lifetime pool statistics
- `getPoolBalances()` - Current ICP & FUNNAI balances
- `getPoolMainers()` - View all pool mAIners
- `getArchivedPoolCycle(cycleId)` - View specific past cycle
- `getAllArchivedPoolCycles()` - View all past cycles
- `getArchivedCycleParticipants(cycleId)` - View cycle participants

### 🔧 Admin Functions (Controller Only)
- `startNextPoolCycle(weekStart, weekEnd)` - **Critical weekly function**
- `addPoolMainer(address, type)` - Add mAIner to pool
- `removePoolMainer(address)` - Remove mAIner from pool
- `updatePoolBalances(icp, funnai)` - Manual balance update
- `accrueFunnaiRewards(amount)` - Record mAIner rewards

### ⚙️ System Functions
- `setGameStateCanisterId(id)` - Configure Game State
- `getGameStateCanisterId()` - View Game State ID
- `whoami()` - Identity check
- `health()` - Canister health status
- `amiController()` - Controller verification

## Configuration Constants

| Constant | Value | Description |
|----------|-------|-------------|
| MIN_ICP_CONTRIBUTION_E8S | 100_000_000 | 1 ICP minimum |
| MAX_ICP_CONTRIBUTION_E8S | 1_000_000_000_000 | 10,000 ICP maximum |
| FUNNAI_BURN_AMOUNT | 10_000_000 | 0.1 FUNNAI for new entrants |
| TREASURY_FEE_PERCENTAGE | 10 | 10% of ICP goes to treasury |

## Common Workflows

### New Participant Flow
1. User approves FUNNAI burn (0.1 FUNNAI)
2. User approves ICP transfer (≥1 ICP)
3. User calls `contributeToNextPool(amount, true)`
4. Pool records commitment for next cycle
5. Monday: admin starts cycle, next cycle becomes active
6. Week: pool mAIners earn rewards
7. Next Monday: pool distributes FUNNAI to user

### Returning Participant Flow
1. User approves ICP transfer
2. User calls `contributeToNextPool(amount, false)` (no burn!)
3. Rest same as new participant

### Weekly Admin Flow
1. Sunday ends (commitment phase closes)
2. Monday 00:00 UTC: admin calls `startNextPoolCycle()`
3. Function distributes last week's FUNNAI
4. Function archives completed cycle
5. Function promotes next → current participants
6. Function tops up mAIners
7. Function sets mAIner burn rates
8. New week begins

## Monitoring Checklist

Daily:
- [ ] Check pool balances
- [ ] Verify mAIner cycles balances
- [ ] Check reward accrual

Weekly (Monday):
- [ ] Execute `startNextPoolCycle()`
- [ ] Verify distributions completed
- [ ] Check all mAIners topped up
- [ ] Verify burn rates set correctly
- [ ] Review participant count

Monthly:
- [ ] Review aggregated statistics
- [ ] Check for failed distributions
- [ ] Verify data archival
- [ ] Monitor canister cycles

## Testing Quick Commands

```bash
# Check pool status
dfx canister call mAIningPool getCurrentPoolStats

# View my participation
dfx canister call mAIningPool getMyCurrentPoolContribution

# Contribute (testnet)
dfx canister call mAIningPool contributeToNextPool '(200_000_000, false)'

# Start cycle (admin only)
dfx canister call mAIningPool startNextPoolCycle '(1737331200, 1737935999)'

# View mAIners
dfx canister call mAIningPool getPoolMainers

# Check balances
dfx canister call mAIningPool getPoolBalances
```
