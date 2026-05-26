"""Test api_canister endpoints

First deploy the canister:
$ dfx start --clean --background
$ dfx deploy --network local

Then run all the tests:
$ pytest -vv --exitfirst --network local test/test_api_canister.py

Or run a specific test:
$ pytest -vv --network local test/test_api_canister.py::test__health

To run it against a deployment to a network on mainnet, just replace `local` with the network in the commands above.
Example: 
$ pytest -vv --network testing test/test_api_canister.py::test__health

"""
# pylint: disable=missing-function-docstring, unused-import, wildcard-import, unused-wildcard-import, line-too-long

from pathlib import Path
from typing import Dict
import pytest
from icpp.smoketest import call_canister_api, dict_to_candid_text

# Test type configuration
# - "single_canister": Only tests that don't require other canisters (e.g., GameState)
# - "full_deployment": All tests including integration tests (requires full deployment)
TEST_TYPE = "single_canister"

# Path to the dfx.json file
DFX_JSON_PATH = Path(__file__).parent / "../dfx.json"

# Canister in the dfx.json file we want to test
CANISTER_NAME = "api_canister"


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


def test__whoami(network: str, principal: str) -> None:
    """Test whoami endpoint returns caller's principal"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="whoami",
        canister_argument="()",
        network=network,
    )
    expected_response = f'(principal "{principal}")'
    assert response == expected_response


def test__whoami_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test whoami endpoint returns anonymous principal"""
    assert identity_anonymous["identity"] == "anonymous"
    assert identity_anonymous["principal"] == "2vxsx-fae"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="whoami",
        canister_argument="()",
        network=network,
    )
    expected_response = '(principal "2vxsx-fae")'
    assert response == expected_response


def test__getNumDailyMetrics(network: str) -> None:
    """Test getNumDailyMetrics returns count (initially 0)"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumDailyMetrics",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = 0 : nat })'
    assert response == expected_response


def test__getDailyMetrics_empty(network: str) -> None:
    """Test getDailyMetrics returns empty response when no metrics exist"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDailyMetrics",
        canister_argument="(null)",
        network=network,
    )
    expected_response = '(variant { Ok = record { period = record { end_date = ""; total_days = 0 : nat; start_date = "";}; daily_metrics = vec {};} })'
    assert response == expected_response


def test__getLatestDailyMetric_empty(network: str) -> None:
    """Test getLatestDailyMetric returns error when no metrics exist"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getLatestDailyMetric",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Err = variant { Other = "No metrics available" } })'
    assert response == expected_response


def test__getDailyMetricByDate_not_found(network: str) -> None:
    """Test getDailyMetricByDate returns error for non-existent date"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDailyMetricByDate",
        canister_argument='("2025-01-01")',
        network=network,
    )
    expected_response = '(variant { Err = variant { Other = "Metric for date 2025-01-01 not found" } })'
    assert response == expected_response


def test__getDailyMetricByDate_invalid_format(network: str) -> None:
    """Test getDailyMetricByDate returns error for invalid date format"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDailyMetricByDate",
        canister_argument='("invalid-date")',
        network=network,
    )
    expected_response = '(variant { Err = variant { Other = "Invalid date format. Use YYYY-MM-DD" } })'
    assert response == expected_response


def test__getTokenRewardsData(network: str) -> None:
    """Test getTokenRewardsData returns token rewards data"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getTokenRewardsData",
        canister_argument="()",
        network=network,
    )
    # Check that the response starts with Ok and contains expected metadata
    assert response.startswith('(variant { Ok = record {')
    assert 'FUNNAI Token Minting Data' in response
    assert 'metadata' in response
    assert 'data' in response


# =============================================================================
# Controller-Only Endpoints - Anonymous Access Denial Tests
# =============================================================================

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


def test__getMasterCanisterId_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test getMasterCanisterId rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMasterCanisterId",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__setMasterCanisterId_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test setMasterCanisterId rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMasterCanisterId",
        canister_argument='("aaaaa-aa")',
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__getAdminRoles_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test getAdminRoles rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getAdminRoles",
        canister_argument="()",
        network=network,
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
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__resetDailyMetricsAdmin_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test resetDailyMetricsAdmin rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="resetDailyMetricsAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


# =============================================================================
# Admin RBAC Endpoints - Anonymous Access Denial Tests
# =============================================================================

def test__createDailyMetricAdmin_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test createDailyMetricAdmin rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="createDailyMetricAdmin",
        canister_argument='(record { date = "2025-01-01"; funnai_index = 100.0; daily_burn_rate_cycles = 1000 : nat; daily_burn_rate_usd = 0.01; total_mainers_created = 10 : nat; total_active_mainers = 5 : nat; total_paused_mainers = 5 : nat; total_cycles_all_mainers = 10000 : nat; active_low_burn_rate_mainers = 1 : nat; active_medium_burn_rate_mainers = 1 : nat; active_high_burn_rate_mainers = 1 : nat; active_very_high_burn_rate_mainers = 1 : nat; active_custom_burn_rate_mainers = 1 : nat; paused_low_burn_rate_mainers = 1 : nat; paused_medium_burn_rate_mainers = 1 : nat; paused_high_burn_rate_mainers = 1 : nat; paused_very_high_burn_rate_mainers = 1 : nat; paused_custom_burn_rate_mainers = 1 : nat })',
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__updateDailyMetricAdmin_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test updateDailyMetricAdmin rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="updateDailyMetricAdmin",
        canister_argument='(record { date = "2025-01-01"; input = record { funnai_index = opt 150.0 } })',
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__deleteDailyMetricAdmin_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test deleteDailyMetricAdmin rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="deleteDailyMetricAdmin",
        canister_argument='("2025-01-01")',
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__getDailyMetricsAdmin_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test getDailyMetricsAdmin rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDailyMetricsAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__bulkCreateDailyMetricsAdmin_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test bulkCreateDailyMetricsAdmin rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="bulkCreateDailyMetricsAdmin",
        canister_argument='(vec {})',
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


