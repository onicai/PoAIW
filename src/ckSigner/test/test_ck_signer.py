"""Test ck_signer_canister endpoints

First deploy the canister:
$ dfx start --clean --background
$ dfx deploy --network local

Then run all the tests:
$ pytest -vv --exitfirst --network local test/test_ck_signer.py

Or run a specific test:
$ pytest -vv --network local test/test_ck_signer.py::test__health

"""
# pylint: disable=missing-function-docstring, unused-import, wildcard-import, unused-wildcard-import, line-too-long

from pathlib import Path
from typing import Dict
import re
import pytest
from icpp.smoketest import call_canister_api

# Path to the dfx.json file
DFX_JSON_PATH = Path(__file__).parent / "../dfx.json"

# Canister in the dfx.json file we want to test
CANISTER_NAME = "ck_signer_canister"

# Reusable 32-byte sighash for sign() tests
SIGHASH_32_BYTES = r'\00\01\02\03\04\05\06\07\08\09\0a\0b\0c\0d\0e\0f\10\11\12\13\14\15\16\17\18\19\1a\1b\1c\1d\1e\1f'

# Fake ledger principals for fee token tests (no real ledger on local)
FAKE_LEDGER = "mxzaz-hqaaa-aaaar-qaada-cai"
FAKE_LEDGER_2 = "ryjl3-tyaaa-aaaaa-aaaba-cai"

# Default treasury (funnAI Treasury Canister prd) — hardcoded in canister
DEFAULT_TREASURY_NAME = "funnAI Treasury Canister"
DEFAULT_TREASURY_PRINCIPAL = "qbhxa-ziaaa-aaaaa-qbqza-cai"

# Test treasury for setTreasury tests
TEST_TREASURY_NAME = "funnAI Treasury Canister Dev"
TEST_TREASURY_PRINCIPAL = "pu2lc-nyaaa-aaaag-au65q-cai"


# =============================================================================
# Public Endpoints (No Authentication Required)
# =============================================================================

def test__health(network: str) -> None:
    """Test health endpoint returns status 200"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="health",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response


# =============================================================================
# amiController Endpoint
# =============================================================================

def test__amiController(network: str) -> None:
    """Test amiController succeeds for controller (default dfx identity)"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="amiController",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response


def test__amiController_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test amiController rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="amiController",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


# =============================================================================
# getTreasury / setTreasury Endpoints
# =============================================================================

def test__getTreasury_default(network: str) -> None:
    """Test getTreasury returns funnAI Treasury Canister (prd) by default"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getTreasury",
        canister_argument="()",
        network=network,
    )
    assert f'treasuryName = "{DEFAULT_TREASURY_NAME}"' in response
    assert f'treasuryPrincipal = principal "{DEFAULT_TREASURY_PRINCIPAL}"' in response


def test__setTreasury(network: str) -> None:
    """Test setTreasury succeeds for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setTreasury",
        canister_argument=f'(record {{ treasuryName = "{TEST_TREASURY_NAME}"; treasuryPrincipal = principal "{TEST_TREASURY_PRINCIPAL}" }})',
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response

    # Verify it was updated
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getTreasury",
        canister_argument="()",
        network=network,
    )
    assert f'treasuryName = "{TEST_TREASURY_NAME}"' in response
    assert f'treasuryPrincipal = principal "{TEST_TREASURY_PRINCIPAL}"' in response


def test__setTreasury_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test setTreasury rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setTreasury",
        canister_argument=f'(record {{ treasuryName = "{TEST_TREASURY_NAME}"; treasuryPrincipal = principal "{TEST_TREASURY_PRINCIPAL}" }})',
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__setTreasury_restore_default(network: str) -> None:
    """Restore treasury to default for remaining tests"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setTreasury",
        canister_argument=f'(record {{ treasuryName = "{DEFAULT_TREASURY_NAME}"; treasuryPrincipal = principal "{DEFAULT_TREASURY_PRINCIPAL}" }})',
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response


# =============================================================================
# getFeeTokens Endpoint
# =============================================================================

def test__getFeeTokens_empty(network: str) -> None:
    """Test getFeeTokens returns empty list with canisterId, treasury, and usage"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getFeeTokens",
        canister_argument="()",
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'canisterId = principal "' in response
    assert f'treasuryName = "{DEFAULT_TREASURY_NAME}"' in response
    assert f'treasuryPrincipal = principal "{DEFAULT_TREASURY_PRINCIPAL}"' in response
    assert 'feeTokens = vec {};' in response
    assert 'usage = "To pay for sign():' in response


