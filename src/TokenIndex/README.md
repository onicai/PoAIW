# FUNNAI Token Index Canister

> **No `icp.yaml` here, on purpose.** Like TokenLedger, this is a download-only canister:
> the wasm is the official ICRC-1 index, not built from source in this repo. Its deployed
> ids live in `token_ids.json` and are addressed by principal, not via an icp-cli environment.

## Deployment

```bash
# Deploy to production network (same subnet as ledger)
icp deploy -e prd funnAI_index_canister --subnet snjp4-xlbw4-mnbog-ddwy6-6ckfd-2w5a2-eipqo-7l436-pxqkh-l6fuv-vae

# Add all appropriate controllers
icp canister settings update mziuv-biaaa-aaaaa-qccrq-cai -e prd --add-controller ...

# Add canister to CycleOps & canister_ids-prd.env
```

## Verify Sync Status

```bash
# Check sync progress after deployment
icp canister call funnAI_index_canister status '()'
# Returns: (record { num_blocks_synced = <number> : nat64 })

# Verify correct ledger ID
icp canister call funnAI_index_canister ledger_id '()'
# Should return: vpyot-zqaaa-aaaaa-qavaq-cai
```

## Querying

```bash
# Get account transactions
icp canister call funnAI_index_canister get_account_transactions '(record {account = record {owner = principal "<account-principal>"}; max_results = 10})'

# Get blocks
icp canister call funnAI_index_canister get_blocks '(record {start = 0; length = 10})'
```

---

## Appendix A: Detailed Documentation

### Overview

The index canister is a pre-built canister from DFINITY that indexes transactions from the FUNNAI ledger canister, enabling efficient querying of transaction history and account balances.

**Important**: The index canister must be deployed to the same subnet as the token ledger canister for optimal performance.

### Structure

- `token_ids.json` - deployed canister ids (there is no `icp.yaml`: the wasm is downloaded, not built)
- `canister_ids.json` - Canister IDs for different networks
- `download_latest_icrc1_index.sh` - Script to download the latest index canister wasm and candid files

### Download Script

The `download_latest_icrc1_index.sh` script fetches the latest ICRC-1 index canister files from DFINITY's official releases.

#### Running the Download Script

```bash
# Make the script executable (only needed once)
chmod +x download_latest_icrc1_index.sh

# Run the script
./download_latest_icrc1_index.sh
```

#### What the Script Does

1. Downloads the official ICRC-1 index canister files from DFINITY's GitHub releases
2. Fetches two essential files:
   - `ic-icrc1-index-ng.wasm.gz` - The compressed WebAssembly module for the index canister
   - `index-ng.did` - The Candid interface definition file
3. Automatically decompresses the wasm file for local use

#### Files Created by the Script

After running the script, you'll have:
- `ic-icrc1-index-ng.wasm.gz` - Compressed wasm file (as downloaded)
- `ic-icrc1-index-ng.wasm` - Decompressed wasm file (ready for deployment)
- `index-ng.did` - Candid interface file

### Prerequisites

1. Ensure the FUNNAI ledger canister is deployed (see `/src/TokenLedger`)
2. The production ledger canister ID is: `vpyot-zqaaa-aaaaa-qavaq-cai`
3. Production subnet ID: `snjp4-xlbw4-mnbog-ddwy6-6ckfd-2w5a2-eipqo-7l436-pxqkh-l6fuv-vae`

### Configuration

The index canister is configured with the following parameters at install time:

- **ledger_id**: `vpyot-zqaaa-aaaaa-qavaq-cai` (FUNNAI production ledger)
- **retrieve_blocks_from_ledger_interval_seconds**: Set to 10 seconds (how often the index fetches new blocks from the ledger)

### Updating

To update the index canister to a newer version:

1. Run the download script to get the latest version:
   ```bash
   ./download_latest_icrc1_index.sh
   ```

2. Update `RELEASE_TAG` in `download_latest_icrc1_index.sh` if the release tag has changed
   (this is where the download URLs live now; the old `dfx.json` is gone)

3. Upgrade the canister. There is no `icp.yaml` for this project, so target the canister by
   principal from `token_ids.json` and select the network directly:
   ```bash
   icp canister install mziuv-biaaa-aaaaa-qccrq-cai \
       --wasm ic-icrc1-index-ng.wasm.gz --mode upgrade -n ic -y
   ```

### Networks

The canister ids per environment are recorded in `token_ids.json`:
- **prd**: Production environment (primary deployment target)
- **development**: Development environment
- **testing**: Testing environment
- **backup**: Backup environment
- **demo**: Demo environment

All networks use `https://icp0.io` as the provider and are configured as persistent.

### Resources

- [ICRC-1 Index Canister Documentation](https://internetcomputer.org/docs/defi/token-indexes/)
- [ICRC-1 Ledger Setup](https://internetcomputer.org/docs/defi/token-ledgers/setup/icrc1_ledger_setup)
- [Latest Releases](https://github.com/dfinity/ic/releases)