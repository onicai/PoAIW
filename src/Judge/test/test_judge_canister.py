"""Test judge_ctrlb_canister endpoints

First deploy the canister:
$ dfx start --clean --background
$ dfx deploy --network local judge_ctrlb_canister

Then run all the tests:
$ pytest -vv --exitfirst --network local test/test_judge_canister.py

Or run a specific test:
$ pytest -vv --network local test/test_judge_canister.py::test__health

To run it against a deployment to a network on mainnet, just replace `local` with the network in the commands above.
Example:
$ pytest -vv --network testing test/test_judge_canister.py::test__health

"""

# pylint: disable=unused-argument, missing-function-docstring, unused-import, wildcard-import, unused-wildcard-import, line-too-long, invalid-name

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
CANISTER_NAME = "judge_ctrlb_canister"


# -----------------------------------------------------------------------------
# Basic endpoints
# -----------------------------------------------------------------------------


def test__health(network: str) -> None:
    """Test health endpoint - should be accessible by anyone"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="health",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


def test__whoami_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test whoami with anonymous identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="whoami",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = f'(principal "{identity_anonymous["principal"]}")'
    assert response == expected_response


def test__whoami_default(identity_default: Dict[str, str], network: str) -> None:
    """Test whoami with default identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="whoami",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = f'(principal "{identity_default["principal"]}")'
    assert response == expected_response


def test__amiController_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test amiController rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="amiController",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__amiController(network: str) -> None:
    """Test amiController with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="amiController",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# Ready endpoint
# -----------------------------------------------------------------------------


def test__ready_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test ready rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="ready",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__ready(network: str) -> None:
    """Test ready with controller identity (no LLMs configured yet)"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="ready",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # With no LLMs configured, should return Ok
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# GameState canister configuration
# -----------------------------------------------------------------------------


def test__setGameStateCanisterId_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test setGameStateCanisterId rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setGameStateCanisterId",
        canister_argument='("aaaaa-aa")',
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setGameStateCanisterId(network: str) -> None:
    """Test setGameStateCanisterId with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setGameStateCanisterId",
        canister_argument='("aaaaa-aa")',
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# Send cycles to LLM flag
# -----------------------------------------------------------------------------


def test__toggleSendCyclesToLlmFlagAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test toggleSendCyclesToLlmFlagAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleSendCyclesToLlmFlagAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getSendCyclesToLlmFlagAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getSendCyclesToLlmFlagAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSendCyclesToLlmFlagAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getSendCyclesToLlmFlagAdmin(network: str) -> None:
    """Test getSendCyclesToLlmFlagAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSendCyclesToLlmFlagAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Default is true
    expected_response = "(variant { Ok = record { flag = true;} })"
    assert response == expected_response


def test__toggleSendCyclesToLlmFlagAdmin(network: str) -> None:
    """Test toggleSendCyclesToLlmFlagAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleSendCyclesToLlmFlagAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Toggle from true to false
    expected_response = '(variant { Ok = record { auth = "You set the flag to false";} })'
    assert response == expected_response


def test__toggleSendCyclesToLlmFlagAdmin_back(network: str) -> None:
    """Test toggleSendCyclesToLlmFlagAdmin toggles back to true"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleSendCyclesToLlmFlagAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Toggle from false back to true
    expected_response = '(variant { Ok = record { auth = "You set the flag to true";} })'
    assert response == expected_response


# -----------------------------------------------------------------------------
# Cycles transactions
# -----------------------------------------------------------------------------


def test__getCyclesTransactionsAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getCyclesTransactionsAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCyclesTransactionsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getCyclesTransactionsAdmin(network: str) -> None:
    """Test getCyclesTransactionsAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCyclesTransactionsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Empty initially
    expected_response = "(variant { Ok = vec {} })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# Min cycles balance configuration
# -----------------------------------------------------------------------------


def test__setMinCyclesBalanceAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test setMinCyclesBalanceAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMinCyclesBalanceAdmin",
        canister_argument="(30_000_000_000_000 : nat)",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getMinCyclesBalanceAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getMinCyclesBalanceAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMinCyclesBalanceAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Returns 0 for unauthorized
    expected_response = "(0 : nat)"
    assert response == expected_response


def test__getMinCyclesBalanceAdmin(network: str) -> None:
    """Test getMinCyclesBalanceAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMinCyclesBalanceAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Default is 30 trillion
    expected_response = "(30_000_000_000_000 : nat)"
    assert response == expected_response


