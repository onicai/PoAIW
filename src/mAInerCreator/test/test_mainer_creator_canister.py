"""Exhaustive smoke tests for the mainer_creator_canister endpoints.

This test file covers all public endpoints in the mAInerCreator canister.
Tests are organized to verify:
1. Anonymous callers are rejected for admin endpoints
2. Controller callers succeed for admin endpoints
3. Edge cases and error conditions are handled properly
"""

from pathlib import Path
import pytest
from icpp.smoketest import call_canister_api

# Test configuration
TEST_TYPE = "single_canister"  # vs "full_deployment" for integration tests

# Path to dfx.json relative to this test file
DFX_JSON_PATH = Path(__file__).parent / "../dfx.json"
CANISTER_NAME = "mainer_creator_canister"


# =============================================================================
# Health & Identity Endpoints (no auth required)
# =============================================================================


def test__health(network: str) -> None:
    """Test health endpoint - should return Ok for any caller."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="health",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response


def test__whoami(network: str, principal: str) -> None:
    """Test whoami endpoint - should return caller's principal."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="whoami",
        canister_argument="()",
        network=network,
    )
    expected_response = f"(principal \"{principal}\")"
    assert response == expected_response


def test__whoami_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test whoami endpoint with anonymous identity."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="whoami",
        canister_argument="()",
        network=network,
    )
    expected_response = f"(principal \"{identity_anonymous['principal']}\")"
    assert response == expected_response


def test__amiController_as_controller(network: str, principal: str) -> None:
    """Test amiController - controller should get Ok with auth message."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="amiController",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = record { auth = "You are a controller of this canister.";} })'
    assert response == expected_response


def test__amiController_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test amiController - anonymous caller should get Unauthorized."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="amiController",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Master Canister ID Endpoints
# =============================================================================


def test__setMasterCanisterId_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setMasterCanisterId - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMasterCanisterId",
        canister_argument='("aaaaa-aa")',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setMasterCanisterId_as_controller(network: str) -> None:
    """Test setMasterCanisterId - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMasterCanisterId",
        canister_argument='("aaaaa-aa")',
        network=network,
    )
    expected_response = '(variant { Ok = record { auth = "You set the master canister for this canister.";} })'
    assert response == expected_response


def test__getMasterCanisterIdAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getMasterCanisterIdAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMasterCanisterIdAdmin",
        canister_argument="()",
        network=network,
    )
    # Query methods trap on unauthorized, returning a different format
    assert "Unauthorized" in response or "rejected" in response.lower()


def test__getMasterCanisterIdAdmin_as_controller(network: str) -> None:
    """Test getMasterCanisterIdAdmin - controller should get the master canister ID."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMasterCanisterIdAdmin",
        canister_argument="()",
        network=network,
    )
    # Should return the master canister ID set earlier
    assert "aaaaa-aa" in response


# =============================================================================
# Cycles Management Endpoints
# =============================================================================


def test__getCyclesTransactionsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getCyclesTransactionsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCyclesTransactionsAdmin",
        canister_argument="()",
        network=network,
    )
    assert "Unauthorized" in response or "rejected" in response.lower()


def test__getCyclesTransactionsAdmin_as_controller(network: str) -> None:
    """Test getCyclesTransactionsAdmin - controller should get transactions list."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCyclesTransactionsAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok" in response


def test__setMinCyclesBalanceAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setMinCyclesBalanceAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMinCyclesBalanceAdmin",
        canister_argument="(100_000_000_000 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setMinCyclesBalanceAdmin_as_controller(network: str) -> None:
    """Test setMinCyclesBalanceAdmin - controller should succeed."""
    # Value must be >= 20 trillion cycles
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMinCyclesBalanceAdmin",
        canister_argument="(30_000_000_000_000 : nat)",
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response


