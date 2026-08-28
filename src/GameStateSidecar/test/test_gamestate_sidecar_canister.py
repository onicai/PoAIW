"""Test gamestate_sidecar_canister endpoints

First deploy the canister:
$ dfx start --clean --background
$ dfx deploy --network local gamestate_sidecar_canister

Then run all the tests:
$ pytest -vv --exitfirst --network local test/test_gamestate_sidecar_canister.py

Or run a specific test:
$ pytest -vv --network local test/test_gamestate_sidecar_canister.py::test__health

Or just run `make smoketest`, which does all of the above from a clean replica.

SCOPE OF WHAT IS TESTED HERE
----------------------------
Only the endpoint gates, the admin setters, and the account-identifier derivation.

The sweep itself is NOT exercised: it needs the ICP index canister and a GameState
canister, neither of which exists on a local dfx network. Calling runSweepNowAdmin
here would reach the index call, fail, log, and return - which proves nothing about
the sweep logic. That is deliberately left to a deployed environment rather than
faked with an assertion that always passes.

IDENTITY NOTE
-------------
Controller tests take ONLY `network` and run as the ambient dfx identity - the one
that deployed the canister and is therefore its controller. Do NOT request the
`identity_default` fixture on a controller test: it switches dfx to the `default`
identity, which is not a controller, and every admin call then returns Unauthorized.
"""

# pylint: disable=unused-argument, missing-function-docstring, unused-import, wildcard-import, unused-wildcard-import, line-too-long, invalid-name

import subprocess
from pathlib import Path
from typing import Dict
import pytest
from icpp.smoketest import call_canister_api

# Test type configuration
# - "single_canister": Only tests that don't require other canisters (e.g., GameState)
# - "full_deployment": All tests including integration tests (requires full deployment)
TEST_TYPE = "single_canister"

# Path to the dfx.json file
DFX_JSON_PATH = Path(__file__).parent / "../dfx.json"

# Canister in the dfx.json file we want to test
CANISTER_NAME = "gamestate_sidecar_canister"

# A real, checksum-valid canister id used wherever a principal must parse.
# setGameStateCanisterId calls Principal.fromText, which traps on a malformed id.
GAMESTATE_TESTING_ID = "vpa37-giaaa-aaaam-qdxeq-cai"


def _call(network: str, method: str, argument: str = "()") -> str:
    return call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method=method,
        canister_argument=argument,
        network=network,
    )


# -----------------------------------------------------------------------------
# Basic endpoints
# -----------------------------------------------------------------------------


def test__health(network: str) -> None:
    assert _call(network, "health") == "(variant { Ok = record { status_code = 200 : nat16;} })"


def test__whoami_anonymous(network: str, identity_anonymous: dict) -> None:
    assert _call(network, "whoami") == '(principal "2vxsx-fae")'


def test__amiController_anonymous(network: str, identity_anonymous: dict) -> None:
    assert _call(network, "amiController") == "(variant { Err = variant { Unauthorized } })"


def test__amiController_as_controller(network: str) -> None:
    assert _call(network, "amiController") == "(variant { Ok = record { status_code = 200 : nat16;} })"


def test__ready_anonymous(network: str, identity_anonymous: dict) -> None:
    assert _call(network, "ready") == "(variant { Err = variant { Unauthorized } })"


def test__ready_as_controller_reports_unarmed_timer(network: str) -> None:
    """A freshly installed sidecar has no timer, and readiness must say so.

    This is the failure mode that otherwise hides: a sidecar with a dead timer looks
    exactly like one with nothing to sweep.
    """
    response = _call(network, "ready")
    assert "The sweep timer is not armed" in response


# -----------------------------------------------------------------------------
# GameState canister id
# -----------------------------------------------------------------------------


def test__setGameStateCanisterId_anonymous(network: str, identity_anonymous: dict) -> None:
    response = _call(network, "setGameStateCanisterId", f'("{GAMESTATE_TESTING_ID}")')
    assert response == "(variant { Err = variant { Unauthorized } })"


def test__getGameStateCanisterId_anonymous(network: str, identity_anonymous: dict) -> None:
    assert _call(network, "getGameStateCanisterId") == "(variant { Err = variant { Unauthorized } })"


def test__setGameStateCanisterId_as_controller(network: str) -> None:
    response = _call(network, "setGameStateCanisterId", f'("{GAMESTATE_TESTING_ID}")')
    assert response == "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert _call(network, "getGameStateCanisterId") == f'(variant {{ Ok = "{GAMESTATE_TESTING_ID}" }})'


