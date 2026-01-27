# mAIning Pool Usage Examples

## For Pool Participants

### 1. First-Time Participation

```javascript
// Step 1: Approve FUNNAI burn (frontend call to FUNNAI ledger)
await funnaiLedger.approve({
  spender: poolCanisterPrincipal,
  amount: 10_000_000n, // 0.1 FUNNAI
});

// Step 2: Approve ICP transfer (frontend call to ICP ledger)
await icpLedger.approve({
  spender: poolCanisterPrincipal,
  amount: 200_000_000n, // 2 ICP in e8s
});

// Step 3: Contribute to pool
const result = await poolCanister.contributeToNextPool(
  200_000_000n, // 2 ICP
  true         // burnFunnai = true for first time
);

// Result: { Ok: 200_000_000 } (your total contribution)
```

### 2. Continuing Participation (No FUNNAI Burn)

```javascript
// Step 1: Approve ICP transfer only
await icpLedger.approve({
  spender: poolCanisterPrincipal,
  amount: 300_000_000n, // 3 ICP
});

// Step 2: Contribute to pool
const result = await poolCanister.contributeToNextPool(
  300_000_000n, // 3 ICP
  false         // burnFunnai = false (participated last week)
);
```

### 3. Adding More to Existing Contribution

```javascript
// Can contribute multiple times before cycle starts
// Contributions accumulate

// First contribution this week
await poolCanister.contributeToNextPool(200_000_000n, false);
// Result: { Ok: 200_000_000 }

// Add more before Sunday deadline
await poolCanister.contributeToNextPool(100_000_000n, false);
// Result: { Ok: 300_000_000 } (cumulative)
```

### 4. Check Your Contributions

```javascript
// Check current active pool contribution
const current = await poolCanister.getMyCurrentPoolContribution();
// Result: { Ok: 200_000_000 } (2 ICP)

// Check next pool commitment
const next = await poolCanister.getMyNextPoolContribution();
// Result: { Ok: 300_000_000 } (3 ICP committed for next week)
```

### 5. View Your History

```javascript
const history = await poolCanister.getMyHistory();
// Result: { Ok: [
//   {
//     weekStartTimestamp: 1737331200n,
//     weekEndTimestamp: 1737936000n,
//     icpContributionE8S: 200_000_000n,
//     funnaiDistribution: 15_000_000n
//   },
//   {
//     weekStartTimestamp: 1737936000n,
//     weekEndTimestamp: 1738540800n,
//     icpContributionE8S: 300_000_000n,
//     funnaiDistribution: 22_500_000n
//   }
// ]}
```

## For Pool Viewers

### 1. Check Current Pool Stats

```javascript
const stats = await poolCanister.getCurrentPoolStats();
// Result: { Ok: {
//   cycleId: 5,
//   startTimestamp: 1737331200n,
//   endTimestamp: 1737936000n,
//   participantCount: 47,
//   totalIcpContributedE8S: 15_000_000_000n, // 150 ICP
//   totalFunnaiRewardsAccumulated: 500_000_000n
// }}
```

### 2. Check Next Pool Stats

```javascript
const nextStats = await poolCanister.getNextPoolStats();
// Result: { Ok: {
//   cycleId: 6,
//   participantCount: 52,
//   totalIcpCommittedE8S: 18_000_000_000n, // 180 ICP committed
//   commitmentDeadline: 1737936000n // Sunday end of day
// }}
```

### 3. View Pool Configuration

```javascript
const config = await poolCanister.getPoolConfiguration();
// Result: { Ok: {
//   minIcpContributionE8S: 100_000_000n, // 1 ICP
//   maxIcpContributionE8S: 1_000_000_000_000n, // 10,000 ICP
//   funnaiEntryBurnAmount: 10_000_000n, // 0.1 FUNNAI
//   treasuryFeePercentage: 10,
//   currentCycleId: 5,
//   nextCycleId: 6,
//   totalPoolCycles: 5,
//   totalParticipantsAllTime: 324
// }}
```

### 4. View Aggregated History

```javascript
const aggregated = await poolCanister.getAggregatedHistory();
// Result: { Ok: {
//   totalCycles: 5,
//   totalParticipants: 324,
//   totalIcpContributedE8S: 75_000_000_000n, // 750 ICP total
//   totalFunnaiDistributed: 2_500_000_000n // 25 FUNNAI distributed
// }}
```