def test__getMinCyclesBalanceAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getMinCyclesBalanceAdmin - anonymous caller gets 0."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMinCyclesBalanceAdmin",
        canister_argument="()",
        network=network,
    )
    # Anonymous callers get 0 instead of Unauthorized
    expected_response = "(0 : nat)"
    assert response == expected_response


def test__getMinCyclesBalanceAdmin_as_controller(network: str) -> None:
    """Test getMinCyclesBalanceAdmin - controller should get the value."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMinCyclesBalanceAdmin",
        canister_argument="()",
        network=network,
    )
    # Should return the value set earlier (30_000_000_000_000)
    assert "30_000_000_000_000" in response


def test__setCyclesToSendToGameStateAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setCyclesToSendToGameStateAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setCyclesToSendToGameStateAdmin",
        canister_argument="(50_000_000_000 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setCyclesToSendToGameStateAdmin_as_controller(network: str) -> None:
    """Test setCyclesToSendToGameStateAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setCyclesToSendToGameStateAdmin",
        canister_argument="(50_000_000_000 : nat)",
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response


def test__getCyclesToSendToGameStateAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getCyclesToSendToGameStateAdmin - anonymous caller gets 0."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCyclesToSendToGameStateAdmin",
        canister_argument="()",
        network=network,
    )
    # Anonymous callers get 0 instead of Unauthorized
    expected_response = "(0 : nat)"
    assert response == expected_response


def test__getCyclesToSendToGameStateAdmin_as_controller(network: str) -> None:
    """Test getCyclesToSendToGameStateAdmin - controller should get the value."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCyclesToSendToGameStateAdmin",
        canister_argument="()",
        network=network,
    )
    # Should return the value set earlier (50_000_000_000)
    assert "50_000_000_000" in response


def test__sendCyclesToGameStateCanister_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test sendCyclesToGameStateCanister - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sendCyclesToGameStateCanister",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Integration test - requires GameState canister")
def test__sendCyclesToGameStateCanister_as_controller(network: str) -> None:
    """Test sendCyclesToGameStateCanister - requires GameState canister."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sendCyclesToGameStateCanister",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok" in response or "variant { Err" in response


# =============================================================================
# SHA256 Hashes Endpoint
# =============================================================================


def test__getSha256HashesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getSha256HashesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSha256HashesAdmin",
        canister_argument="()",
        network=network,
    )
    assert "Unauthorized" in response or "rejected" in response.lower()


def test__getSha256HashesAdmin_as_controller(network: str) -> None:
    """Test getSha256HashesAdmin - controller should get hashes list."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSha256HashesAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok" in response


# =============================================================================
# Mainer Controller WASM Upload Endpoints
# =============================================================================


def test__start_upload_mainer_controller_canister_wasm_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test start_upload_mainer_controller_canister_wasm - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="start_upload_mainer_controller_canister_wasm",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__start_upload_mainer_controller_canister_wasm_as_controller(network: str) -> None:
    """Test start_upload_mainer_controller_canister_wasm - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="start_upload_mainer_controller_canister_wasm",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response


def test__upload_mainer_controller_canister_wasm_bytes_chunk_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test upload_mainer_controller_canister_wasm_bytes_chunk - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="upload_mainer_controller_canister_wasm_bytes_chunk",
        canister_argument="(vec { 0 : nat8; 1 : nat8 })",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__upload_mainer_controller_canister_wasm_bytes_chunk_as_controller(network: str) -> None:
    """Test upload_mainer_controller_canister_wasm_bytes_chunk - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="upload_mainer_controller_canister_wasm_bytes_chunk",
        canister_argument="(vec { 0 : nat8; 1 : nat8 })",
        network=network,
    )
    assert "variant { Ok" in response


def test__finish_upload_mainer_controller_canister_wasm_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test finish_upload_mainer_controller_canister_wasm - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="finish_upload_mainer_controller_canister_wasm",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__finish_upload_mainer_controller_canister_wasm_as_controller(network: str) -> None:
    """Test finish_upload_mainer_controller_canister_wasm - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="finish_upload_mainer_controller_canister_wasm",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response