# =============================================================================
# Controller-Only Endpoints - Success Tests (requires controller identity)
# =============================================================================

def test__setup_cleanup_admin_roles(network: str) -> None:
    """Setup: Clean up any existing admin roles from previous test runs"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="revokeAdminRole",
        canister_argument='("aaaaa-aa")',
        network=network,
    )
    # Accept either Ok (role revoked) or Err (role not found)
    assert response in [
        '(variant { Ok = "Admin role revoked for principal: aaaaa-aa" })',
        '(variant { Err = variant { Other = "No admin role found for principal: aaaaa-aa" } })'
    ]


def test__amiController(network: str) -> None:
    """Test amiController succeeds for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="amiController",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = record { auth = "You are a controller of this canister.";} })'
    assert response == expected_response


def test__getMasterCanisterId(network: str) -> None:
    """Test getMasterCanisterId succeeds for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMasterCanisterId",
        canister_argument="()",
        network=network,
    )
    # Response should start with Ok and contain the master canister id
    assert response.startswith('(variant { Ok = record { auth = "Master canister id for this canister:')


def test__setMasterCanisterId(network: str) -> None:
    """Test setMasterCanisterId succeeds for controller (set and restore)"""
    # Get current master canister ID
    get_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMasterCanisterId",
        canister_argument="()",
        network=network,
    )
    # Extract current ID from response
    import re
    match = re.search(r'Master canister id for this canister: ([a-z0-9-]+)', get_response)
    assert match, f"Could not extract master canister ID from: {get_response}"
    original_id = match.group(1)

    # Set to a test value
    set_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMasterCanisterId",
        canister_argument='("aaaaa-aa")',
        network=network,
    )
    expected_set_response = '(variant { Ok = record { auth = "You set the master canister for this canister.";} })'
    assert set_response == expected_set_response

    # Verify it was set
    verify_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMasterCanisterId",
        canister_argument="()",
        network=network,
    )
    assert 'aaaaa-aa' in verify_response

    # Restore original value
    restore_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMasterCanisterId",
        canister_argument=f'("{original_id}")',
        network=network,
    )
    assert restore_response == expected_set_response


def test__getAdminRoles_empty(network: str) -> None:
    """Test getAdminRoles returns empty list initially"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getAdminRoles",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = vec {} })'
    assert response == expected_response


def test__resetDailyMetricsAdmin(network: str) -> None:
    """Test resetDailyMetricsAdmin succeeds for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="resetDailyMetricsAdmin",
        canister_argument="()",
        network=network,
    )
    # Returns count of deleted metrics (0 if empty)
    expected_response = '(variant { Ok = 0 : nat })'
    assert response == expected_response


# =============================================================================
# Admin RBAC Management - Success Tests (controller can manage roles)
# =============================================================================

def test__assignAdminRole_AdminQuery(network: str) -> None:
    """Test assignAdminRole assigns AdminQuery role"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="assignAdminRole",
        canister_argument='(record { "principal" = "aaaaa-aa"; role = variant { AdminQuery }; note = "Test admin query role" })',
        network=network,
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
    )
    expected_response = '(variant { Err = variant { Other = "No admin role found for principal: non-existent-principal" } })'
    assert response == expected_response


# =============================================================================
# Daily Metrics CRUD - Success Tests (controller has implicit AdminUpdate)
# =============================================================================

def test__createDailyMetricAdmin(network: str) -> None:
    """Test createDailyMetricAdmin creates a metric"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="createDailyMetricAdmin",
        canister_argument='(record { date = "2025-01-15"; funnai_index = 100.5; daily_burn_rate_cycles = 1000 : nat; daily_burn_rate_usd = 0.01; total_mainers_created = 10 : nat; total_active_mainers = 5 : nat; total_paused_mainers = 5 : nat; total_cycles_all_mainers = 10000 : nat; active_low_burn_rate_mainers = 1 : nat; active_medium_burn_rate_mainers = 1 : nat; active_high_burn_rate_mainers = 1 : nat; active_very_high_burn_rate_mainers = 1 : nat; active_custom_burn_rate_mainers = 1 : nat; paused_low_burn_rate_mainers = 1 : nat; paused_medium_burn_rate_mainers = 1 : nat; paused_high_burn_rate_mainers = 1 : nat; paused_very_high_burn_rate_mainers = 1 : nat; paused_custom_burn_rate_mainers = 1 : nat })',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'date = "2025-01-15"' in response
    assert 'funnai_index = 100.5' in response


def test__createDailyMetricAdmin_invalid_date(network: str) -> None:
    """Test createDailyMetricAdmin rejects invalid date format"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="createDailyMetricAdmin",
        canister_argument='(record { date = "2025/01/15"; funnai_index = 100.0; daily_burn_rate_cycles = 1000 : nat; daily_burn_rate_usd = 0.01; total_mainers_created = 10 : nat; total_active_mainers = 5 : nat; total_paused_mainers = 5 : nat; total_cycles_all_mainers = 10000 : nat; active_low_burn_rate_mainers = 1 : nat; active_medium_burn_rate_mainers = 1 : nat; active_high_burn_rate_mainers = 1 : nat; active_very_high_burn_rate_mainers = 1 : nat; active_custom_burn_rate_mainers = 1 : nat; paused_low_burn_rate_mainers = 1 : nat; paused_medium_burn_rate_mainers = 1 : nat; paused_high_burn_rate_mainers = 1 : nat; paused_very_high_burn_rate_mainers = 1 : nat; paused_custom_burn_rate_mainers = 1 : nat })',
        network=network,
    )
    expected_response = '(variant { Err = variant { Other = "Invalid date format. Use YYYY-MM-DD" } })'
    assert response == expected_response