# =============================================================================
# addFeeToken Endpoint
# =============================================================================

def test__addFeeToken(network: str) -> None:
    """Test addFeeToken succeeds for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addFeeToken",
        canister_argument=f'(record {{ tokenName = "ckBTC"; tokenLedger = principal "{FAKE_LEDGER}"; fee = 100 : nat }})',
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response


def test__addFeeToken_verify(network: str) -> None:
    """Test getFeeTokens returns the added token with canisterId, treasury, and usage"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getFeeTokens",
        canister_argument="()",
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'canisterId = principal "' in response
    assert f'treasuryName = "{DEFAULT_TREASURY_NAME}"' in response
    assert '"ckBTC"' in response
    assert FAKE_LEDGER in response
    assert 'usage = "To pay for sign():' in response


def test__addFeeToken_idempotent(network: str) -> None:
    """Test addFeeToken with same ledger updates the existing entry"""
    # Update fee from 100 to 200
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addFeeToken",
        canister_argument=f'(record {{ tokenName = "ckBTC"; tokenLedger = principal "{FAKE_LEDGER}"; fee = 200 : nat }})',
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response

    # Verify the fee was updated (only one entry, not two)
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getFeeTokens",
        canister_argument="()",
        network=network,
    )
    assert 'fee = 200' in response
    assert 'fee = 100' not in response


def test__addFeeToken_multiple(network: str) -> None:
    """Test adding a second fee token"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addFeeToken",
        canister_argument=f'(record {{ tokenName = "ckETH"; tokenLedger = principal "{FAKE_LEDGER_2}"; fee = 50 : nat }})',
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response

    # Verify both tokens are present
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getFeeTokens",
        canister_argument="()",
        network=network,
    )
    assert '"ckBTC"' in response
    assert '"ckETH"' in response


def test__addFeeToken_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test addFeeToken rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addFeeToken",
        canister_argument=f'(record {{ tokenName = "ckBTC"; tokenLedger = principal "{FAKE_LEDGER}"; fee = 100 : nat }})',
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


# =============================================================================
# removeFeeToken Endpoint
# =============================================================================

def test__removeFeeToken(network: str) -> None:
    """Test removeFeeToken succeeds for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="removeFeeToken",
        canister_argument=f'(record {{ tokenLedger = principal "{FAKE_LEDGER_2}" }})',
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response

    # Verify only ckBTC remains
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getFeeTokens",
        canister_argument="()",
        network=network,
    )
    assert '"ckBTC"' in response
    assert '"ckETH"' not in response


def test__removeFeeToken_idempotent(network: str) -> None:
    """Test removeFeeToken for non-existent ledger succeeds (idempotent)"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="removeFeeToken",
        canister_argument=f'(record {{ tokenLedger = principal "{FAKE_LEDGER_2}" }})',
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response


def test__removeFeeToken_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test removeFeeToken rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="removeFeeToken",
        canister_argument=f'(record {{ tokenLedger = principal "{FAKE_LEDGER}" }})',
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


# =============================================================================
# sign with fees configured - Payment Sanity Check Tests
# Note: At this point, ckBTC fee token (fee=200) is still configured from above
# =============================================================================

def test__sign_fee_required_no_payment(network: str) -> None:
    """Test sign rejects when fees configured but no payment provided, includes self-discovery"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = "testbot"; message = blob "{SIGHASH_32_BYTES}"; payment = null }})',
        network=network,
    )
    assert 'variant { Err = variant { Other = "Fee payment required.' in response
    assert 'canisterId=' in response
    assert DEFAULT_TREASURY_NAME in response
    assert 'Accepted tokens:' in response
    assert 'ckBTC' in response
    assert 'icrc2_approve' in response


def test__sign_fee_wrong_ledger(network: str) -> None:
    """Test sign rejects payment with unsupported ledger, includes self-discovery"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = "testbot"; message = blob "{SIGHASH_32_BYTES}"; payment = opt record {{ tokenName = "ckBTC"; tokenLedger = principal "{FAKE_LEDGER_2}"; amount = 200 : nat }} }})',
        network=network,
    )
    assert 'Unsupported fee token ledger:' in response
    assert 'canisterId=' in response
    assert 'Accepted tokens:' in response


def test__sign_fee_wrong_token_name(network: str) -> None:
    """Test sign rejects payment with wrong token name, includes self-discovery"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = "testbot"; message = blob "{SIGHASH_32_BYTES}"; payment = opt record {{ tokenName = "WRONG"; tokenLedger = principal "{FAKE_LEDGER}"; amount = 200 : nat }} }})',
        network=network,
    )
    assert 'Token name mismatch: expected ckBTC, got WRONG' in response
    assert 'canisterId=' in response
    assert 'Accepted tokens:' in response