def test__getGameStateAccountIdentifierAdmin_matches_dfx(network: str) -> None:
    """The derived account identifier must equal what the ledger tooling produces.

    This is the one piece of sweep logic testable without any ledger, and it is worth
    pinning: the index canister takes the account as hex TEXT while the ledger uses a
    32-byte Blob, and it answers a wrong identifier with an EMPTY transaction list
    rather than an error. A mistake here would look exactly like having nothing to
    sweep.

    Depends on test__setGameStateCanisterId_as_controller having run first, which
    pytest guarantees by file order.
    """
    expected = subprocess.run(
        ["dfx", "ledger", "account-id", "--of-principal", GAMESTATE_TESTING_ID],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    assert len(expected) == 64, f"unexpected account-id from dfx: {expected!r}"
    assert _call(network, "getGameStateAccountIdentifierAdmin") == f'(variant {{ Ok = "{expected}" }})'


def test__getGameStateAccountIdentifierAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    response = _call(network, "getGameStateAccountIdentifierAdmin")
    assert response == "(variant { Err = variant { Unauthorized } })"


# -----------------------------------------------------------------------------
# Timer
# -----------------------------------------------------------------------------


def test__startTimerExecutionAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    assert _call(network, "startTimerExecutionAdmin") == "(variant { Err = variant { Unauthorized } })"


def test__stopTimerExecutionAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    assert _call(network, "stopTimerExecutionAdmin") == "(variant { Err = variant { Unauthorized } })"


def test__setSweepIntervalSecondsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    response = _call(network, "setSweepIntervalSecondsAdmin", "(86400 : nat)")
    assert response == "(variant { Err = variant { Unauthorized } })"


def test__setSweepIntervalSecondsAdmin_rejects_hot_loop(network: str) -> None:
    """A too-short interval must be refused, not accepted.

    Without the floor, a mistyped value turns the daily sweep into a hot loop against
    the ICP index canister.
    """
    response = _call(network, "setSweepIntervalSecondsAdmin", "(5 : nat)")
    assert "at least 300 seconds" in response


def test__setSweepIntervalSecondsAdmin_as_controller(network: str) -> None:
    response = _call(network, "setSweepIntervalSecondsAdmin", "(3600 : nat)")
    assert response == "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert _call(network, "getSweepIntervalSecondsAdmin") == "(variant { Ok = 3_600 : nat })"


def test__getSweepIntervalSecondsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    assert _call(network, "getSweepIntervalSecondsAdmin") == "(variant { Err = variant { Unauthorized } })"


# -----------------------------------------------------------------------------
# Cursor and status
# -----------------------------------------------------------------------------


def test__setScannedThroughBlockIdAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    response = _call(network, "setScannedThroughBlockIdAdmin", "(38034000 : nat64)")
    assert response == "(variant { Err = variant { Unauthorized } })"


def test__setScannedThroughBlockIdAdmin_round_trip(network: str) -> None:
    """The cursor must be settable, because it must never default to 0.

    A first run from 0 would walk GameState's entire ICP account history; the cursor
    is seeded at deploy time and any backfill is staged in chunks.
    """
    response = _call(network, "setScannedThroughBlockIdAdmin", "(38034000 : nat64)")
    assert response == "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert _call(network, "getScannedThroughBlockIdAdmin") == "(variant { Ok = 38_034_000 : nat })"


def test__getScannedThroughBlockIdAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    assert _call(network, "getScannedThroughBlockIdAdmin") == "(variant { Err = variant { Unauthorized } })"


def test__getSidecarStatusAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    assert _call(network, "getSidecarStatusAdmin") == "(variant { Err = variant { Unauthorized } })"


def test__getSidecarStatusAdmin_as_controller(network: str) -> None:
    """Status reports a never-run, unarmed sidecar honestly."""
    response = _call(network, "getSidecarStatusAdmin")
    assert "timerIsArmed = false" in response
    assert "lastRunAt = 0" in response
    assert "pendingRetriesCount = 0" in response
    # Set by the cursor round-trip test above.
    assert "scannedThroughBlockId = 38_034_000" in response


def test__runSweepNowAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    assert _call(network, "runSweepNowAdmin") == "(variant { Err = variant { Unauthorized } })"


# -----------------------------------------------------------------------------
# Cycles
# -----------------------------------------------------------------------------


def test__getMinCyclesBalanceAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    assert _call(network, "getMinCyclesBalanceAdmin") == "(variant { Err = variant { Unauthorized } })"


def test__setMinCyclesBalanceAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    response = _call(network, "setMinCyclesBalanceAdmin", "(5 : nat)")
    assert response == "(variant { Err = variant { Unauthorized } })"


def test__setMinCyclesBalanceAdmin_clamped(network: str) -> None:
    response = _call(network, "setMinCyclesBalanceAdmin", "(500 : nat)")
    assert "above 100T" in response


def test__setMinCyclesBalanceAdmin_as_controller(network: str) -> None:
    response = _call(network, "setMinCyclesBalanceAdmin", "(7 : nat)")
    assert response == "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert _call(network, "getMinCyclesBalanceAdmin") == "(variant { Ok = 7_000_000_000_000 : nat })"


def test__getCyclesBalanceAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    assert _call(network, "getCyclesBalanceAdmin") == "(variant { Err = variant { Unauthorized } })"


# -----------------------------------------------------------------------------
# Admin roles (RBAC)
# -----------------------------------------------------------------------------


def test__assignAdminRole_anonymous(network: str, identity_anonymous: dict) -> None:
    response = _call(
        network,
        "assignAdminRole",
        '(record { "principal" = "aaaaa-aa"; role = variant { AdminQuery }; note = "test" })',
    )
    assert response == "(variant { Err = variant { Unauthorized } })"


def test__revokeAdminRole_anonymous(network: str, identity_anonymous: dict) -> None:
    assert _call(network, "revokeAdminRole", '("aaaaa-aa")') == "(variant { Err = variant { Unauthorized } })"


def test__getAdminRoles_anonymous(network: str, identity_anonymous: dict) -> None:
    assert _call(network, "getAdminRoles") == "(variant { Err = variant { Unauthorized } })"


def test__rbac_setup_cleanup(network: str) -> None:
    """Assign, list, revoke, and confirm the revoke is idempotent-safe."""
    assigned = _call(
        network,
        "assignAdminRole",
        '(record { "principal" = "aaaaa-aa"; role = variant { AdminQuery }; note = "smoketest" })',
    )
    assert "Ok" in assigned and "aaaaa-aa" in assigned

    listed = _call(network, "getAdminRoles")
    assert "aaaaa-aa" in listed

    revoked = _call(network, "revokeAdminRole", '("aaaaa-aa")')
    assert "Ok" in revoked

    again = _call(network, "revokeAdminRole", '("aaaaa-aa")')
    assert "No admin role found" in again