def test__getNumDailyMetrics_after_create(network: str) -> None:
    """Test getNumDailyMetrics returns 1 after creating a metric"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumDailyMetrics",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = 1 : nat })'
    assert response == expected_response


def test__getDailyMetricByDate_found(network: str) -> None:
    """Test getDailyMetricByDate returns the created metric"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDailyMetricByDate",
        canister_argument='("2025-01-15")',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'date = "2025-01-15"' in response


def test__getLatestDailyMetric(network: str) -> None:
    """Test getLatestDailyMetric returns the created metric"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getLatestDailyMetric",
        canister_argument="()",
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'date = "2025-01-15"' in response


def test__getDailyMetrics_with_data(network: str) -> None:
    """Test getDailyMetrics returns the created metric"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDailyMetrics",
        canister_argument="(null)",
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'total_days = 1' in response


def test__getDailyMetricsAdmin(network: str) -> None:
    """Test getDailyMetricsAdmin returns metrics for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDailyMetricsAdmin",
        canister_argument="()",
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'total_days = 1' in response


def test__updateDailyMetricAdmin(network: str) -> None:
    """Test updateDailyMetricAdmin updates an existing metric"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="updateDailyMetricAdmin",
        canister_argument='(record { date = "2025-01-15"; input = record { funnai_index = opt 150.5 } })',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'funnai_index = 150.5' in response


def test__updateDailyMetricAdmin_not_found(network: str) -> None:
    """Test updateDailyMetricAdmin returns error for non-existent date"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="updateDailyMetricAdmin",
        canister_argument='(record { date = "2025-12-31"; input = record { funnai_index = opt 150.0 } })',
        network=network,
    )
    expected_response = '(variant { Err = variant { Other = "Metric for date 2025-12-31 not found" } })'
    assert response == expected_response


def test__bulkCreateDailyMetricsAdmin(network: str) -> None:
    """Test bulkCreateDailyMetricsAdmin creates multiple metrics"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="bulkCreateDailyMetricsAdmin",
        canister_argument='(vec { record { date = "2025-01-16"; funnai_index = 101.0; daily_burn_rate_cycles = 1100 : nat; daily_burn_rate_usd = 0.011; total_mainers_created = 11 : nat; total_active_mainers = 6 : nat; total_paused_mainers = 5 : nat; total_cycles_all_mainers = 11000 : nat; active_low_burn_rate_mainers = 1 : nat; active_medium_burn_rate_mainers = 1 : nat; active_high_burn_rate_mainers = 2 : nat; active_very_high_burn_rate_mainers = 1 : nat; active_custom_burn_rate_mainers = 1 : nat; paused_low_burn_rate_mainers = 1 : nat; paused_medium_burn_rate_mainers = 1 : nat; paused_high_burn_rate_mainers = 1 : nat; paused_very_high_burn_rate_mainers = 1 : nat; paused_custom_burn_rate_mainers = 1 : nat }; record { date = "2025-01-17"; funnai_index = 102.0; daily_burn_rate_cycles = 1200 : nat; daily_burn_rate_usd = 0.012; total_mainers_created = 12 : nat; total_active_mainers = 7 : nat; total_paused_mainers = 5 : nat; total_cycles_all_mainers = 12000 : nat; active_low_burn_rate_mainers = 1 : nat; active_medium_burn_rate_mainers = 2 : nat; active_high_burn_rate_mainers = 2 : nat; active_very_high_burn_rate_mainers = 1 : nat; active_custom_burn_rate_mainers = 1 : nat; paused_low_burn_rate_mainers = 1 : nat; paused_medium_burn_rate_mainers = 1 : nat; paused_high_burn_rate_mainers = 1 : nat; paused_very_high_burn_rate_mainers = 1 : nat; paused_custom_burn_rate_mainers = 1 : nat } })',
        network=network,
    )
    # Should return count of created metrics (2, since 2025-01-15 already exists)
    expected_response = '(variant { Ok = 2 : nat })'
    assert response == expected_response