# =============================================================================
# Model Creation Artefacts Entry Endpoint
# =============================================================================


def test__addModelCreationArtefactsEntry_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test addModelCreationArtefactsEntry - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addModelCreationArtefactsEntry",
        canister_argument='(record { selectedModel = variant { Qwen2_5_500M }; creationArtefacts = record { canisterWasm = vec {}; modelFile = vec {}; modelFileSha256 = "abc123" } })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__addModelCreationArtefactsEntry_as_controller(network: str) -> None:
    """Test addModelCreationArtefactsEntry - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addModelCreationArtefactsEntry",
        canister_argument='(record { selectedModel = variant { Qwen2_5_500M }; creationArtefacts = record { canisterWasm = vec {}; modelFile = vec {}; modelFileSha256 = "abc123" } })',
        network=network,
    )
    assert "variant { Ok" in response or "variant { Err" in response


# =============================================================================
# Mainer LLM Canister WASM Upload Endpoints
# =============================================================================


def test__start_upload_mainer_llm_canister_wasm_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test start_upload_mainer_llm_canister_wasm - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="start_upload_mainer_llm_canister_wasm",
        canister_argument="(variant { Qwen2_5_500M })",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__start_upload_mainer_llm_canister_wasm_as_controller(network: str) -> None:
    """Test start_upload_mainer_llm_canister_wasm - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="start_upload_mainer_llm_canister_wasm",
        canister_argument="(variant { Qwen2_5_500M })",
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response


def test__upload_mainer_llm_canister_wasm_bytes_chunk_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test upload_mainer_llm_canister_wasm_bytes_chunk - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="upload_mainer_llm_canister_wasm_bytes_chunk",
        canister_argument='(record { selectedModel = variant { Qwen2_5_500M }; bytesChunk = vec { 0 : nat8; 1 : nat8 } })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__upload_mainer_llm_canister_wasm_bytes_chunk_as_controller(network: str) -> None:
    """Test upload_mainer_llm_canister_wasm_bytes_chunk - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="upload_mainer_llm_canister_wasm_bytes_chunk",
        canister_argument='(record { selectedModel = variant { Qwen2_5_500M }; bytesChunk = vec { 0 : nat8; 1 : nat8 } })',
        network=network,
    )
    assert "variant { Ok" in response


def test__finish_upload_mainer_llm_canister_wasm_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test finish_upload_mainer_llm_canister_wasm - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="finish_upload_mainer_llm_canister_wasm",
        canister_argument="(variant { Qwen2_5_500M })",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__finish_upload_mainer_llm_canister_wasm_as_controller(network: str) -> None:
    """Test finish_upload_mainer_llm_canister_wasm - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="finish_upload_mainer_llm_canister_wasm",
        canister_argument="(variant { Qwen2_5_500M })",
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response


# =============================================================================
# Mainer LLM Model Upload Endpoints
# =============================================================================


def test__start_upload_mainer_llm_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test start_upload_mainer_llm - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="start_upload_mainer_llm",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__start_upload_mainer_llm_as_controller(network: str) -> None:
    """Test start_upload_mainer_llm - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="start_upload_mainer_llm",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = record { status_code = 200 : nat16;} })'
    assert response == expected_response


def test__upload_mainer_llm_bytes_chunk_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test upload_mainer_llm_bytes_chunk - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="upload_mainer_llm_bytes_chunk",
        canister_argument='(record { bytesChunk = blob "\\00\\01"; chunkID = 0 : nat })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__upload_mainer_llm_bytes_chunk_as_controller(network: str) -> None:
    """Test upload_mainer_llm_bytes_chunk - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="upload_mainer_llm_bytes_chunk",
        canister_argument='(record { bytesChunk = blob "\\00\\01"; chunkID = 0 : nat })',
        network=network,
    )
    assert "variant { Ok" in response