### 5. View Specific Past Cycle

```javascript
const cycle = await poolCanister.getArchivedPoolCycle(3);
// Result: { Ok: {
//   cycleId: 3,
//   startTimestamp: 1736121600n,
//   endTimestamp: 1736726400n,
//   totalIcpContributedE8S: 12_000_000_000n,
//   totalFunnaiDistributed: 400_000_000n,
//   participantCount: 38
// }}

// Get participants for that cycle
const participants = await poolCanister.getArchivedCycleParticipants(3);
// Result: { Ok: [
//   [Principal.fromText("aaaaa-aa..."), {
//     principal: Principal.fromText("aaaaa-aa..."),
//     icpContributionE8S: 500_000_000n,
//     funnaiDistribution: 16_666_666n,
//     joinTimestamp: 1736121600n,
//     participatedInLastWeek: true
//   }],
//   // ... more participants
// ]}
```

### 6. View Pool mAIners

```javascript
const mainers = await poolCanister.getPoolMainers();
// Result: { Ok: [
//   {
//     address: "ryjl3-tyaaa-aaaaa-aaaba-cai",
//     mainerType: { Own: null },
//     creationTimestamp: 1735000000n,
//     currentCyclesBalance: 5_000_000_000_000n,
//     cyclesBurnRate: 8_267_195n // cycles per second
//   },
//   {
//     address: "rrkah-fqaaa-aaaaa-aaaaq-cai",
//     mainerType: { ShareAgent: null },
//     creationTimestamp: 1735100000n,
//     currentCyclesBalance: 5_000_000_000_000n,
//     cyclesBurnRate: 8_267_195n
//   }
// ]}
```

### 7. Check Pool Balances

```javascript
const balances = await poolCanister.getPoolBalances();
// Result: { Ok: {
//   icpBalanceE8S: 18_000_000_000n, // 180 ICP
//   funnaiBalance: 500_000_000n // 5 FUNNAI accumulated
// }}
```

## For Administrators

### 1. Initialize Pool (First Time)

```bash
# Deploy the canister first
dfx deploy mAIningPool

# Set the Game State canister ID
dfx canister call mAIningPool setGameStateCanisterId '("r5m5y-diaaa-aaaaa-qanaa-cai")'

# Add mAIners to the pool
dfx canister call mAIningPool addPoolMainer '("ryjl3-tyaaa-aaaaa-aaaba-cai", variant { Own })'
dfx canister call mAIningPool addPoolMainer '("rrkah-fqaaa-aaaaa-aaaaq-cai", variant { Own })'
dfx canister call mAIningPool addPoolMainer '("r7inp-6aaaa-aaaaa-aaabq-cai", variant { ShareAgent })'

# Start the first cycle (Monday 00:00:00 UTC to Sunday 23:59:59 UTC)
# Timestamps are in seconds since epoch
dfx canister call mAIningPool startNextPoolCycle '(
  1737331200, # Monday Jan 20, 2026 00:00:00 UTC
  1737935999  # Sunday Jan 26, 2026 23:59:59 UTC
)'
```

### 2. Weekly Cycle Transition (Every Monday)

```bash
# This should be called after Sunday (start of Monday) to:
# 1. Distribute rewards from last week
# 2. Archive completed cycle
# 3. Start new cycle with committed participants
# 4. Top up mAIners and set burn rates

dfx canister call mAIningPool startNextPoolCycle '(
  1737936000, # Monday Jan 27, 2026 00:00:00 UTC
  1738540799  # Sunday Feb 2, 2026 23:59:59 UTC
)'
```

### 3. Add/Remove mAIners

```bash
# Add a new mAIner to the pool
dfx canister call mAIningPool addPoolMainer '(
  "rkp4c-7iaaa-aaaaa-aaaca-cai",
  variant { Own }
)'

# Remove a mAIner from the pool
dfx canister call mAIningPool removePoolMainer '("rkp4c-7iaaa-aaaaa-aaaca-cai")'
```

### 4. Manual Balance Updates (if needed)

```bash
# Update pool balances manually (for accounting corrections)
dfx canister call mAIningPool updatePoolBalances '(
  18_000_000_000, # ICP balance in e8s
  500_000_000     # FUNNAI balance
)'
```

## Automated Weekly Script Example