def test__getNumDailyMetrics_after_bulk(network: str) -> None:
    """Test getNumDailyMetrics returns 3 after bulk create"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumDailyMetrics",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = 3 : nat })'
    assert response == expected_response


def test__getDailyMetrics_with_query_params(network: str) -> None:
    """Test getDailyMetrics with date range filter"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDailyMetrics",
        canister_argument='(opt record { start_date = opt "2025-01-15"; end_date = opt "2025-01-16"; limit = null })',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'total_days = 2' in response


def test__getDailyMetrics_with_limit(network: str) -> None:
    """Test getDailyMetrics with limit parameter"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDailyMetrics",
        canister_argument='(opt record { start_date = null; end_date = null; limit = opt 1 })',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'total_days = 1' in response


def test__deleteDailyMetricAdmin(network: str) -> None:
    """Test deleteDailyMetricAdmin deletes a metric"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="deleteDailyMetricAdmin",
        canister_argument='("2025-01-17")',
        network=network,
    )
    expected_response = '(variant { Ok = 1 : nat })'
    assert response == expected_response


def test__deleteDailyMetricAdmin_not_found(network: str) -> None:
    """Test deleteDailyMetricAdmin returns error for non-existent date"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="deleteDailyMetricAdmin",
        canister_argument='("2025-12-31")',
        network=network,
    )
    expected_response = '(variant { Err = variant { Other = "Metric for date 2025-12-31 not found" } })'
    assert response == expected_response


def test__getNumDailyMetrics_after_delete(network: str) -> None:
    """Test getNumDailyMetrics returns 2 after delete"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumDailyMetrics",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = 2 : nat })'
    assert response == expected_response


# =============================================================================
# Total Cycles Tests (new optional field)
# =============================================================================

def test__createDailyMetricAdmin_without_total_cycles(network: str) -> None:
    """Test backward compatibility: creating metric without total_cycles fields.

    The existing test__createDailyMetricAdmin already covers this, but this test
    explicitly verifies that old-style calls still work after adding the new fields.
    """
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="createDailyMetricAdmin",
        canister_argument='(record { date = "2025-02-01"; funnai_index = 0.23; daily_burn_rate_cycles = 1163 : nat; daily_burn_rate_usd = 1587.06; total_mainers_created = 742 : nat; total_active_mainers = 362 : nat; total_paused_mainers = 380 : nat; total_cycles_all_mainers = 7899 : nat; active_low_burn_rate_mainers = 131 : nat; active_medium_burn_rate_mainers = 50 : nat; active_high_burn_rate_mainers = 77 : nat; active_very_high_burn_rate_mainers = 104 : nat; active_custom_burn_rate_mainers = 0 : nat; paused_low_burn_rate_mainers = 107 : nat; paused_medium_burn_rate_mainers = 47 : nat; paused_high_burn_rate_mainers = 104 : nat; paused_very_high_burn_rate_mainers = 113 : nat; paused_custom_burn_rate_mainers = 0 : nat })',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'date = "2025-02-01"' in response
    # Verify total_cycles is null (not present or explicitly null)
    assert 'total_cycles = null' in response or 'total_cycles' not in response


def test__createDailyMetricAdmin_with_total_cycles(network: str) -> None:
    """Test new interface: creating metric with total_cycles fields (all 5 required)."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="createDailyMetricAdmin",
        canister_argument='(record { date = "2025-02-02"; funnai_index = 0.25; daily_burn_rate_cycles = 1200 : nat; daily_burn_rate_usd = 1600.0; total_mainers_created = 800 : nat; total_active_mainers = 400 : nat; total_paused_mainers = 400 : nat; total_cycles_all_mainers = 8000 : nat; active_low_burn_rate_mainers = 100 : nat; active_medium_burn_rate_mainers = 100 : nat; active_high_burn_rate_mainers = 100 : nat; active_very_high_burn_rate_mainers = 100 : nat; active_custom_burn_rate_mainers = 0 : nat; paused_low_burn_rate_mainers = 100 : nat; paused_medium_burn_rate_mainers = 100 : nat; paused_high_burn_rate_mainers = 100 : nat; paused_very_high_burn_rate_mainers = 100 : nat; paused_custom_burn_rate_mainers = 0 : nat; total_cycles_all = opt (18000 : nat); total_cycles_all_usd = opt (0.018 : float64); total_cycles_protocol = opt (10000 : nat); total_cycles_protocol_usd = opt (0.01 : float64); total_cycles_mainers_usd = opt (0.008 : float64) })',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'date = "2025-02-02"' in response
    # Verify total_cycles is present with CycleAmount structure (cycles and usd)
    assert 'total_cycles = opt record' in response
    assert 'cycles = 18_000' in response  # all.cycles
    assert 'cycles = 10_000' in response  # protocol.cycles
    assert 'cycles = 8_000' in response   # mainers.cycles


def test__getLatestDailyMetric_with_total_cycles(network: str) -> None:
    """Test getLatestDailyMetric returns total_cycles when present."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getLatestDailyMetric",
        canister_argument="()",
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    # Latest metric should be 2025-02-02 which has total_cycles
    assert 'date = "2025-02-02"' in response
    assert 'total_cycles = opt record' in response


