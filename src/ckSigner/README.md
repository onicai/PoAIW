# ckSigner

A general-purpose threshold signing service that gives any authenticated caller deterministic, isolated Bitcoin keys derived from `(caller, botName)` pairs via the IC's Chain Fusion capabilities.

Both the production and testing canisters are deployed to the [fiduciary subnet](https://dashboard.internetcomputer.org/subnet/pzp6e-ekpqk-3c5x7-2h6so-njoeq-mt45d-h3h6c-q3mxf-vpeq5-fk5o7-yae) (`pzp6e-ekpqk-3c5x7-2h6so-njoeq-mt45d-h3h6c-q3mxf-vpeq5-fk5o7-yae`) for higher security guarantees (34-node subnet).

| Network | Canister ID                                                                                                    |
|---------|----------------------------------------------------------------------------------------------------------------|
| prd     | [`g7qkb-iiaaa-aaaar-qb3za-cai`](https://dashboard.internetcomputer.org/canister/g7qkb-iiaaa-aaaar-qb3za-cai) |
| testing | [`ho2u6-qaaaa-aaaar-qb34q-cai`](https://dashboard.internetcomputer.org/canister/ho2u6-qaaaa-aaaar-qb34q-cai) |

## Endpoints

- `getPublicKeyQuery(botName)` — Returns the cached x-only public key and P2TR address (query call, free)
- `getPublicKey(botName, payment)` — Returns x-only public key and P2TR address, fetches from management canister on cache miss (update call, may require fee)
- `sign(botName, messageHash, payment)` — Signs a 32-byte hash with threshold Schnorr (update call, may require fee)
- `getFeeTokens()` — Returns accepted fee tokens and usage instructions (query call)
- `getTreasury()` — Returns the treasury configuration (query call)

## Use cases

- [odin-bots](https://github.com/onicai/odin_bots) — Trading bot for Bitcoin Runes on Odin.fun
- [IConfucius](https://x.com/IConfucius_odin) — An Odin.fun Rune, AI canister and autonomous Rune trader
- Sign In With Bitcoin (SIWB) authentication
- Bitcoin transaction signing
- Any BIP340 Schnorr signing use case

## Roadmap

- Ethereum support (ECDSA) for Sign In With Ethereum (SIWE) applications

---

## Development

### Prerequisites

- [icp-cli](https://cli.internetcomputer.org) (1.2.0+)
- [Docker](https://www.docker.com/) (for reproducible wasm builds)
- Python 3.11+ (any environment manager: conda, venv, asdf, etc.)
- [mops](https://mops.one/) (Motoko package manager)

### Setup

```bash
# Install Python test dependencies (from PoAIW repo root)
pip install -r requirements.txt

# Install Motoko dependencies
cd src/ckSigner
mops install
```

### Running smoke tests

```bash
cd src/ckSigner
make smoketest
```

This will:
1. Stop any running local network (`icp network stop`)
2. Start a clean local network (`rm -rf .icp/cache && icp network start -d`;
   icp-cli has no `--clean`, removing the cache is the equivalent)
3. Build the canister wasm (Docker reproducible build)
4. Create and install the canister locally with the `dfx_test_key` Schnorr key
   (that is the management canister's key name on a local replica, not a dfx CLI concept)
5. Run all pytest smoke tests
6. Stop the replica

### Local deployment (manual)

To deploy manually without running the full smoketest:

```bash
cd src/ckSigner

# Start a clean local replica
icp network stop
rm -rf .icp/cache && icp network start -d

# Build wasm (Docker reproducible build)
make docker-build-base
make docker-build-wasm

# Create and install the canister
icp canister create ck_signer_canister -e local
icp canister install ck_signer_canister --wasm out/ck_signer_canister.wasm \
    --mode install \
    --args '("dfx_test_key")'

# Run tests
pytest -vv --exitfirst test/test_ck_signer.py

# Stop the replica when done
icp network stop
```

---

## Upgrade commands

### Schnorr Key Names

| Schnorr Key Name | network                     | Signing Cost    | Subnet used for signing    |
|------------------|-----------------------------|-----------------|----------------------------|
| `key_1`          | IC mainnet (prd)            | ~26B cycles     | 34-node fiduciary subnet   |
| `test_key_1`     | IC mainnet (testing)        | ~10B cycles     | 13-node application subnet |
| `dfx_test_key`   | Local replica (`icp network start`) | Free            | Local test subnet          |

### Set the variables

```bash
# One of these combinations
NETWORK=prd
SCHNORR_KEY_NAME="key_1"

NETWORK=testing
SCHNORR_KEY_NAME="test_key_1"

NETWORK=local
SCHNORR_KEY_NAME="dfx_test_key"

echo "NETWORK=$NETWORK"
echo "SCHNORR_KEY_NAME=$SCHNORR_KEY_NAME"
```

### Upgrade the ck_signer_canister

```bash
# Verify correct network & signing key!
echo "NETWORK=$NETWORK"
echo "SCHNORR_KEY_NAME=$SCHNORR_KEY_NAME"

# from folder: PoAIW/src/ckSigner

# Build wasm with Docker (reproducible build)
make docker-build-base
make docker-build-wasm

icp canister stop ck_signer_canister -e $NETWORK
icp canister snapshot create ck_signer_canister -e $NETWORK

# ---------------------------------------------
# To upgrade
icp canister install ck_signer_canister \
    --mode upgrade \
    -e $NETWORK \
    --wasm out/ck_signer_canister.wasm \
    --args "("$SCHNORR_KEY_NAME")" \
    --wasm-memory-persistence keep

# To reinstall
# When reinstalling, make sure to redo the steps of the section:
# "Configure fee tokens"
#
icp canister install ck_signer_canister \
    --mode reinstall \
    -e $NETWORK \
    --wasm out/ck_signer_canister.wasm \
    --args "("$SCHNORR_KEY_NAME")"

# Verify wasm hash
make docker-verify-wasm VERIFY_NETWORK=$NETWORK

# Start the canister back up
icp canister start ck_signer_canister -e $NETWORK
icp canister status ck_signer_canister -e $NETWORK | grep Status
icp canister call ck_signer_canister health

# Verify Treasury -> go to Configure Treasury section if wrong
icp canister call ck_signer_canister getTreasury

# Verify fee token configuration -> go to Configure Fee Tokens section if wrong
icp canister call ck_signer_canister getFeeTokens

# Verify signing is functional
# getPublicKey — should return an x-only public key and P2TR bitcoin address
icp canister call ck_signer_canister getPublicKey \
    '(record { botName = "testbot"; payment = null })'

# sign — should return a 64-byte Schnorr signature
# (the argument is a 32-byte message hash, hex-encoded as a blob)
icp canister call ck_signer_canister sign \
    '(record { botName = "testbot"; message = blob "\00\01\02\03\04\05\06\07\08\09\0a\0b\0c\0d\0e\0f\10\11\12\13\14\15\16\17\18\19\1a\1b\1c\1d\1e\1f"; payment = null })'

# Verify that different botNames produce different keys
icp canister call ck_signer_canister getPublicKey \
    '(record { botName = "testbot2"; payment = null })'
```

### Configure treasury

The treasury is where all fees are sent. Default: funnAI Treasury Canister (prd).
After a reinstall, verify the treasury is correct. For testing, set it to the testing treasury.

```bash
echo "Using network: $NETWORK"

# Check current treasury
icp canister call ck_signer_canister getTreasury

## Treasury Configuration
#
# | Environment | Treasury Name                | Treasury Principal            |
# |-------------|------------------------------|-------------------------------|
# | prd         | funnAI Treasury Canister     | qbhxa-ziaaa-aaaaa-qbqza-cai  |
# | testing     | funnAI Treasury Canister Dev | pu2lc-nyaaa-aaaag-au65q-cai  |

# Set treasury (only needed if default is wrong, e.g. for testing network)
# icp canister call ck_signer_canister setTreasury \
#     '(record { treasuryName = "funnAI Treasury Canister Dev"; treasuryPrincipal = principal "pu2lc-nyaaa-aaaag-au65q-cai" })'
```

### Configure fee tokens

After a reinstall, configure the accepted ICRC-2 fee tokens.

```bash
echo "Using network: $NETWORK"

# Check current fee token configuration
icp canister call ck_signer_canister getFeeTokens

## Fee Token Configuration
#
# | Token | Ledger Canister ID          | Fee        |
# |-------|-----------------------------|------------|
# | ckBTC | mxzaz-hqaaa-aaaar-qaada-cai | 100 (sats) |

icp canister call ck_signer_canister addFeeToken \
    '(record { tokenName = "ckBTC"; tokenLedger = principal "mxzaz-hqaaa-aaaar-qaada-cai"; fee = 100 : nat })'

# Verify fee tokens are configured
icp canister call ck_signer_canister getFeeTokens

# Verify getPublicKey rejects without payment (should return "Fee payment required" error)
icp canister call ck_signer_canister getPublicKey \
    '(record { botName = "testbot"; payment = null })'

# Verify sign rejects without payment (should return "Fee payment required" error)
icp canister call ck_signer_canister sign \
    '(record { botName = "testbot"; message = blob "\00\01\02\03\04\05\06\07\08\09\0a\0b\0c\0d\0e\0f\10\11\12\13\14\15\16\17\18\19\1a\1b\1c\1d\1e\1f"; payment = null })'

# To remove a fee token (if needed):
# icp canister call ck_signer_canister removeFeeToken \
#     '(record { tokenLedger = principal "mxzaz-hqaaa-aaaar-qaada-cai" })'
```

### Cleanup the snapshots

After a couple of hours, if everything looks good, remove the snapshots to save memory:

```bash
icp canister snapshot list ck_signer_canister -e $NETWORK
icp canister snapshot delete ck_signer_canister -e $NETWORK <snapshot-id>
```

### Load a snapshot to ROLL BACK

```bash
icp canister stop ck_signer_canister -e $NETWORK
icp canister snapshot list ck_signer_canister -e $NETWORK
icp canister snapshot restore ck_signer_canister -e $NETWORK <snapshot-id>
icp canister start ck_signer_canister -e $NETWORK
icp canister call ck_signer_canister health
```

---

## Status & Disclaimer

This project is in **alpha**. APIs may change without notice.

The software and hosted services are provided "as is", without warranty of any kind. Use at your own risk. The authors and onicai are not liable for any losses — including but not limited to loss of funds, keys, or data — incurred through use of this software or the hosted canister services. No guarantee of availability, correctness, or security is made. You are solely responsible for evaluating the suitability of these services for your use case and for complying with all applicable laws and regulations in your jurisdiction.

## License

MIT