```bash
#!/bin/bash
# weekly_pool_cycle.sh
# Run this script every Monday at 00:01 UTC

# Calculate timestamps for the new week
WEEK_START=$(date -d "today 00:00:00" +%s)
WEEK_END=$(date -d "next Sunday 23:59:59" +%s)

# Start the next pool cycle
dfx canister call mAIningPool startNextPoolCycle \
  "($WEEK_START, $WEEK_END)" \
  --identity admin

# Log the result
echo "Pool cycle started: $WEEK_START to $WEEK_END"

# Check stats
dfx canister call mAIningPool getCurrentPoolStats
```

## Frontend Integration Example (React)

```typescript
import { Actor, HttpAgent } from "@dfinity/agent";
import { idlFactory } from "./declarations/mAIningPool";

// Initialize actor
const agent = new HttpAgent({ host: "https://ic0.app" });
const poolActor = Actor.createActor(idlFactory, {
  agent,
  canisterId: "YOUR_POOL_CANISTER_ID",
});

// Component for pool participation
function PoolParticipation() {
  const [contribution, setContribution] = useState("");
  const [isNewParticipant, setIsNewParticipant] = useState(false);

  const handleContribute = async () => {
    try {
      // 1. Check if user needs to burn FUNNAI
      const currentContribution = await poolActor.getMyCurrentPoolContribution();
      const needsBurn = currentContribution.Ok === 0n;
      
      // 2. Convert ICP to e8s
      const amountE8S = BigInt(parseFloat(contribution) * 100_000_000);
      
      // 3. Approve ICP
      await icpLedger.approve({
        spender: poolCanisterPrincipal,
        amount: amountE8S,
      });
      
      // 4. If needed, approve and burn FUNNAI
      if (needsBurn) {
        await funnaiLedger.approve({
          spender: poolCanisterPrincipal,
          amount: 10_000_000n,
        });
      }
      
      // 5. Contribute to pool
      const result = await poolActor.contributeToNextPool(amountE8S, needsBurn);
      
      if ("Ok" in result) {
        alert(`Successfully contributed ${contribution} ICP!`);
      } else {
        alert(`Error: ${result.Err}`);
      }
    } catch (error) {
      console.error("Contribution failed:", error);
    }
  };

  return (
    <div>
      <input
        type="number"
        value={contribution}
        onChange={(e) => setContribution(e.target.value)}
        placeholder="Amount in ICP"
        min="1"
        max="10000"
      />
      <button onClick={handleContribute}>Contribute to Next Pool</button>
    </div>
  );
}
```

## Error Handling Examples

```javascript
// Handle contribution errors
const result = await poolCanister.contributeToNextPool(50_000_000n, false);

if ("Err" in result) {
  switch (result.Err) {
    case "Unauthorized":
      console.error("Must be logged in");
      break;
    case "Other":
      console.error("Error:", result.Err.Other);
      // Could be: "Contribution below minimum of 1 ICP"
      // Or: "New participants must burn 10000000 FUNNAI to join"
      break;
    default:
      console.error("Unknown error:", result.Err);
  }
}
```

## Testing Scenarios

### 1. Test First-Time Participation

```bash
# As a new user
dfx identity use user1
dfx canister call mAIningPool contributeToNextPool '(200_000_000, true)'
# Should succeed with FUNNAI burn

dfx canister call mAIningPool contributeToNextPool '(200_000_000, false)'
# Should fail: "New participants must burn FUNNAI"
```

### 2. Test Contribution Limits

```bash
# Try below minimum
dfx canister call mAIningPool contributeToNextPool '(50_000_000, false)'
# Should fail: "Contribution below minimum of 1 ICP"

# Try above maximum
dfx canister call mAIningPool contributeToNextPool '(2_000_000_000_000, false)'
# Should fail: "Contribution exceeds maximum of 10000 ICP"
```

### 3. Test Continuous Participation

```bash
# Week 1: contribute
dfx canister call mAIningPool contributeToNextPool '(200_000_000, true)'

# Admin starts next cycle
dfx identity use admin
dfx canister call mAIningPool startNextPoolCycle '(...)'

# Week 2: contribute again (no FUNNAI burn needed)
dfx identity use user1
dfx canister call mAIningPool contributeToNextPool '(200_000_000, false)'
# Should succeed without burning
```