def test__getDailyMetricByDate_with_total_cycles(network: str) -> None:
    """Test getDailyMetricByDate returns total_cycles when present."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDailyMetricByDate",
        canister_argument='("2025-02-02")',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'total_cycles = opt record' in response
    assert 'cycles = 18_000' in response  # all.cycles


def test__getDailyMetricByDate_without_total_cycles(network: str) -> None:
    """Test getDailyMetricByDate returns null total_cycles for old records."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDailyMetricByDate",
        canister_argument='("2025-02-01")',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    # Old record should have null total_cycles
    assert 'total_cycles = null' in response


def test__getDailyMetrics_mixed_total_cycles(network: str) -> None:
    """Test getDailyMetrics returns both records with and without total_cycles."""
    # Query with explicit date range to get both 2025-02-01 and 2025-02-02
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDailyMetrics",
        canister_argument='(opt record { start_date = opt "2025-02-01"; end_date = opt "2025-02-02"; limit = null })',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    # Should have records with both null and present total_cycles
    assert 'total_cycles = null' in response
    assert 'total_cycles = opt record' in response


def test__updateDailyMetricAdmin_add_total_cycles(network: str) -> None:
    """Test updating an existing metric to add total_cycles (all 5 fields required)."""
    # Update the 2025-02-01 record (which has null total_cycles) to add total_cycles
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="updateDailyMetricAdmin",
        canister_argument='(record { date = "2025-02-01"; input = record { total_cycles_all = opt (20000 : nat); total_cycles_all_usd = opt (0.02 : float64); total_cycles_protocol = opt (12101 : nat); total_cycles_protocol_usd = opt (0.012101 : float64); total_cycles_mainers_usd = opt (0.007899 : float64) } })',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    # Verify total_cycles was added with CycleAmount structure
    assert 'total_cycles = opt record' in response
    assert 'cycles = 20_000' in response  # all.cycles
    assert 'cycles = 12_101' in response  # protocol.cycles
    # mainers.cycles should be 7899 (from original total_cycles_all_mainers)
    assert 'cycles = 7_899' in response


def test__updateDailyMetricAdmin_update_total_cycles(network: str) -> None:
    """Test updating an existing metric's total_cycles values (partial update merges with existing)."""
    # Update the 2025-02-02 record to change only total_cycles_all
    # The merge logic should preserve existing USD values from the record
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="updateDailyMetricAdmin",
        canister_argument='(record { date = "2025-02-02"; input = record { total_cycles_all = opt (25000 : nat) } })',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    # Verify total_cycles is still present (merged with existing values)
    assert 'total_cycles = opt record' in response
    # all.cycles should be updated to 25000
    assert 'cycles = 25_000' in response
    # protocol.cycles should be unchanged at 10000
    assert 'cycles = 10_000' in response


def test__cleanup_total_cycles_tests(network: str) -> None:
    """Cleanup: Delete the test metrics created for total_cycles tests."""
    # Delete 2025-02-01
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="deleteDailyMetricAdmin",
        canister_argument='("2025-02-01")',
        network=network,
    )
    assert response == '(variant { Ok = 1 : nat })'

    # Delete 2025-02-02
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="deleteDailyMetricAdmin",
        canister_argument='("2025-02-02")',
        network=network,
    )
    assert response == '(variant { Ok = 1 : nat })'


# =============================================================================
# Cleanup - Reset for next test run
# =============================================================================

def test__cleanup_resetDailyMetricsAdmin(network: str) -> None:
    """Cleanup: Reset daily metrics for next test run"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="resetDailyMetricsAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = 2 : nat })'
    assert response == expected_response


def test__cleanup_verify_empty(network: str) -> None:
    """Cleanup: Verify metrics are reset"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumDailyMetrics",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = 0 : nat })'
    assert response == expected_response


# =============================================================================
# Activity Feed Public Endpoints
# =============================================================================

def test__getActivityFeed_empty(network: str) -> None:
    """Test getActivityFeed returns empty cache initially"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getActivityFeed",
        canister_argument='(record { winnersLimit = null; winnersOffset = null; challengesLimit = null; challengesOffset = null; sinceTimestamp = null })',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'winners = vec {}' in response
    assert 'challenges = vec {}' in response
    assert 'totalWinners = 0' in response
    assert 'totalChallenges = 0' in response


def test__getActivityFeed_with_pagination(network: str) -> None:
    """Test getActivityFeed with pagination parameters"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getActivityFeed",
        canister_argument='(record { winnersLimit = opt 10; winnersOffset = opt 0; challengesLimit = opt 5; challengesOffset = opt 0; sinceTimestamp = null })',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'winners = vec {}' in response
    assert 'challenges = vec {}' in response


def test__getActivityFeed_with_timestamp_filter(network: str) -> None:
    """Test getActivityFeed with sinceTimestamp filter"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getActivityFeed",
        canister_argument='(record { winnersLimit = opt 20; winnersOffset = opt 0; challengesLimit = opt 20; challengesOffset = opt 0; sinceTimestamp = opt (1700000000000000000 : nat64) })',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')


def test__getOpenChallengesFromCache_empty(network: str) -> None:
    """Test getOpenChallengesFromCache returns empty initially"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getOpenChallengesFromCache",
        canister_argument='()',
        network=network,
    )
    expected_response = '(variant { Ok = vec {} })'
    assert response == expected_response


