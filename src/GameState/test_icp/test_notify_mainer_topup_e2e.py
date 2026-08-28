"""End-to-end tests for notifyMainerTopUp, against a LOCAL icp-cli network.

Run with:  make smoketest-icp        (from PoAIW/src/GameState)

WHY A SEPARATE FILE FROM test_game_state_canister.py
    Those tests run on the dfx local network, which has no ICP ledger. They can
    therefore only reach notifyMainerTopUp's pre-await gates, plus the prefix
    resolver via resolveMainerByPrefixAdmin.

    An icp-cli managed network starts with the NNS system canisters installed, and
    the ICP ledger and CMC use the SAME canister ids as mainnet - the ids hardcoded
    in ../../common/Types.mo. So the real payment paths run here unmodified:
    fetchLiveTransaction, the icrc1_memo decode, the MIN_TOPUP_E8S floor,
    verifyIncomingPayment, and the in-flight claim guard across real awaits.

    Keeping these in their own file means a plain `make smoketest` (no ledger)
    never picks them up.

SAFETY
    These tests move ICP. conftest_icp.require_local_gateway refuses to proceed
    unless the gateway is loopback, and every transfer passes an explicit --url,
    so nothing here can reach mainnet.
"""

import subprocess
import sys
from pathlib import Path

import pytest

from conftest_icp import (
    E2E_IDENTITY,
    GAMESTATE_DIR,
    call_gamestate,
    ensure_identity,
    gamestate_canister_id,
    icp,
    identity_pem,
    require_local_gateway,
)

PAY_TOPUP = GAMESTATE_DIR / "scripts" / "pay_topup.py"

MIN_TOPUP_E8S = 9_000_000        # MIN_TOPUP_E8S in Main.mo - 0.09 ICP
BELOW_MIN_E8S = MIN_TOPUP_E8S - 1
COMFORTABLE_E8S = 20_000_000     # 0.2 ICP

# Seeded mAIner addresses.
#
# SEED_UNIQUE must be a REAL, checksum-valid canister principal. Anything reaching
# the cycles-delivery step goes through `actor (mainerEntry.address)` in
# processTopUpCyclesForMainer, and an invalid principal traps the canister with
# 'RTS error: blob_of_principal: invalid principal' rather than returning an error.
#
# The ambiguous pair may stay syntactically fake: ambiguity is detected during
# prefix resolution, before any principal is parsed.
SEED_AMBIGUOUS_A = "aaaaaaa-aaaaa-aaaaa-aaaaa-cai"
SEED_AMBIGUOUS_B = "aaaaaaa-bbbbb-bbbbb-bbbbb-cai"
SEED_UNIQUE = "rrkah-fqaaa-aaaaa-aaaaq-cai"
UNIQUE_PREFIX = "rrkah-fq"

# No mAIner canister actually runs at SEED_UNIQUE on the local network, so the final
# `addCycles` call cannot succeed and the happy path ends here instead of at Ok.
# Everything this change introduces runs BEFORE this point - memo decode, prefix
# resolution, the minimum-amount floor, verifyIncomingPayment and the CMC conversion
# in handleIncomingFunds - so reaching this error proves all of it worked.
#
# To assert a true Ok, a stub canister exposing `addCycles` would have to be deployed
# at that address. Tracked as a follow-up; see the plan.
DELIVERY_REACHED = "Failed to credit cycles to mAIner"


def assert_reached_delivery(response: str) -> None:
    """Assert the call passed every new check and got as far as cycles delivery."""
    assert DELIVERY_REACHED in response, (
        f"expected the call to reach cycles delivery, got: {response}"
    )


def _mainer_record(address: str, owner: str) -> str:
    return (
        "record {"
        f' address = "{address}";'
        " canisterType = variant { MainerAgent = variant { Own } };"
        f' createdBy = principal "{owner}";'
        " creationTimestamp = 0 : nat64;"
        " mainerConfig = record {"
        "   cyclesForMainer = 0 : nat;"
        "   mainerAgentCanisterType = variant { Own };"
        "   selectedLLM = null;"
        '   subnetCtrl = "";'
        '   subnetLlm = "";'
        " };"
        f' ownedBy = principal "{owner}";'
        " status = variant { Running };"
        ' subnet = "";'
        "}"
    )


@pytest.fixture(scope="module")
def local_env(tmp_path_factory) -> dict:
    """Local network, funded test identity, and a seeded mAIner registry."""
    url = require_local_gateway()          # fails closed if not loopback
    principal = ensure_identity()
    pem = identity_pem(E2E_IDENTITY, tmp_path_factory.mktemp("pem") / "e2e.pem")

    # The network seeds all managed identities, but top up explicitly so the tests
    # do not depend on how much the default seeding grants.
    icp("token", "transfer", "10", principal, "-e", "local")

    gamestate = gamestate_canister_id()

    # Seed the registry. Deploy identity is the controller; see the Makefile target.
    for address in (SEED_AMBIGUOUS_A, SEED_AMBIGUOUS_B, SEED_UNIQUE):
        call_gamestate(
            "addMainerAgentCanisterAdmin", f"({_mainer_record(address, principal)})"
        )

    return {"url": url, "principal": principal, "pem": pem, "gamestate": gamestate}