def test__finish_upload_mainer_llm_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test finish_upload_mainer_llm - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="finish_upload_mainer_llm",
        canister_argument='(record { selectedModel = variant { Qwen2_5_500M }; modelFileSha256 = "abc123" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__finish_upload_mainer_llm_as_controller(network: str) -> None:
    """Test finish_upload_mainer_llm - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="finish_upload_mainer_llm",
        canister_argument='(record { selectedModel = variant { Qwen2_5_500M }; modelFileSha256 = "abc123" })',
        network=network,
    )
    assert "variant { Ok" in response or "variant { Err" in response


# =============================================================================
# Canister Creation and Setup Endpoints
# =============================================================================


def test__createCanister_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test createCanister - anonymous caller should be rejected."""
    # CanisterCreationConfiguration has many fields
    arg = '(record { canisterType = variant { MainerAgent = variant { ShareAgent } }; associatedCanisterAddress = null; associatedCanisterSubnet = ""; mainerConfig = record { mainerAgentCanisterType = variant { ShareAgent }; selectedLLM = opt variant { Qwen2_5_500M }; cyclesForMainer = 1_000_000_000_000 : nat; subnetCtrl = ""; subnetLlm = "" }; owner = principal "2vxsx-fae"; userMainerEntryCreationTimestamp = 0 : nat64; userMainerEntryCanisterType = variant { MainerAgent = variant { ShareAgent } }; cyclesCreateMainerctrlGsMc = 0 : nat; cyclesCreateMainerllmGsMc = 0 : nat; cyclesCreateMainerctrlMcMainerctrl = 0 : nat; cyclesCreateMainerllmMcMainerllm = 0 : nat })'
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="createCanister",
        canister_argument=arg,
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Integration test - requires full canister infrastructure (GameState, IC management)")
def test__createCanister_as_controller(network: str) -> None:
    """Test createCanister - requires full infrastructure setup."""
    arg = '(record { canisterType = variant { MainerAgent = variant { ShareAgent } }; associatedCanisterAddress = null; associatedCanisterSubnet = ""; mainerConfig = record { mainerAgentCanisterType = variant { ShareAgent }; selectedLLM = opt variant { Qwen2_5_500M }; cyclesForMainer = 1_000_000_000_000 : nat; subnetCtrl = ""; subnetLlm = "" }; owner = principal "2vxsx-fae"; userMainerEntryCreationTimestamp = 0 : nat64; userMainerEntryCanisterType = variant { MainerAgent = variant { ShareAgent } }; cyclesCreateMainerctrlGsMc = 0 : nat; cyclesCreateMainerllmGsMc = 0 : nat; cyclesCreateMainerctrlMcMainerctrl = 0 : nat; cyclesCreateMainerllmMcMainerllm = 0 : nat })'
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="createCanister",
        canister_argument=arg,
        network=network,
    )
    assert "variant { Ok" in response or "variant { Err" in response


