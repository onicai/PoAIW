"""Test mainer_ctrlb_canister_0 endpoints

First deploy the canister:
$ dfx start --clean --background
$ dfx deploy --network local mainer_ctrlb_canister_0

Then run all the tests:
$ pytest -vv --exitfirst --network local test/test_mainer_ctrlb_canister_0.py

Or run a specific test:
$ pytest -vv --network local test/test_mainer_ctrlb_canister_0.py::test__health

To run it against a deployment to a network on mainnet, just replace `local` with the network in the commands above.
Example:
$ pytest -vv --network testing test/test_mainer_ctrlb_canister_0.py::test__health

Note: Some tests are duplicated from test_mainer_service_canister.py. This is intentional
to enable running a full test suite on each canister independently, allowing the canisters
to be separated out into different test runs or deployments in the future.

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
CANISTER_NAME = "mainer_ctrlb_canister_0"


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


def test__whoami_anonymous(identity_anonymous: dict[str, str], network: str) -> None:
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


def test__whoami_default(identity_default: dict[str, str], network: str) -> None:
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
    identity_anonymous: dict[str, str], network: str
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
# Canister type configuration
# -----------------------------------------------------------------------------


def test__setMainerCanisterType_anonymous(
    identity_anonymous: dict[str, str], network: str
) -> None:
    """Test setMainerCanisterType rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMainerCanisterType",
        canister_argument="(variant { ShareAgent })",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setMainerCanisterType(network: str) -> None:
    """Test setMainerCanisterType with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMainerCanisterType",
        canister_argument="(variant { ShareAgent })",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


def test__getMainerCanisterType_anonymous(
    identity_anonymous: dict[str, str], network: str
) -> None:
    """Test getMainerCanisterType rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainerCanisterType",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getMainerCanisterType(network: str) -> None:
    """Test getMainerCanisterType with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainerCanisterType",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # After previous test, type should be ShareAgent
    expected_response = "(variant { Ok = variant { ShareAgent } })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# Game state canister configuration
# -----------------------------------------------------------------------------


def test__setGameStateCanisterId_anonymous(
    identity_anonymous: dict[str, str], network: str
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


def test__getGameStateCanisterId_anonymous(
    identity_anonymous: dict[str, str], network: str
) -> None:
    """Test getGameStateCanisterId rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getGameStateCanisterId",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # This endpoint returns plain Text, so error is encoded as text
    expected_response = '("#Err(#Unauthorized)")'
    assert response == expected_response


def test__getGameStateCanisterId(network: str) -> None:
    """Test getGameStateCanisterId with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getGameStateCanisterId",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Returns plain Text, should be "aaaaa-aa" from previous test
    expected_response = '("aaaaa-aa")'
    assert response == expected_response


# -----------------------------------------------------------------------------
# Admin RBAC Endpoints - Anonymous Access Denial Tests
# -----------------------------------------------------------------------------


def test__getAdminRoles_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test getAdminRoles rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getAdminRoles",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__assignAdminRole_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test assignAdminRole rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="assignAdminRole",
        canister_argument='(record { "principal" = "aaaaa-aa"; role = variant { AdminQuery }; note = "test" })',
        network=network,
        timeout_seconds=10,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__revokeAdminRole_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test revokeAdminRole rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="revokeAdminRole",
        canister_argument='("aaaaa-aa")',
        network=network,
        timeout_seconds=10,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


# -----------------------------------------------------------------------------
# Admin RBAC Management - Success Tests (controller can manage roles)
# -----------------------------------------------------------------------------


def test__setup_cleanup_admin_roles(network: str) -> None:
    """Setup: Clean up any existing admin roles from previous test runs"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="revokeAdminRole",
        canister_argument='("aaaaa-aa")',
        network=network,
        timeout_seconds=10,
    )
    # Accept either Ok (role revoked) or Err (role not found)
    assert response in [
        '(variant { Ok = "Admin role revoked for principal: aaaaa-aa" })',
        '(variant { Err = variant { Other = "No admin role found for principal: aaaaa-aa" } })'
    ]


def test__getAdminRoles_empty(network: str) -> None:
    """Test getAdminRoles returns empty list initially"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getAdminRoles",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = '(variant { Ok = vec {} })'
    assert response == expected_response


def test__assignAdminRole_AdminQuery(network: str) -> None:
    """Test assignAdminRole assigns AdminQuery role"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="assignAdminRole",
        canister_argument='(record { "principal" = "aaaaa-aa"; role = variant { AdminQuery }; note = "Test admin query role" })',
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith('(variant { Ok = record {')
    assert '"principal" = "aaaaa-aa"' in response
    assert 'AdminQuery' in response