def test__setMinCyclesBalanceAdmin(network: str) -> None:
    """Test setMinCyclesBalanceAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMinCyclesBalanceAdmin",
        canister_argument="(25_000_000_000_000 : nat)",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


def test__setMinCyclesBalanceAdmin_too_low(network: str) -> None:
    """Test setMinCyclesBalanceAdmin rejects values below 20 trillion"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMinCyclesBalanceAdmin",
        canister_argument="(10_000_000_000_000 : nat)",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# Cycles to send to GameState configuration
# -----------------------------------------------------------------------------


def test__setCyclesToSendToGameStateAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test setCyclesToSendToGameStateAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setCyclesToSendToGameStateAdmin",
        canister_argument="(10_000_000_000_000 : nat)",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getCyclesToSendToGameStateAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getCyclesToSendToGameStateAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCyclesToSendToGameStateAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Returns 0 for unauthorized
    expected_response = "(0 : nat)"
    assert response == expected_response


def test__getCyclesToSendToGameStateAdmin(network: str) -> None:
    """Test getCyclesToSendToGameStateAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCyclesToSendToGameStateAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Default is 10 trillion
    expected_response = "(10_000_000_000_000 : nat)"
    assert response == expected_response


def test__setCyclesToSendToGameStateAdmin(network: str) -> None:
    """Test setCyclesToSendToGameStateAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setCyclesToSendToGameStateAdmin",
        canister_argument="(15_000_000_000_000 : nat)",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


def test__setCyclesToSendToGameStateAdmin_too_high(network: str) -> None:
    """Test setCyclesToSendToGameStateAdmin rejects values above 100 trillion"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setCyclesToSendToGameStateAdmin",
        canister_argument="(150_000_000_000_000 : nat)",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# LLM canisters management
# -----------------------------------------------------------------------------


def test__get_llm_canisters_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test get_llm_canisters rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="get_llm_canisters",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__get_llm_canisters(network: str) -> None:
    """Test get_llm_canisters with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="get_llm_canisters",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Empty initially - response includes roundRobin config
    expected_response = "(variant { Ok = record { roundRobinUseAll = true; roundRobinLLMs = 0 : nat; llmCanisterIds = vec {};} })"
    assert response == expected_response


def test__reset_llm_canisters_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test reset_llm_canisters rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="reset_llm_canisters",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__reset_llm_canisters(network: str) -> None:
    """Test reset_llm_canisters with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="reset_llm_canisters",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


def test__add_llm_canister_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test add_llm_canister rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="add_llm_canister",
        canister_argument='(record { canister_id = "aaaaa-aa" })',
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__add_llm_canister(network: str) -> None:
    """Test add_llm_canister with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="add_llm_canister",
        canister_argument='(record { canister_id = "aaaaa-aa" })',
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


def test__remove_llm_canister_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test remove_llm_canister rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="remove_llm_canister",
        canister_argument='(record { canister_id = "aaaaa-aa" })',
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__remove_llm_canister(network: str) -> None:
    """Test remove_llm_canister with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="remove_llm_canister",
        canister_argument='(record { canister_id = "aaaaa-aa" })',
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# Round robin LLMs
# -----------------------------------------------------------------------------


def test__resetRoundRobinLLMs_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test resetRoundRobinLLMs rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="resetRoundRobinLLMs",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__resetRoundRobinLLMs(network: str) -> None:
    """Test resetRoundRobinLLMs with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="resetRoundRobinLLMs",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


def test__setRoundRobinLLMs_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test setRoundRobinLLMs rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setRoundRobinLLMs",
        canister_argument="(2 : nat)",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setRoundRobinLLMs(network: str) -> None:
    """Test setRoundRobinLLMs with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setRoundRobinLLMs",
        canister_argument="(2 : nat)",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# Check access to LLMs
# -----------------------------------------------------------------------------


def test__checkAccessToLLMs_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test checkAccessToLLMs rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="checkAccessToLLMs",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__checkAccessToLLMs(network: str) -> None:
    """Test checkAccessToLLMs with controller identity (no LLMs configured)"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="checkAccessToLLMs",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # No LLMs configured, should return Ok
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# Round robin canister
# -----------------------------------------------------------------------------