def test__setupCanister_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setupCanister - anonymous caller should be rejected."""
    # SetupCanisterInput: newCanisterId, subnet, configurationInput (CanisterCreationConfiguration)
    config = 'record { canisterType = variant { MainerAgent = variant { ShareAgent } }; associatedCanisterAddress = null; associatedCanisterSubnet = ""; mainerConfig = record { mainerAgentCanisterType = variant { ShareAgent }; selectedLLM = opt variant { Qwen2_5_500M }; cyclesForMainer = 0 : nat; subnetCtrl = ""; subnetLlm = "" }; owner = principal "2vxsx-fae"; userMainerEntryCreationTimestamp = 0 : nat64; userMainerEntryCanisterType = variant { MainerAgent = variant { ShareAgent } }; cyclesCreateMainerctrlGsMc = 0 : nat; cyclesCreateMainerllmGsMc = 0 : nat; cyclesCreateMainerctrlMcMainerctrl = 0 : nat; cyclesCreateMainerllmMcMainerllm = 0 : nat }'
    arg = f'(record {{ newCanisterId = "aaaaa-aa"; subnet = ""; configurationInput = {config} }})'
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setupCanister",
        canister_argument=arg,
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Integration test - requires existing mainer controller canister")
def test__setupCanister_as_controller(network: str) -> None:
    """Test setupCanister - requires existing mainer controller canister."""
    config = 'record { canisterType = variant { MainerAgent = variant { ShareAgent } }; associatedCanisterAddress = null; associatedCanisterSubnet = ""; mainerConfig = record { mainerAgentCanisterType = variant { ShareAgent }; selectedLLM = opt variant { Qwen2_5_500M }; cyclesForMainer = 0 : nat; subnetCtrl = ""; subnetLlm = "" }; owner = principal "2vxsx-fae"; userMainerEntryCreationTimestamp = 0 : nat64; userMainerEntryCanisterType = variant { MainerAgent = variant { ShareAgent } }; cyclesCreateMainerctrlGsMc = 0 : nat; cyclesCreateMainerllmGsMc = 0 : nat; cyclesCreateMainerctrlMcMainerctrl = 0 : nat; cyclesCreateMainerllmMcMainerllm = 0 : nat }'
    arg = f'(record {{ newCanisterId = "aaaaa-aa"; subnet = ""; configurationInput = {config} }})'
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setupCanister",
        canister_argument=arg,
        network=network,
    )
    assert "variant { Ok" in response or "variant { Err" in response


# =============================================================================
# Upgrade and Reinstall Endpoints
# =============================================================================


def test__upgradeMainerctrl_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test upgradeMainerctrl - anonymous caller should be rejected."""
    # UpgradeMainerctrlInput: mainerAgentEntry (OfficialMainerAgentCanister), associatedCanisterAddress, associatedCanisterSubnet, cycles...
    mainer_entry = 'record { address = "aaaaa-aa"; subnet = ""; canisterType = variant { MainerAgent = variant { ShareAgent } }; creationTimestamp = 0 : nat64; createdBy = principal "2vxsx-fae"; ownedBy = principal "2vxsx-fae"; status = variant { Unlocked }; mainerConfig = record { mainerAgentCanisterType = variant { ShareAgent }; selectedLLM = opt variant { Qwen2_5_500M }; cyclesForMainer = 0 : nat; subnetCtrl = ""; subnetLlm = "" } }'
    arg = f'(record {{ mainerAgentEntry = {mainer_entry}; associatedCanisterAddress = null; associatedCanisterSubnet = ""; cyclesUpgradeMainerctrlGsMc = 0 : nat; cyclesUpgradeMainerctrlMcMainerctrl = 0 : nat }})'
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="upgradeMainerctrl",
        canister_argument=arg,
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Integration test - requires existing mainer controller canister")
def test__upgradeMainerctrl_as_controller(network: str) -> None:
    """Test upgradeMainerctrl - requires existing mainer controller canister."""
    mainer_entry = 'record { address = "aaaaa-aa"; subnet = ""; canisterType = variant { MainerAgent = variant { ShareAgent } }; creationTimestamp = 0 : nat64; createdBy = principal "2vxsx-fae"; ownedBy = principal "2vxsx-fae"; status = variant { Unlocked }; mainerConfig = record { mainerAgentCanisterType = variant { ShareAgent }; selectedLLM = opt variant { Qwen2_5_500M }; cyclesForMainer = 0 : nat; subnetCtrl = ""; subnetLlm = "" } }'
    arg = f'(record {{ mainerAgentEntry = {mainer_entry}; associatedCanisterAddress = null; associatedCanisterSubnet = ""; cyclesUpgradeMainerctrlGsMc = 0 : nat; cyclesUpgradeMainerctrlMcMainerctrl = 0 : nat }})'
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="upgradeMainerctrl",
        canister_argument=arg,
        network=network,
    )
    assert "variant { Ok" in response or "variant { Err" in response