def test__sign_fee_insufficient_amount(network: str) -> None:
    """Test sign rejects payment with insufficient amount, includes self-discovery"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = "testbot"; message = blob "{SIGHASH_32_BYTES}"; payment = opt record {{ tokenName = "ckBTC"; tokenLedger = principal "{FAKE_LEDGER}"; amount = 50 : nat }} }})',
        network=network,
    )
    assert 'Insufficient payment amount: expected >= 200, got 50' in response
    assert 'canisterId=' in response
    assert 'Accepted tokens:' in response


def test__sign_fee_sanity_check_passes_transfer_fails(network: str) -> None:
    """Test sign with correct payment details: sanity check passes but transfer_from
    fails because there is no real ICRC-2 ledger on local replica. Includes self-discovery."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = "testbot"; message = blob "{SIGHASH_32_BYTES}"; payment = opt record {{ tokenName = "ckBTC"; tokenLedger = principal "{FAKE_LEDGER}"; amount = 200 : nat }} }})',
        network=network,
    )
    # Sanity check passed but transfer_from fails (no real ledger on local)
    assert 'Fee payment failed:' in response
    assert 'canisterId=' in response


# =============================================================================
# Clean up fee tokens - Remove all so subsequent tests run without fees
# =============================================================================

def test__removeFeeToken_cleanup(network: str) -> None:
    """Remove all fee tokens to restore free signing for remaining tests"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="removeFeeToken",
        canister_argument=f'(record {{ tokenLedger = principal "{FAKE_LEDGER}" }})',
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response

    # Verify empty
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getFeeTokens",
        canister_argument="()",
        network=network,
    )
    assert 'feeTokens = vec {};' in response
    assert 'canisterId = principal "' in response


# =============================================================================
# getPublicKey Endpoint - Auth & Validation Tests
# =============================================================================

def test__getPublicKey_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test getPublicKey rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPublicKey",
        canister_argument='(record { botName = "testbot" })',
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__getPublicKey_empty_botName(network: str) -> None:
    """Test getPublicKey rejects empty botName"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPublicKey",
        canister_argument='(record { botName = "" })',
        network=network,
    )
    expected_response = '(variant { Err = variant { Other = "botName cannot be empty" } })'
    assert response == expected_response


# =============================================================================
# sign Endpoint - Auth & Validation Tests (no fees configured)
# =============================================================================

def test__sign_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test sign rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = "testbot"; message = blob "{SIGHASH_32_BYTES}"; payment = null }})',
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__sign_empty_botName(network: str) -> None:
    """Test sign rejects empty botName"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = ""; message = blob "{SIGHASH_32_BYTES}"; payment = null }})',
        network=network,
    )
    expected_response = '(variant { Err = variant { Other = "botName cannot be empty" } })'
    assert response == expected_response


def test__sign_wrong_message_size(network: str) -> None:
    """Test sign rejects message that is not 32 bytes"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=r'(record { botName = "testbot"; message = blob "\00\01\02\03"; payment = null })',
        network=network,
    )
    expected_response = '(variant { Err = variant { Other = "message must be exactly 32 bytes (sighash)" } })'
    assert response == expected_response


def test__sign_no_fee_with_payment(network: str) -> None:
    """Test sign with payment provided but no fees configured — rejects unsupported ledger"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = "testbot"; message = blob "{SIGHASH_32_BYTES}"; payment = opt record {{ tokenName = "ckBTC"; tokenLedger = principal "{FAKE_LEDGER}"; amount = 100 : nat }} }})',
        network=network,
    )
    assert 'variant { Err = variant { Other = "Unsupported fee token ledger:' in response


# =============================================================================
# getPublicKeyQuery Endpoint
# =============================================================================

def test__getPublicKeyQuery_cache_miss(network: str) -> None:
    """Test getPublicKeyQuery returns cache miss error for uncached bot"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPublicKeyQuery",
        canister_argument='(record { botName = "query_test_bot" })',
        network=network,
    )
    assert 'variant { Err = variant { Other = "Not Found' in response