def pay(local_env: dict, memo_text: str, e8s: int = COMFORTABLE_E8S) -> int:
    """Transfer ICP to GameState with a plain ASCII memo. Returns the block index."""
    result = subprocess.run(
        [
            sys.executable,
            str(PAY_TOPUP),
            SEED_UNIQUE,                   # positional; unused when --memo-text is given
            local_env["gamestate"],
            "--memo-text", memo_text,
            "--e8s", str(e8s),
            "--url", local_env["url"],     # always explicit - never the mainnet default
            "--pem", str(local_env["pem"]),
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    return int(result.stdout.strip())


def notify(block_id: int) -> str:
    return call_gamestate(
        "notifyMainerTopUp", f"(record {{ paymentTransactionBlockId = {block_id} : nat64 }})"
    )


def test__happy_path_unique_prefix(local_env: dict) -> None:
    """An 8-char prefix in the memo resolves to the matching mAIner.

    The canister log for this call shows verifyIncomingPayment receiving
    #MainerTopUp("rrkah-fqaaa-aaaaa-aaaaq-cai") - the target was derived from the
    memo alone, with no address anywhere in the call argument.
    """
    block = pay(local_env, UNIQUE_PREFIX)
    assert_reached_delivery(notify(block))


def test__happy_path_full_canister_id(local_env: dict) -> None:
    """The full canister id works too - the NNS-dapp paste-your-id flow."""
    block = pay(local_env, SEED_UNIQUE)
    assert_reached_delivery(notify(block))


def test__below_minimum_rejected(local_env: dict) -> None:
    """One e8 under the floor is refused, and the ICP stays put for the sweep."""
    block = pay(local_env, UNIQUE_PREFIX, e8s=BELOW_MIN_E8S)
    response = notify(block)
    assert "Err" in response, response
    assert "below the minimum top-up" in response, response


def test__exactly_minimum_accepted(local_env: dict) -> None:
    """The floor is inclusive - exactly 0.09 ICP must pass it.

    Paired with test__below_minimum_rejected (one e8 less), this pins the boundary.
    """
    block = pay(local_env, UNIQUE_PREFIX, e8s=MIN_TOPUP_E8S)
    assert_reached_delivery(notify(block))


def test__ambiguous_prefix_rejected(local_env: dict) -> None:
    """A prefix matching two mAIners is refused rather than credited to either."""
    block = pay(local_env, "aaaaaaa-")
    response = notify(block)
    assert "matches more than one mAIner" in response, response


def test__short_prefix_rejected(local_env: dict) -> None:
    """7 characters is below MIN_MAINER_PREFIX_LENGTH."""
    block = pay(local_env, "zzzzzzz")
    response = notify(block)
    assert "too short" in response, response


def test__unknown_prefix_rejected(local_env: dict) -> None:
    """A well-formed prefix matching nothing is refused."""
    block = pay(local_env, "qqqqqqq-qqqqq")
    response = notify(block)
    assert "No mAIner matches memo prefix" in response, response


def test__concurrent_notify_only_one_proceeds(local_env: dict) -> None:
    """The in-flight claim guard: one payment must be processed exactly once.

    This is the case dfx cannot reach - it needs the claim to be held across real
    awaits. Without the guard both calls pass checkExistingTransactionBlock and both
    run the full convert-and-deliver sequence, crediting one payment twice.
    """
    block = pay(local_env, UNIQUE_PREFIX)
    argument = f"(record {{ paymentTransactionBlockId = {block} : nat64 }})"
    procs = [
        subprocess.Popen(
            ["icp", "canister", "call", local_env["gamestate"], "notifyMainerTopUp",
             argument, "-e", "local", "--identity", E2E_IDENTITY],
            cwd=GAMESTATE_DIR, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        )
        for _ in range(2)
    ]
    outputs = [p.communicate()[0] for p in procs]
    blocked = [o for o in outputs if "already in progress" in o]
    assert len(blocked) == 1, (
        "expected exactly one of the two concurrent calls to be turned away by the "
        f"in-flight claim, got: {outputs}"
    )


def test__legacy_bound_memo_rejected(local_env: dict) -> None:
    """A [0xAD]-prefixed memo belongs to the other endpoint and is refused here."""
    result = subprocess.run(
        [
            sys.executable, str(PAY_TOPUP),
            SEED_UNIQUE, local_env["gamestate"],
            "--e8s", str(COMFORTABLE_E8S),
            "--url", local_env["url"],
            "--pem", str(local_env["pem"]),
        ],
        capture_output=True, text=True, check=True,
    )
    block = int(result.stdout.strip())
    response = notify(block)
    assert "legacy bound memo" in response, response


def test__regression_topUpCyclesForAnyMainerAgent_still_works(local_env: dict) -> None:
    """The pre-existing bound-memo endpoint must keep working after the guard/floor."""
    result = subprocess.run(
        [
            sys.executable, str(PAY_TOPUP),
            SEED_UNIQUE, local_env["gamestate"],
            "--e8s", str(COMFORTABLE_E8S),
            "--url", local_env["url"],
            "--pem", str(local_env["pem"]),
        ],
        capture_output=True, text=True, check=True,
    )
    block = int(result.stdout.strip())
    response = call_gamestate(
        "topUpCyclesForAnyMainerAgent",
        f'(record {{ mainerAgentAddress = "{SEED_UNIQUE}"; '
        f"paymentTransactionBlockId = {block} : nat64 }})",
    )
    assert_reached_delivery(response)


@pytest.mark.skip(
    reason="Needs a stub canister exposing addCycles at SEED_UNIQUE. A block is only "
           "recorded as redeemed after cycles are delivered, so replay cannot be "
           "triggered while delivery fails. Covered on the testing network instead."
)
def test__replay_rejected(local_env: dict) -> None:
    """A block already redeemed must not be redeemable again."""
    block = pay(local_env, UNIQUE_PREFIX)
    assert "Ok" in notify(block)
    assert "Already redeemd this transaction block" in notify(block)