def test__getActivityFeedCacheStatus(network: str) -> None:
    """Test getActivityFeedCacheStatus returns cache metadata"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getActivityFeedCacheStatus",
        canister_argument='()',
        network=network,
    )
    assert response.startswith('(variant { Ok = record {')
    assert 'lastSyncTimestamp = 0' in response
    assert 'cachedWinnersCount = 0' in response
    assert 'cachedChallengesCount = 0' in response
    assert 'syncIntervalSeconds = 300' in response


# =============================================================================
# Activity Feed Admin Endpoints - Anonymous Access Denial Tests
# =============================================================================

def test__getActivityFeedSyncIntervalAdmin_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test getActivityFeedSyncIntervalAdmin rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getActivityFeedSyncIntervalAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__setActivityFeedSyncIntervalAdmin_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test setActivityFeedSyncIntervalAdmin rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setActivityFeedSyncIntervalAdmin",
        canister_argument="(120 : nat)",
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__startActivityFeedTimerAdmin_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test startActivityFeedTimerAdmin rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="startActivityFeedTimerAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


def test__stopActivityFeedTimerAdmin_anonymous(identity_anonymous: Dict[str, str], network: str) -> None:
    """Test stopActivityFeedTimerAdmin rejects anonymous caller"""
    assert identity_anonymous["identity"] == "anonymous"

    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="stopActivityFeedTimerAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Err = variant { Unauthorized } })'
    assert response == expected_response


# =============================================================================
# Activity Feed Admin Endpoints - Success Tests (controller)
# =============================================================================

def test__getActivityFeedSyncIntervalAdmin(network: str) -> None:
    """Test getActivityFeedSyncIntervalAdmin returns current interval"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getActivityFeedSyncIntervalAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = 300 : nat })'
    assert response == expected_response


def test__stopActivityFeedTimerAdmin_no_active(network: str) -> None:
    """Test stopActivityFeedTimerAdmin when no timer is active"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="stopActivityFeedTimerAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = '(variant { Ok = record { auth = "No active activity feed sync timer.";} })'
    assert response == expected_response


# =============================================================================
# On-Chain Daily Metrics — Date Formatter
# =============================================================================

def test__previewIsoDateAdmin_unix_epoch(network: str) -> None:
    """Util.toIsoDate(0) returns 1970-01-01"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="previewIsoDateAdmin",
        canister_argument="(0 : int)",
        network=network,
    )
    assert response == '(variant { Ok = "1970-01-01" })'


def test__previewIsoDateAdmin_known_date(network: str) -> None:
    """2024-02-29 (leap day) at midnight UTC = 1709164800 sec = 1709164800000000000 ns"""
    nanos = 1709164800 * 1_000_000_000
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="previewIsoDateAdmin",
        canister_argument=f"({nanos} : int)",
        network=network,
    )
    assert response == '(variant { Ok = "2024-02-29" })'