def test__getPublicKeyQuery_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test getPublicKeyQuery rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPublicKeyQuery",
        canister_argument='(record { botName = "testbot" })',
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__getPublicKeyQuery_empty_botName(network: str) -> None:
    """Test getPublicKeyQuery rejects empty botName"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPublicKeyQuery",
        canister_argument='(record { botName = "" })',
        network=network,
    )
    expected_response = '(variant { Err = variant { Other = "botName cannot be empty" } })'
    assert response == expected_response


# =============================================================================
# getPublicKey & sign - Success Tests (requires Schnorr signing on replica)
# =============================================================================

def test__getPublicKey(network: str) -> None:
    """Test getPublicKey returns public key and P2TR address"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPublicKey",
        canister_argument='(record { botName = "testbot" })',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'botName = "testbot"' in response
    assert 'publicKeyHex' in response
    assert 'address = "bc1p' in response


def test__getPublicKey_p2tr_address_matches_local(network: str) -> None:
    """Test canister P2TR address matches locally-derived address (BIP341 tweak)"""
    try:
        from bitcoinutils.setup import setup
        from bitcoinutils.keys import PublicKey
    except ImportError:
        pytest.skip("bitcoin-utils not installed")

    # bitcoin-utils defaults to testnet; canister always uses mainnet ("bc" hrp)
    setup('mainnet')

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPublicKey",
        canister_argument='(record { botName = "testbot" })',
        network=network,
    )
    # Parse publicKeyHex and address from candid response
    pubkey_match = re.search(r'publicKeyHex = "([0-9a-f]{64})"', response)
    address_match = re.search(r'address = "(bc1p[a-z0-9]+)"', response)
    assert pubkey_match, f"publicKeyHex not found in response: {response}"
    assert address_match, f"address not found in response: {response}"

    pubkey_hex = pubkey_match.group(1)
    canister_address = address_match.group(1)

    # Derive P2TR address locally using bitcoin-utils (applies BIP341 tweak)
    pk = PublicKey("02" + pubkey_hex)
    local_address = pk.get_taproot_address().to_string()

    assert canister_address == local_address, (
        f"P2TR address mismatch!\n"
        f"  Canister: {canister_address}\n"
        f"  Local:    {local_address}\n"
        f"  PubKey:   {pubkey_hex}"
    )


def test__getPublicKey_cache_hit(network: str) -> None:
    """Test getPublicKey returns same result on second call (cache hit)"""
    response1 = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPublicKey",
        canister_argument='(record { botName = "testbot" })',
        network=network,
    )
    response2 = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPublicKey",
        canister_argument='(record { botName = "testbot" })',
        network=network,
    )
    assert response1 == response2
    assert response1.startswith('(variant { Ok = record {')


def test__getPublicKeyQuery_cache_hit(network: str) -> None:
    """Test getPublicKeyQuery returns cached result after getPublicKey populated it"""
    # getPublicKey for "testbot" was called in earlier tests, so cache is populated
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPublicKeyQuery",
        canister_argument='(record { botName = "testbot" })',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'botName = "testbot"' in response
    assert 'publicKeyHex' in response
    assert 'address = "bc1p' in response


def test__getPublicKey_different_botNames(network: str) -> None:
    """Test getPublicKey returns different keys for different bot names"""
    response1 = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPublicKey",
        canister_argument='(record { botName = "bot_alpha" })',
        network=network,
    )
    response2 = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPublicKey",
        canister_argument='(record { botName = "bot_beta" })',
        network=network,
    )
    assert response1.startswith('(variant { Ok = record {')
    assert response2.startswith('(variant { Ok = record {')
    assert response1 != response2


def test__sign(network: str) -> None:
    """Test sign returns a valid signature (no fees configured)"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = "testbot"; message = blob "{SIGHASH_32_BYTES}"; payment = null }})',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'botName = "testbot"' in response
    assert 'signatureHex' in response


def test__sign_signature_format(network: str) -> None:
    """Test sign returns a 64-byte (128 hex char) Schnorr signature"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = "testbot"; message = blob "{SIGHASH_32_BYTES}"; payment = null }})',
        network=network,
    )
    sig_match = re.search(r'signatureHex = "([0-9a-f]+)"', response)
    assert sig_match, f"signatureHex not found in response: {response}"
    sig_hex = sig_match.group(1)
    assert len(sig_hex) == 128, f"Expected 128 hex chars (64 bytes), got {len(sig_hex)}"