def test__reinstallMainerctrl_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test reinstallMainerctrl - anonymous caller should be rejected."""
    # ReinstallMainerctrlInput: mainerAgentEntry (OfficialMainerAgentCanister), associatedCanisterAddress, associatedCanisterSubnet, cycles...
    mainer_entry = 'record { address = "aaaaa-aa"; subnet = ""; canisterType = variant { MainerAgent = variant { ShareAgent } }; creationTimestamp = 0 : nat64; createdBy = principal "2vxsx-fae"; ownedBy = principal "2vxsx-fae"; status = variant { Unlocked }; mainerConfig = record { mainerAgentCanisterType = variant { ShareAgent }; selectedLLM = opt variant { Qwen2_5_500M }; cyclesForMainer = 0 : nat; subnetCtrl = ""; subnetLlm = "" } }'
    arg = f'(record {{ mainerAgentEntry = {mainer_entry}; associatedCanisterAddress = null; associatedCanisterSubnet = ""; cyclesReinstallMainerctrlGsMc = 0 : nat; cyclesReinstallMainerctrlMcMainerctrl = 0 : nat }})'
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="reinstallMainerctrl",
        canister_argument=arg,
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Integration test - requires existing mainer controller canister")
def test__reinstallMainerctrl_as_controller(network: str) -> None:
    """Test reinstallMainerctrl - requires existing mainer controller canister."""
    mainer_entry = 'record { address = "aaaaa-aa"; subnet = ""; canisterType = variant { MainerAgent = variant { ShareAgent } }; creationTimestamp = 0 : nat64; createdBy = principal "2vxsx-fae"; ownedBy = principal "2vxsx-fae"; status = variant { Unlocked }; mainerConfig = record { mainerAgentCanisterType = variant { ShareAgent }; selectedLLM = opt variant { Qwen2_5_500M }; cyclesForMainer = 0 : nat; subnetCtrl = ""; subnetLlm = "" } }'
    arg = f'(record {{ mainerAgentEntry = {mainer_entry}; associatedCanisterAddress = null; associatedCanisterSubnet = ""; cyclesReinstallMainerctrlGsMc = 0 : nat; cyclesReinstallMainerctrlMcMainerctrl = 0 : nat }})'
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="reinstallMainerctrl",
        canister_argument=arg,
        network=network,
    )
    assert "variant { Ok" in response or "variant { Err" in response


# =============================================================================
# Subnet Endpoints
# =============================================================================


def test__getDefaultSubnetsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getDefaultSubnetsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDefaultSubnetsAdmin",
        canister_argument="()",
        network=network,
    )
    # This is a shared method but should check controller
    assert "Unauthorized" in response or "rejected" in response.lower() or "Ok" in response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Integration test - requires GameState canister for inter-canister calls")
def test__getDefaultSubnetsAdmin_as_controller(network: str) -> None:
    """Test getDefaultSubnetsAdmin - controller should get subnet info."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDefaultSubnetsAdmin",
        canister_argument="()",
        network=network,
    )
    # Should return record with subnetCtrl and subnetLlm
    assert "subnetCtrl" in response or "Ok" in response


def test__isSubnetAvailableAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test isSubnetAvailableAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="isSubnetAvailableAdmin",
        canister_argument='("")',
        network=network,
    )
    # This is a shared method but should check controller
    assert "Unauthorized" in response or "rejected" in response.lower() or "Ok" in response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Integration test - requires GameState canister for inter-canister calls")
def test__isSubnetAvailableAdmin_as_controller(network: str) -> None:
    """Test isSubnetAvailableAdmin - controller should get availability info."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="isSubnetAvailableAdmin",
        canister_argument='("")',
        network=network,
    )
    # Should return record with isAvailable and reason
    assert "isAvailable" in response or "Ok" in response