def test__getAdminRoles_after_assign(network: str) -> None:
    """Test getAdminRoles returns assigned roles"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getAdminRoles",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith('(variant { Ok = vec {')
    assert 'aaaaa-aa' in response


def test__revokeAdminRole(network: str) -> None:
    """Test revokeAdminRole removes role"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="revokeAdminRole",
        canister_argument='("aaaaa-aa")',
        network=network,
        timeout_seconds=10,
    )
    expected_response = '(variant { Ok = "Admin role revoked for principal: aaaaa-aa" })'
    assert response == expected_response


def test__revokeAdminRole_not_found(network: str) -> None:
    """Test revokeAdminRole returns error for non-existent principal"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="revokeAdminRole",
        canister_argument='("non-existent-principal")',
        network=network,
        timeout_seconds=10,
    )
    expected_response = '(variant { Err = variant { Other = "No admin role found for principal: non-existent-principal" } })'
    assert response == expected_response


# -----------------------------------------------------------------------------
# Maintenance Endpoints
# -----------------------------------------------------------------------------


def test__getMaintenanceFlag(network: str) -> None:
    """Test getMaintenanceFlag - public query, should be accessible"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMaintenanceFlag",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Returns a FlagResult with a boolean
    assert response.startswith("(variant { Ok =")


def test__toggleMaintenanceFlagAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test toggleMaintenanceFlagAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleMaintenanceFlagAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__toggleMaintenanceFlagAdmin(network: str) -> None:
    """Test toggleMaintenanceFlagAdmin with controller identity - toggle twice to restore state"""
    # First toggle
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleMaintenanceFlagAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = record { auth =")

    # Toggle back to restore original state
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleMaintenanceFlagAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = record { auth =")


# -----------------------------------------------------------------------------
# Cycles Endpoint
# -----------------------------------------------------------------------------


def test__addCycles_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test addCycles rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addCycles",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__addCycles(network: str) -> None:
    """Test addCycles with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addCycles",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Returns AddCyclesResult with cycles info
    assert response.startswith("(variant { Ok = record {")


# -----------------------------------------------------------------------------
# Issue Flags and Statistics Endpoints
# -----------------------------------------------------------------------------


def test__getIssueFlagsAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getIssueFlagsAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getIssueFlagsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getIssueFlagsAdmin(network: str) -> None:
    """Test getIssueFlagsAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getIssueFlagsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = record {")


def test__getMainerStatisticsAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getMainerStatisticsAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainerStatisticsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getMainerStatisticsAdmin(network: str) -> None:
    """Test getMainerStatisticsAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainerStatisticsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = record {")


# -----------------------------------------------------------------------------
# Agent Settings Endpoints
# -----------------------------------------------------------------------------


def test__getCurrentAgentSettingsAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getCurrentAgentSettingsAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCurrentAgentSettingsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getAgentSettingsAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getAgentSettingsAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getAgentSettingsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getAgentSettingsAdmin(network: str) -> None:
    """Test getAgentSettingsAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getAgentSettingsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = vec")


def test__canAgentSettingsBeUpdated_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test canAgentSettingsBeUpdated rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="canAgentSettingsBeUpdated",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__canAgentSettingsBeUpdated(network: str) -> None:
    """Test canAgentSettingsBeUpdated with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="canAgentSettingsBeUpdated",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Returns StatusCodeRecordResult
    assert "variant { Ok" in response or "variant { Err" in response


def test__timeToNextAgentSettingsUpdate_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test timeToNextAgentSettingsUpdate rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="timeToNextAgentSettingsUpdate",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__timeToNextAgentSettingsUpdate(network: str) -> None:
    """Test timeToNextAgentSettingsUpdate with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="timeToNextAgentSettingsUpdate",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Returns NatResult
    assert "variant { Ok" in response and ": nat" in response


def test__updateAgentSettings_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test updateAgentSettings rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="updateAgentSettings",
        canister_argument="(record { cyclesBurnRate = variant { Low } })",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__updateAgentSettings(network: str) -> None:
    """Test updateAgentSettings with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="updateAgentSettings",
        canister_argument="(record { cyclesBurnRate = variant { Mid } })",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


def test__getCurrentAgentSettingsAdmin(network: str) -> None:
    """Test getCurrentAgentSettingsAdmin with controller identity - after settings updated"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCurrentAgentSettingsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = record {")
    assert "Mid" in response


# -----------------------------------------------------------------------------
# Agent Timers Endpoints
# -----------------------------------------------------------------------------


def test__getCurrentAgentTimersAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getCurrentAgentTimersAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCurrentAgentTimersAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getAgentTimersAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getAgentTimersAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getAgentTimersAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# Challenge Queue Endpoints
# -----------------------------------------------------------------------------


def test__getChallengeQueueAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getChallengeQueueAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getChallengeQueueAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getChallengeQueueAdmin(network: str) -> None:
    """Test getChallengeQueueAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getChallengeQueueAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = vec")


def test__resetChallengeQueueAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test resetChallengeQueueAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="resetChallengeQueueAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__resetChallengeQueueAdmin(network: str) -> None:
    """Test resetChallengeQueueAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="resetChallengeQueueAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# Submitted Responses Endpoints
# -----------------------------------------------------------------------------


def test__getSubmittedResponsesAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getSubmittedResponsesAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSubmittedResponsesAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getSubmittedResponsesAdmin(network: str) -> None:
    """Test getSubmittedResponsesAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSubmittedResponsesAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = vec")


def test__getRecentSubmittedResponsesAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getRecentSubmittedResponsesAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRecentSubmittedResponsesAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getRecentSubmittedResponsesAdmin(network: str) -> None:
    """Test getRecentSubmittedResponsesAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRecentSubmittedResponsesAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = vec")


# -----------------------------------------------------------------------------
# LLM Canisters Endpoints
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
    assert response.startswith("(variant { Ok = record {")


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
        canister_argument="(1 : nat)",
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
        canister_argument="(1 : nat)",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


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
    """Test checkAccessToLLMs with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="checkAccessToLLMs",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # May succeed or fail depending on LLM setup
    assert "variant {" in response


def test__getLLMCanisterIds_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getLLMCanisterIds rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getLLMCanisterIds",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getLLMCanisterIds(network: str) -> None:
    """Test getLLMCanisterIds with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getLLMCanisterIds",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = vec")


# -----------------------------------------------------------------------------
# Ready and Round Robin Endpoints
# -----------------------------------------------------------------------------


def test__ready_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
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
    """Test ready with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="ready",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # May return Ok or Err depending on canister state
    assert "variant {" in response


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
    """Test getRoundRobinCanister with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRoundRobinCanister",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Returns error when no LLM canisters configured, Ok otherwise
    assert response in [
        '(variant { Err = variant { Other = "No LLM canisters configured" } })'
    ] or response.startswith("(variant { Ok = record {")


# -----------------------------------------------------------------------------
# Share Agent Management Endpoints
# -----------------------------------------------------------------------------


def test__addChallengeResponseToShareAgent_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test addChallengeResponseToShareAgent rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addChallengeResponseToShareAgent",
        canister_argument='(record { challengeTopic = "test"; challengeTopicId = "test"; challengeTopicCreationTimestamp = 0 : nat64; challengeTopicStatus = variant { Open }; cyclesGenerateChallengeGsChctrl = 0 : nat; cyclesGenerateChallengeChctrlChllm = 0 : nat; challengeQuestion = "test"; challengeQuestionSeed = 0 : nat32; mainerPromptId = "test"; mainerMaxContinueLoopCount = 0 : nat; mainerNumTokens = 0 : nat64; mainerTemp = 0.0 : float64; judgePromptId = "test"; challengeId = "test"; challengeCreationTimestamp = 0 : nat64; challengeCreatedBy = "aaaaa-aa"; challengeStatus = variant { Open }; challengeClosedTimestamp = null; cyclesSubmitResponse = 0 : nat; protocolOperationFeesCut = 0 : nat; cyclesGenerateResponseSactrlSsctrl = 0 : nat; cyclesGenerateResponseSsctrlGs = 0 : nat; cyclesGenerateResponseSsctrlSsllm = 0 : nat; cyclesGenerateResponseOwnctrlGs = 0 : nat; cyclesGenerateResponseOwnctrlOwnllmLOW = 0 : nat; cyclesGenerateResponseOwnctrlOwnllmMEDIUM = 0 : nat; cyclesGenerateResponseOwnctrlOwnllmHIGH = 0 : nat; challengeQueuedId = "test"; challengeQueuedBy = principal "aaaaa-aa"; challengeQueuedTo = principal "aaaaa-aa"; challengeQueuedTimestamp = 0 : nat64; challengeAnswer = "test"; challengeAnswerSeed = 0 : nat32; submittedBy = principal "aaaaa-aa" })',
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__addChallengeToShareServiceQueue_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test addChallengeToShareServiceQueue rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addChallengeToShareServiceQueue",
        canister_argument='(record { challengeTopic = "test"; challengeTopicId = "test"; challengeTopicCreationTimestamp = 0 : nat64; challengeTopicStatus = variant { Open }; cyclesGenerateChallengeGsChctrl = 0 : nat; cyclesGenerateChallengeChctrlChllm = 0 : nat; challengeQuestion = "test"; challengeQuestionSeed = 0 : nat32; mainerPromptId = "test"; mainerMaxContinueLoopCount = 0 : nat; mainerNumTokens = 0 : nat64; mainerTemp = 0.0 : float64; judgePromptId = "test"; challengeId = "test"; challengeCreationTimestamp = 0 : nat64; challengeCreatedBy = "aaaaa-aa"; challengeStatus = variant { Open }; challengeClosedTimestamp = null; cyclesSubmitResponse = 0 : nat; protocolOperationFeesCut = 0 : nat; cyclesGenerateResponseSactrlSsctrl = 0 : nat; cyclesGenerateResponseSsctrlGs = 0 : nat; cyclesGenerateResponseSsctrlSsllm = 0 : nat; cyclesGenerateResponseOwnctrlGs = 0 : nat; cyclesGenerateResponseOwnctrlOwnllmLOW = 0 : nat; cyclesGenerateResponseOwnctrlOwnllmMEDIUM = 0 : nat; cyclesGenerateResponseOwnctrlOwnllmHIGH = 0 : nat; challengeQueuedId = "test"; challengeQueuedBy = principal "aaaaa-aa"; challengeQueuedTo = principal "aaaaa-aa"; challengeQueuedTimestamp = 0 : nat64 })',
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# Helper for OfficialMainerAgentCanister argument
OFFICIAL_MAINER_AGENT_CANISTER_ARG = """(record {
    address = "aaaaa-aa";
    subnet = "";
    canisterType = variant { MainerAgent = variant { ShareAgent } };
    creationTimestamp = 0 : nat64;
    createdBy = principal "aaaaa-aa";
    ownedBy = principal "aaaaa-aa";
    status = variant { Unlocked };
    mainerConfig = record {
        mainerAgentCanisterType = variant { ShareAgent };
        selectedLLM = null;
        cyclesForMainer = 0 : nat;
        subnetCtrl = "";
        subnetLlm = ""
    }
})"""


def test__addMainerShareAgentCanister_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test addMainerShareAgentCanister rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addMainerShareAgentCanister",
        canister_argument=OFFICIAL_MAINER_AGENT_CANISTER_ARG,
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__addMainerShareAgentCanisterAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test addMainerShareAgentCanisterAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addMainerShareAgentCanisterAdmin",
        canister_argument=OFFICIAL_MAINER_AGENT_CANISTER_ARG,
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__addMainerShareAgentCanisterAdmin(network: str) -> None:
    """Test addMainerShareAgentCanisterAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addMainerShareAgentCanisterAdmin",
        canister_argument=OFFICIAL_MAINER_AGENT_CANISTER_ARG,
        network=network,
        timeout_seconds=10,
    )
    # Returns MainerAgentCanisterResult
    assert response.startswith("(variant { Ok = record {")


# -----------------------------------------------------------------------------
# Timer Execution Endpoints
# -----------------------------------------------------------------------------


def test__setTimerAction2RegularityInSecondsAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test setTimerAction2RegularityInSecondsAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setTimerAction2RegularityInSecondsAdmin",
        canister_argument="(60 : nat)",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Integration test - requires GameState canister")
def test__setTimerAction2RegularityInSecondsAdmin(network: str) -> None:
    """Test setTimerAction2RegularityInSecondsAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setTimerAction2RegularityInSecondsAdmin",
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
    assert response.startswith("(variant { Ok = record {")


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


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Integration test - requires GameState canister")
def test__startTimerExecutionAdmin(network: str) -> None:
    """Test startTimerExecutionAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="startTimerExecutionAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = record { auth =")


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Integration test - requires GameState canister (timer must be started)")
def test__getCurrentAgentTimersAdmin_after_timer_start(network: str) -> None:
    """Test getCurrentAgentTimersAdmin with controller identity - after timer started"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCurrentAgentTimersAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = record {")


