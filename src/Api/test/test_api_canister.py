"""Test api_canister endpoints

First deploy the canister:
$ dfx start --clean --background
$ dfx deploy --network local

Then run all the tests:
$ pytest -vv --exitfirst --network local test/test_api_canister.py

Or run a specific test:
$ pytest -vv --network local test/test_api_canister.py::test__health

To run it against a deployment to the IC, just replace `local` with `ic` in the commands above.

"""
# pylint: disable=missing-function-docstring, unused-import, wildcard-import, unused-wildcard-import, line-too-long

from pathlib import Path
from typing import Dict
import pytest
from icpp.smoketest import call_canister_api, dict_to_candid_text

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