def test__sign_different_messages(network: str) -> None:
    """Test sign produces different signatures for different messages"""
    msg1 = r'\00\01\02\03\04\05\06\07\08\09\0a\0b\0c\0d\0e\0f\10\11\12\13\14\15\16\17\18\19\1a\1b\1c\1d\1e\1f'
    msg2 = r'\ff\fe\fd\fc\fb\fa\f9\f8\f7\f6\f5\f4\f3\f2\f1\f0\ef\ee\ed\ec\eb\ea\e9\e8\e7\e6\e5\e4\e3\e2\e1\e0'

    response1 = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = "testbot"; message = blob "{msg1}"; payment = null }})',
        network=network,
    )
    response2 = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = "testbot"; message = blob "{msg2}"; payment = null }})',
        network=network,
    )
    assert response1.startswith('(variant { Ok = record {')
    assert response2.startswith('(variant { Ok = record {')

    sig1 = re.search(r'signatureHex = "([0-9a-f]+)"', response1).group(1)
    sig2 = re.search(r'signatureHex = "([0-9a-f]+)"', response2).group(1)
    assert sig1 != sig2, "Different messages should produce different signatures"


def test__sign_different_botNames(network: str) -> None:
    """Test sign produces different signatures for different bot names"""
    response1 = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = "bot_alpha"; message = blob "{SIGHASH_32_BYTES}"; payment = null }})',
        network=network,
    )
    response2 = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = "bot_beta"; message = blob "{SIGHASH_32_BYTES}"; payment = null }})',
        network=network,
    )
    assert response1.startswith('(variant { Ok = record {')
    assert response2.startswith('(variant { Ok = record {')

    sig1 = re.search(r'signatureHex = "([0-9a-f]+)"', response1).group(1)
    sig2 = re.search(r'signatureHex = "([0-9a-f]+)"', response2).group(1)
    assert sig1 != sig2, "Different bot names should produce different signatures"


def test__sign_verify_signature(network: str) -> None:
    """Test signature verification: get public key, sign, verify with BIP340

    The canister signs with the BIP341 Taproot-tweaked key, so we must:
    1. Get the internal (untweaked) x-only key from getPublicKey
    2. Compute the BIP341 tweaked key: internal_key + tagged_hash("TapTweak", internal_key) * G
    3. Verify the Schnorr signature against the tweaked key
    """
    try:
        import hashlib
        from coincurve import PublicKey as CPublicKey, PrivateKey
        from bitcoinutils.schnorr import schnorr_verify
    except ImportError:
        pytest.skip("coincurve or bitcoin-utils not installed")

    # Step 1: Get the internal x-only public key
    pk_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPublicKey",
        canister_argument='(record { botName = "testbot" })',
        network=network,
    )
    pubkey_match = re.search(r'publicKeyHex = "([0-9a-f]{64})"', pk_response)
    assert pubkey_match, f"publicKeyHex not found in response: {pk_response}"
    internal_key_bytes = bytes.fromhex(pubkey_match.group(1))

    # Step 2: Sign a message
    sign_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sign",
        canister_argument=f'(record {{ botName = "testbot"; message = blob "{SIGHASH_32_BYTES}"; payment = null }})',
        network=network,
    )
    sig_match = re.search(r'signatureHex = "([0-9a-f]{128})"', sign_response)
    assert sig_match, f"signatureHex not found in response: {sign_response}"
    sig_bytes = bytes.fromhex(sig_match.group(1))

    # The message used for signing (same 32 bytes as SIGHASH_32_BYTES)
    msg_bytes = bytes(range(32))

    # Step 3: Compute BIP341 Taproot-tweaked key
    # tagged_hash("TapTweak", internal_key) — key-path-only (no merkle root)
    tag_hash = hashlib.sha256(b"TapTweak").digest()
    tweak = hashlib.sha256(tag_hash + tag_hash + internal_key_bytes).digest()

    # tweaked_key = internal_key + tweak * G (EC point addition)
    tweak_point = PrivateKey(tweak).public_key
    internal_point = CPublicKey(b'\x02' + internal_key_bytes)
    tweaked_point = CPublicKey.combine_keys([internal_point, tweak_point])
    tweaked_x_only = tweaked_point.format(compressed=True)[1:]  # Strip 02/03 prefix

    # Step 4: Verify BIP340 Schnorr signature
    is_valid = schnorr_verify(msg_bytes, tweaked_x_only, sig_bytes)
    assert is_valid, (
        f"Schnorr signature verification failed!\n"
        f"  Internal key: {internal_key_bytes.hex()}\n"
        f"  Tweaked key:  {tweaked_x_only.hex()}\n"
        f"  Message:      {msg_bytes.hex()}\n"
        f"  Signature:    {sig_bytes.hex()}"
    )