def test__previewIsoDateAdmin_anonymous_rejected(identity_anonymous: Dict[str, str], network: str) -> None:
    """previewIsoDateAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="previewIsoDateAdmin",
        canister_argument="(0 : int)",
        network=network,
    )
    assert response == '(variant { Err = variant { Unauthorized } })'


# =============================================================================
# On-Chain Daily Metrics — Float parser (parseFloat)
#
# Commented out — the previewParseFloatAdmin endpoint is also commented out in
# Main.mo to avoid leaving a debug-only endpoint in production. Re-enable both
# together for local debugging when an upstream API changes its number format.
# =============================================================================

# def _parse_float_ok(network: str, candid_input: str) -> float:
#     """Call previewParseFloatAdmin with a Text argument and assert Ok, return the value."""
#     response = call_canister_api(
#         dfx_json_path=DFX_JSON_PATH,
#         canister_name=CANISTER_NAME,
#         canister_method="previewParseFloatAdmin",
#         canister_argument=f'("{candid_input}")',
#         network=network,
#     )
#     assert 'variant { Ok' in response, response
#     return _extract_float(response, 'Ok')
#
#
# def test__previewParseFloatAdmin_plain_decimal(network: str) -> None:
#     """Plain decimal '42.5' parses to 42.5"""
#     assert abs(_parse_float_ok(network, "42.5") - 42.5) < 1e-9
#
#
# def test__previewParseFloatAdmin_negative_decimal(network: str) -> None:
#     """'-3.14' parses to -3.14"""
#     assert abs(_parse_float_ok(network, "-3.14") - (-3.14)) < 1e-9
#
#
# def test__previewParseFloatAdmin_integer(network: str) -> None:
#     """'100' parses to 100.0"""
#     assert abs(_parse_float_ok(network, "100") - 100.0) < 1e-9
#
#
# def test__previewParseFloatAdmin_exponent_lowercase(network: str) -> None:
#     """'1.5e3' parses to 1500.0"""
#     assert abs(_parse_float_ok(network, "1.5e3") - 1500.0) < 1e-6
#
#
# def test__previewParseFloatAdmin_exponent_uppercase_plus(network: str) -> None:
#     """'5E+5' parses to 500000.0"""
#     assert abs(_parse_float_ok(network, "5E+5") - 500000.0) < 1e-3
#
#
# def test__previewParseFloatAdmin_exponent_negative(network: str) -> None:
#     """'2.0e-2' parses to 0.02"""
#     assert abs(_parse_float_ok(network, "2.0e-2") - 0.02) < 1e-9
#
#
# def test__previewParseFloatAdmin_integer_with_exponent(network: str) -> None:
#     """'7e2' parses to 700.0 (no decimal point before exponent)"""
#     assert abs(_parse_float_ok(network, "7e2") - 700.0) < 1e-9
#
#
# def test__previewParseFloatAdmin_invalid_letters(network: str) -> None:
#     """'abc' is not a number → Err"""
#     response = call_canister_api(
#         dfx_json_path=DFX_JSON_PATH,
#         canister_name=CANISTER_NAME,
#         canister_method="previewParseFloatAdmin",
#         canister_argument='("abc")',
#         network=network,
#     )
#     assert 'variant { Err' in response
#     assert "could not parse 'abc'" in response
#
#
# def test__previewParseFloatAdmin_invalid_double_dot(network: str) -> None:
#     """'1.2.3' has two dots → Err"""
#     response = call_canister_api(
#         dfx_json_path=DFX_JSON_PATH,
#         canister_name=CANISTER_NAME,
#         canister_method="previewParseFloatAdmin",
#         canister_argument='("1.2.3")',
#         network=network,
#     )
#     assert 'variant { Err' in response
#
#
# def test__previewParseFloatAdmin_invalid_empty_exponent(network: str) -> None:
#     """'1e' has 'e' but no exponent digits → Err"""
#     response = call_canister_api(
#         dfx_json_path=DFX_JSON_PATH,
#         canister_name=CANISTER_NAME,
#         canister_method="previewParseFloatAdmin",
#         canister_argument='("1e")',
#         network=network,
#     )
#     assert 'variant { Err' in response
#
#
# def test__previewParseFloatAdmin_invalid_empty(network: str) -> None:
#     """Empty string has no digits → Err"""
#     response = call_canister_api(
#         dfx_json_path=DFX_JSON_PATH,
#         canister_name=CANISTER_NAME,
#         canister_method="previewParseFloatAdmin",
#         canister_argument='("")',
#         network=network,
#     )
#     assert 'variant { Err' in response
#
#
# def test__previewParseFloatAdmin_anonymous_rejected(identity_anonymous: Dict[str, str], network: str) -> None:
#     """previewParseFloatAdmin rejects anonymous callers"""
#     response = call_canister_api(
#         dfx_json_path=DFX_JSON_PATH,
#         canister_name=CANISTER_NAME,
#         canister_method="previewParseFloatAdmin",
#         canister_argument='("1.0")',
#         network=network,
#     )
#     assert response == '(variant { Err = variant { Unauthorized } })'


# =============================================================================
# On-Chain Daily Metrics — ShareService canister ID + tier constants
# =============================================================================

def test__getShareServiceCanisterIdAdmin_default(network: str) -> None:
    """Default points at prd ShareService (rilmv-...)"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getShareServiceCanisterIdAdmin",
        canister_argument="()",
        network=network,
    )
    assert 'rilmv-caaaa-aaaaa-qandq-cai' in response
    assert 'variant { Ok' in response


def test__setShareServiceCanisterIdAdmin(network: str) -> None:
    """Setter accepts a new canister id, echoes it back, and getter reflects it"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setShareServiceCanisterIdAdmin",
        canister_argument='("aaaaa-aa")',
        network=network,
    )
    assert response == (
        '(variant { Ok = record { '
        'auth = "You set the ShareService canister id for this canister to: aaaaa-aa";'
        '} })'
    )

    # Verify the getter reflects the new value
    get_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getShareServiceCanisterIdAdmin",
        canister_argument="()",
        network=network,
    )
    assert 'aaaaa-aa' in get_response
    assert 'variant { Ok' in get_response

    # Reset to default so later tests are unaffected
    call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setShareServiceCanisterIdAdmin",
        canister_argument='("rilmv-caaaa-aaaaa-qandq-cai")',
        network=network,
    )


# =============================================================================
# On-Chain Daily Metrics — Pricing cache
# =============================================================================

def test__getPricingCacheAdmin_returns_defaults(network: str) -> None:
    """A freshly-deployed canister is seeded with usdPerComputedXdr=1.5 and
    icApiTcycleBurnRatePerDay=42.5. After a live refresh these values are
    replaced by Coinbase/IC-API outputs, so accept either the defaults or a
    populated cache (just verify Ok and the field names are present)."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPricingCacheAdmin",
        canister_argument="()",
        network=network,
    )
    assert 'variant { Ok' in response, response
    assert 'usdPerComputedXdr' in response
    assert 'icApiTcycleBurnRatePerDay' in response