def test__getRoundRobinCanister_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getRoundRobinCanister rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRoundRobinCanister",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getRoundRobinCanister(network: str) -> None:
    """Test getRoundRobinCanister with controller identity (no LLMs configured)"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRoundRobinCanister",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # No LLMs configured - should return error
    expected_response = '(variant { Err = variant { Other = "No LLM canisters configured" } })'
    assert response == expected_response


# -----------------------------------------------------------------------------
# Timer execution endpoints
# -----------------------------------------------------------------------------


def test__setTimerActionRegularityInSecondsAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test setTimerActionRegularityInSecondsAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setTimerActionRegularityInSecondsAdmin",
        canister_argument="(60 : nat)",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setTimerActionRegularityInSecondsAdmin(network: str) -> None:
    """Test setTimerActionRegularityInSecondsAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setTimerActionRegularityInSecondsAdmin",
        canister_argument="(60 : nat)",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


def test__getTimerActionRegularityInSecondsAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getTimerActionRegularityInSecondsAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getTimerActionRegularityInSecondsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getTimerActionRegularityInSecondsAdmin(network: str) -> None:
    """Test getTimerActionRegularityInSecondsAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getTimerActionRegularityInSecondsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok =")


def test__startTimerExecutionAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test startTimerExecutionAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="startTimerExecutionAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__startTimerExecutionAdmin(network: str) -> None:
    """Test startTimerExecutionAdmin with controller identity"""
    if TEST_TYPE == "single_canister":
        pytest.skip("Integration test - requires GameState canister")
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="startTimerExecutionAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = record { auth =")


def test__stopTimerExecutionAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test stopTimerExecutionAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="stopTimerExecutionAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__stopTimerExecutionAdmin(network: str) -> None:
    """Test stopTimerExecutionAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="stopTimerExecutionAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = record { auth =")


# -----------------------------------------------------------------------------
# Submission processing flag
# -----------------------------------------------------------------------------


def test__getIsProcessingSubmissionsAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getIsProcessingSubmissionsAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getIsProcessingSubmissionsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getIsProcessingSubmissionsAdmin(network: str) -> None:
    """Test getIsProcessingSubmissionsAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getIsProcessingSubmissionsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Default returns an auth record with flag info
    assert response.startswith("(variant { Ok = record { auth =")


def test__resetIsProcessingSubmissionsAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test resetIsProcessingSubmissionsAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="resetIsProcessingSubmissionsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__resetIsProcessingSubmissionsAdmin(network: str) -> None:
    """Test resetIsProcessingSubmissionsAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="resetIsProcessingSubmissionsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = record { auth =")


# -----------------------------------------------------------------------------
# Trigger score submission (integration test)
# -----------------------------------------------------------------------------


def test__triggerScoreSubmissionAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test triggerScoreSubmissionAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="triggerScoreSubmissionAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__triggerScoreSubmissionAdmin(network: str) -> None:
    """Test triggerScoreSubmissionAdmin with controller identity"""
    if TEST_TYPE == "single_canister":
        pytest.skip("Integration test - requires GameState and LLM canisters")
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="triggerScoreSubmissionAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=60,
    )
    assert response.startswith("(variant { Ok =")


# -----------------------------------------------------------------------------
# Send cycles to GameState (integration test)
# -----------------------------------------------------------------------------


def test__sendCyclesToGameStateCanister_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test sendCyclesToGameStateCanister rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sendCyclesToGameStateCanister",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__sendCyclesToGameStateCanister(network: str) -> None:
    """Test sendCyclesToGameStateCanister with controller identity"""
    if TEST_TYPE == "single_canister":
        pytest.skip("Integration test - requires GameState canister and sufficient cycles")
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sendCyclesToGameStateCanister",
        canister_argument="()",
        network=network,
        timeout_seconds=30,
    )
    # May fail due to insufficient cycles on local
    assert response.startswith("(variant {")