def test__getAgentTimersAdmin_after_timer_start(network: str) -> None:
    """Test getAgentTimersAdmin with controller identity - after timer started"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getAgentTimersAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = vec")


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


def test__getTimerBuffersAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getTimerBuffersAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getTimerBuffersAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getTimerBuffersAdmin(network: str) -> None:
    """Test getTimerBuffersAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getTimerBuffersAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = record {")


def test__setTimerBufferMaxSizeAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test setTimerBufferMaxSizeAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setTimerBufferMaxSizeAdmin",
        canister_argument="(100 : nat)",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setTimerBufferMaxSizeAdmin(network: str) -> None:
    """Test setTimerBufferMaxSizeAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setTimerBufferMaxSizeAdmin",
        canister_argument="(100 : nat)",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


def test__getTimerBufferMaxSizeAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getTimerBufferMaxSizeAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getTimerBufferMaxSizeAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getTimerBufferMaxSizeAdmin(network: str) -> None:
    """Test getTimerBufferMaxSizeAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getTimerBufferMaxSizeAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert "variant { Ok" in response and ": nat" in response


def test__triggerChallengeResponseAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test triggerChallengeResponseAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="triggerChallengeResponseAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Integration test - requires GameState canister")
def test__triggerChallengeResponseAdmin(network: str) -> None:
    """Test triggerChallengeResponseAdmin with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="triggerChallengeResponseAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = record { auth =")