def test__pricing_auto_fill_in_createDailyMetricAdmin(network: str) -> None:
    """When pricing cache is populated and input has zero pricing, the stored
    metric has computed funnai_index and daily_burn_rate_usd."""
    # Cache is seeded at deploy time with (1.5, 42.5).
    # daily_burn_rate_cycles = 10 trillion → expected USD = 10 * 1.5 = 15.0,
    # expected funnai_index = 0.9 * 10 / 42.5 = 0.2117...
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="createDailyMetricAdmin",
        canister_argument=(
            '(record { '
            'date = "2030-01-15"; '
            'funnai_index = 0.0 : float64; '
            'daily_burn_rate_cycles = 10 : nat; '
            'daily_burn_rate_usd = 0.0 : float64; '
            'total_mainers_created = 0 : nat; '
            'total_active_mainers = 0 : nat; '
            'total_paused_mainers = 0 : nat; '
            'total_cycles_all_mainers = 100 : nat; '
            'active_low_burn_rate_mainers = 0 : nat; '
            'active_medium_burn_rate_mainers = 0 : nat; '
            'active_high_burn_rate_mainers = 0 : nat; '
            'active_very_high_burn_rate_mainers = 0 : nat; '
            'active_custom_burn_rate_mainers = 0 : nat; '
            'paused_low_burn_rate_mainers = 0 : nat; '
            'paused_medium_burn_rate_mainers = 0 : nat; '
            'paused_high_burn_rate_mainers = 0 : nat; '
            'paused_very_high_burn_rate_mainers = 0 : nat; '
            'paused_custom_burn_rate_mainers = 0 : nat; '
            'total_cycles_all = null; '
            'total_cycles_all_usd = null; '
            'total_cycles_protocol = null; '
            'total_cycles_protocol_usd = null; '
            'total_cycles_mainers_usd = null; '
            '})'
        ),
        network=network,
    )
    # USD = 10 * 1.5 = 15.0
    assert 'usd = 15' in response
    # funnai_index ≈ 0.9 * 10 / 42.5 ≈ 0.2117647...
    assert 'funnai_index = 0.21' in response

    # Cleanup
    call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="deleteDailyMetricAdmin",
        canister_argument='("2030-01-15")',
        network=network,
    )


# =============================================================================
# On-Chain Daily Metrics — Live HTTPS outcalls (Coinbase + IC API + CMC)
# =============================================================================

def _extract_float(candid_text: str, field_name: str) -> float:
    """Pull a Float64 value out of a candid Ok-record response."""
    # Match e.g. `field_name = 12.34 : float64` (allow scientific notation, negatives).
    import re
    match = re.search(rf'{field_name}\s*=\s*([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)\s*:\s*float64', candid_text)
    assert match, f"Could not find {field_name} in: {candid_text}"
    return float(match.group(1))


@pytest.mark.live_http
def test__pricing_timer_live_outcalls(network: str) -> None:
    """End-to-end HTTPS outcall test driven via the pricing timer:
      - startPricingTimerAdmin fires refreshPricingCache once immediately (and
        only returns after that await resolves), which exercises the full path:
          * CMC.get_icp_xdr_conversion_rate (inter-canister call)
          * HTTPS-outcall https://api.coinbase.com/v2/exchange-rates?currency=ICP
          * HTTPS-outcall https://ic-api.internetcomputer.org/api/v3/metrics/cycle-burn-rate
      - getPricingCacheAdmin then verifies the cache is populated.
    Requires internet access and a replica that supports outcalls (pocket-ic in
    dfx >= 0.20). On local replicas without `dfx nns install` the CMC call fails
    and the canister's seeded xdrPermyriadPerIcp default carries forward.
    """
    start_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="startPricingTimerAdmin",
        canister_argument="()",
        network=network,
    )
    assert start_response == '(variant { Ok = record { auth = "Pricing refresh timer started.";} })', (
        f"startPricingTimerAdmin failed.\nResponse was: {start_response}"
    )

    cache_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPricingCacheAdmin",
        canister_argument="()",
        network=network,
    )
    assert 'variant { Ok' in cache_response, cache_response

    usd_per_xdr = _extract_float(cache_response, 'usdPerComputedXdr')
    burn_rate = _extract_float(cache_response, 'icApiTcycleBurnRatePerDay')

    # Sanity bounds — wide because `dfx nns install` seeds CMC with a placeholder
    # xdr_permyriad_per_icp (1_000_000 ≈ 100 XDR/ICP, vs ~3 XDR/ICP on mainnet),
    # which inflates cycles_per_icp and squashes usdPerComputedXdr roughly 30x.
    # On prd the expected value is in the 0.5–5.0 USD range.
    assert 0.0 < usd_per_xdr <= 10.0, (
        f"usdPerComputedXdr={usd_per_xdr} is outside the (0, 10.0] sanity window"
    )
    assert burn_rate > 0.0, f"icApiTcycleBurnRatePerDay={burn_rate} should be positive"
    assert burn_rate < 1_000_000_000.0, (
        f"icApiTcycleBurnRatePerDay={burn_rate} is implausibly large"
    )

    # Cleanup so the recurring hourly timer doesn't keep firing.
    call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="stopPricingTimerAdmin",
        canister_argument="()",
        network=network,
    )


# =============================================================================
# On-Chain Daily Metrics — ShareService snapshot pull
# =============================================================================

def test__pullShareServiceSnapshotAdmin_unreachable_in_local(network: str) -> None:
    """In local network the prd ShareService isn't reachable — call should
    return Err Other rather than trap."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="pullShareServiceSnapshotAdmin",
        canister_argument="()",
        network=network,
    )
    # Either #Err (most likely) or #Ok with empty registry if a local
    # canister happens to be registered at the default id. Both are valid;
    # what matters is no trap.
    assert ('variant { Err' in response) or ('variant { Ok' in response)


def test__getDailyMetricsRunStatusAdmin_initial(network: str) -> None:
    """Run-status starts with no successful date and timer inactive"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDailyMetricsRunStatusAdmin",
        canister_argument="()",
        network=network,
    )
    assert 'variant { Ok' in response
    assert 'timerActive = false' in response
