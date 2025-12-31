"""Test mainer_service_canister endpoints

First deploy the canister:
$ dfx start --clean --background
$ dfx deploy --network local mainer_service_canister

Then run all the tests:
$ pytest -vv --exitfirst --network local test/test_mainer_service_canister.py

Or run a specific test:
$ pytest -vv --network local test/test_mainer_service_canister.py::test__health

To run it against a deployment to a network on mainnet, just replace `local` with the network in the commands above.
Example:
$ pytest -vv --network testing test/test_mainer_service_canister.py::test__health

Note: Some tests are duplicated from test_mainer_ctrlb_canister_0.py. This is intentional
to enable running a full test suite on each canister independently, allowing the canisters
to be separated out into different test runs or deployments in the future.

"""

# pylint: disable=unused-argument, missing-function-docstring, unused-import, wildcard-import, unused-wildcard-import, line-too-long, invalid-name

from pathlib import Path
from typing import Dict
import pytest
from icpp.smoketest import call_canister_api

# Path to the dfx.json file
DFX_JSON_PATH = Path(__file__).parent / "../dfx.json"

# Canister in the dfx.json file we want to test
CANISTER_NAME = "mainer_service_canister"


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
        canister_argument="(variant { ShareService })",
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
        canister_argument="(variant { ShareService })",
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
    # After previous test, type should be ShareService
    expected_response = "(variant { Ok = variant { ShareService } })"
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
# Share service canister configuration
# -----------------------------------------------------------------------------


def test__setShareServiceCanisterId_anonymous(
    identity_anonymous: dict[str, str], network: str
) -> None:
    """Test setShareServiceCanisterId rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setShareServiceCanisterId",
        canister_argument='("rrkah-fqaaa-aaaaa-aaaaq-cai")',
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setShareServiceCanisterId(network: str) -> None:
    """Test setShareServiceCanisterId with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setShareServiceCanisterId",
        canister_argument='("rrkah-fqaaa-aaaaa-aaaaq-cai")',
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


def test__getShareServiceCanisterId_anonymous(
    identity_anonymous: dict[str, str], network: str
) -> None:
    """Test getShareServiceCanisterId rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getShareServiceCanisterId",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # This endpoint returns plain Text, so error is encoded as text
    expected_response = '("#Err(#Unauthorized)")'
    assert response == expected_response


def test__getShareServiceCanisterId(network: str) -> None:
    """Test getShareServiceCanisterId with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getShareServiceCanisterId",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Returns plain Text, should be "rrkah-fqaaa-aaaaa-aaaaq-cai" from previous test
    expected_response = '("rrkah-fqaaa-aaaaa-aaaaq-cai")'
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
