"""Test game_state_canister endpoints

First deploy the canister:
$ dfx start --clean --background
$ dfx deploy --network local

Then run all the tests:
$ pytest -vv --exitfirst --network local test/test_game_state_canister.py

Or run a specific test:
$ pytest -vv --network local test/test_game_state_canister.py::test__health

To run it against a deployment to a network on mainnet, just replace `local` with the network in the commands above.
Example:
$ pytest -vv --network testing test/test_game_state_canister.py::test__health

This test file covers canister endpoints in the GameState canister.
Tests are organized to verify:
1. Anonymous callers are rejected for admin endpoints
2. Controller callers succeed for admin endpoints
3. Query endpoints work correctly
"""

from pathlib import Path
import pytest
from icpp.smoketest import call_canister_api

# Test configuration
TEST_TYPE = "single_canister"  # vs "full_deployment" for integration tests

# Path to dfx.json relative to this test file
DFX_JSON_PATH = Path(__file__).parent / "../dfx.json"
CANISTER_NAME = "game_state_canister"


# =============================================================================
# Health & Basic Endpoints (no auth required)
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


def test__getCanisterPrincipal(network: str) -> None:
    """Test getCanisterPrincipal endpoint."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCanisterPrincipal",
        canister_argument="()",
        network=network,
    )
    # Response should be a principal text
    assert response.startswith('("')
    assert response.endswith('")')


# =============================================================================
# Protocol Pause Flag Endpoints
# =============================================================================


def test__togglePauseProtocolFlagAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test togglePauseProtocolFlagAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="togglePauseProtocolFlagAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skip(reason="Skipping to avoid state changes during smoke tests")
def test__togglePauseProtocolFlagAdmin_as_controller(network: str) -> None:
    """Test togglePauseProtocolFlagAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="togglePauseProtocolFlagAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok" in response


def test__getPauseProtocolFlag(network: str) -> None:
    """Test getPauseProtocolFlag - should return flag status."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPauseProtocolFlag",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok = record { flag =" in response


# =============================================================================
# Cycles Transactions Admin Endpoints
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
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getCyclesTransactionsAdmin_as_controller(network: str) -> None:
    """Test getCyclesTransactionsAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCyclesTransactionsAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# Add Cycles Endpoint
# =============================================================================


def test__addCycles_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test addCycles - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addCycles",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Whitelist Phase Endpoints
# =============================================================================


def test__toggleWhitelistPhaseActiveFlagAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test toggleWhitelistPhaseActiveFlagAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleWhitelistPhaseActiveFlagAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getIsWhitelistPhaseActive(network: str) -> None:
    """Test getIsWhitelistPhaseActive - should return flag status."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getIsWhitelistPhaseActive",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok = record { flag =" in response


def test__togglePauseWhitelistMainerCreationFlagAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test togglePauseWhitelistMainerCreationFlagAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="togglePauseWhitelistMainerCreationFlagAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getPauseWhitelistMainerCreationFlag(network: str) -> None:
    """Test getPauseWhitelistMainerCreationFlag - should return flag status."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPauseWhitelistMainerCreationFlag",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok = record { flag =" in response


# =============================================================================
# Mainer Creation Limit Endpoints
# =============================================================================


def test__setLimitForCreatingMainerAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setLimitForCreatingMainerAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setLimitForCreatingMainerAdmin",
        canister_argument='(record { mainerType = variant { ShareAgent }; newLimit = 100 : nat })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getLimitForCreatingMainerAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getLimitForCreatingMainerAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getLimitForCreatingMainerAdmin",
        canister_argument='(record { mainerType = variant { ShareAgent } })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getLimitForCreatingMainerAdmin_as_controller(network: str) -> None:
    """Test getLimitForCreatingMainerAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getLimitForCreatingMainerAdmin",
        canister_argument='(record { mainerType = variant { ShareAgent } })',
        network=network,
    )
    assert "variant { Ok =" in response


def test__setBufferMainerCreation_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setBufferMainerCreation - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setBufferMainerCreation",
        canister_argument="(10 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getBufferMainerCreation_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getBufferMainerCreation - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getBufferMainerCreation",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getBufferMainerCreation_as_controller(network: str) -> None:
    """Test getBufferMainerCreation - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getBufferMainerCreation",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__shouldCreatingMainersBeStopped(network: str) -> None:
    """Test shouldCreatingMainersBeStopped - public query."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="shouldCreatingMainersBeStopped",
        canister_argument='(record { mainerType = variant { ShareAgent } })',
        network=network,
    )
    assert "variant { Ok = record { flag =" in response


# =============================================================================
# Treasury Endpoints
# =============================================================================


def test__setTreasuryCanisterId_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setTreasuryCanisterId - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setTreasuryCanisterId",
        canister_argument='("aaaaa-aa")',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getTreasuryCanisterId_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getTreasuryCanisterId - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getTreasuryCanisterId",
        canister_argument="()",
        network=network,
    )
    # Returns error as text string for anonymous caller
    assert response == '("#Err(#Unauthorized)")'


def test__getTreasuryCanisterId_as_controller(network: str) -> None:
    """Test getTreasuryCanisterId - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getTreasuryCanisterId",
        canister_argument="()",
        network=network,
    )
    assert response.startswith('("')


def test__toggleDisburseFundsToTreasuryFlagAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test toggleDisburseFundsToTreasuryFlagAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleDisburseFundsToTreasuryFlagAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getDisburseFundsToTreasuryFlag_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getDisburseFundsToTreasuryFlag - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDisburseFundsToTreasuryFlag",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getDisburseFundsToTreasuryFlag_as_controller(network: str) -> None:
    """Test getDisburseFundsToTreasuryFlag - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDisburseFundsToTreasuryFlag",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok = record { flag =" in response


def test__setMinimumIcpBalance_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setMinimumIcpBalance - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMinimumIcpBalance",
        canister_argument="(1000000000 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getMinimumIcpBalance_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getMinimumIcpBalance - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMinimumIcpBalance",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getMinimumIcpBalance_as_controller(network: str) -> None:
    """Test getMinimumIcpBalance - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMinimumIcpBalance",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# GameState Thresholds Endpoints
# =============================================================================


def test__getGameStateThresholdsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getGameStateThresholdsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getGameStateThresholdsAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getGameStateThresholdsAdmin_as_controller(network: str) -> None:
    """Test getGameStateThresholdsAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getGameStateThresholdsAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# Cycles Burn Rate Endpoints
# =============================================================================


def test__getCyclesBurnRate_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getCyclesBurnRate - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCyclesBurnRate",
        canister_argument="(variant { Low })",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getCyclesBurnRate_as_controller(network: str) -> None:
    """Test getCyclesBurnRate - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCyclesBurnRate",
        canister_argument="(variant { Low })",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# Subnets Admin Endpoints
# =============================================================================


def test__getSubnetsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getSubnetsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSubnetsAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getSubnetsAdmin_as_controller(network: str) -> None:
    """Test getSubnetsAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSubnetsAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# Price Endpoints (Public)
# =============================================================================


def test__getPriceForShareAgent(network: str) -> None:
    """Test getPriceForShareAgent - public query."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPriceForShareAgent",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getWhitelistPriceForShareAgent(network: str) -> None:
    """Test getWhitelistPriceForShareAgent - public query."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getWhitelistPriceForShareAgent",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getPriceForOwnMainer(network: str) -> None:
    """Test getPriceForOwnMainer - public query."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getPriceForOwnMainer",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getWhitelistPriceForOwnMainer(network: str) -> None:
    """Test getWhitelistPriceForOwnMainer - public query."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getWhitelistPriceForOwnMainer",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# Auction Endpoints
# =============================================================================


def test__getIsMainerAuctionActive(network: str) -> None:
    """Test getIsMainerAuctionActive - public query."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getIsMainerAuctionActive",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok = record { flag =" in response


def test__getMainerAuctionTimerInfo(network: str) -> None:
    """Test getMainerAuctionTimerInfo - public query."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainerAuctionTimerInfo",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getNextMainerAuctionPriceDropAtNs(network: str) -> None:
    """Test getNextMainerAuctionPriceDropAtNs - public query."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNextMainerAuctionPriceDropAtNs",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getAvailableMainers(network: str) -> None:
    """Test getAvailableMainers - public query."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getAvailableMainers",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# FUNNAI Cycles Endpoints
# =============================================================================


def test__getFunnaiCyclesPrice(network: str) -> None:
    """Test getFunnaiCyclesPrice - public query."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getFunnaiCyclesPrice",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getFunnaiCyclesPriceAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getFunnaiCyclesPriceAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getFunnaiCyclesPriceAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getFunnaiCyclesPriceAdmin_as_controller(network: str) -> None:
    """Test getFunnaiCyclesPriceAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getFunnaiCyclesPriceAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getMaxFunnaiTopupCyclesAmount(network: str) -> None:
    """Test getMaxFunnaiTopupCyclesAmount - public query."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMaxFunnaiTopupCyclesAmount",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getMaxFunnaiTopupCyclesAmountAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getMaxFunnaiTopupCyclesAmountAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMaxFunnaiTopupCyclesAmountAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getMaxFunnaiTopupCyclesAmountAdmin_as_controller(network: str) -> None:
    """Test getMaxFunnaiTopupCyclesAmountAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMaxFunnaiTopupCyclesAmountAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# Admin Roles Endpoints
# =============================================================================


def test__getAdminRoles_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getAdminRoles - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getAdminRoles",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getAdminRoles_as_controller(network: str) -> None:
    """Test getAdminRoles - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getAdminRoles",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# Round Robin Index Endpoints
# =============================================================================


def test__getRoundRobinTopicIndexAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getRoundRobinTopicIndexAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRoundRobinTopicIndexAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getRoundRobinTopicIndexAdmin_as_controller(network: str) -> None:
    """Test getRoundRobinTopicIndexAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRoundRobinTopicIndexAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getRoundRobinChallengeIndexAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getRoundRobinChallengeIndexAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRoundRobinChallengeIndexAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getRoundRobinChallengeIndexAdmin_as_controller(network: str) -> None:
    """Test getRoundRobinChallengeIndexAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRoundRobinChallengeIndexAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# Challenges Admin Endpoints
# =============================================================================


def test__getClosedChallengesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getClosedChallengesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getClosedChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getClosedChallengesAdmin_as_controller(network: str) -> None:
    """Test getClosedChallengesAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getClosedChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getNumClosedChallengesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getNumClosedChallengesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumClosedChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumClosedChallengesAdmin_as_controller(network: str) -> None:
    """Test getNumClosedChallengesAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumClosedChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getArchivedChallengesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getArchivedChallengesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getArchivedChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getArchivedChallengesAdmin_as_controller(network: str) -> None:
    """Test getArchivedChallengesAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getArchivedChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getNumArchivedChallengesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getNumArchivedChallengesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumArchivedChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumArchivedChallengesAdmin_as_controller(network: str) -> None:
    """Test getNumArchivedChallengesAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumArchivedChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getIsMigratingChallengesFlagAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getIsMigratingChallengesFlagAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getIsMigratingChallengesFlagAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getIsMigratingChallengesFlagAdmin_as_controller(network: str) -> None:
    """Test getIsMigratingChallengesFlagAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getIsMigratingChallengesFlagAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok = record { flag =" in response


# =============================================================================
# Current Challenges Endpoints
# =============================================================================


def test__getCurrentChallenges_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getCurrentChallenges - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCurrentChallenges",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getCurrentChallengesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getCurrentChallengesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCurrentChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getCurrentChallengesAdmin_as_controller(network: str) -> None:
    """Test getCurrentChallengesAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCurrentChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getNumCurrentChallengesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getNumCurrentChallengesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumCurrentChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumCurrentChallengesAdmin_as_controller(network: str) -> None:
    """Test getNumCurrentChallengesAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumCurrentChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# Submissions Admin Endpoints
# =============================================================================


def test__getOpenSubmissionsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getOpenSubmissionsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getOpenSubmissionsAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getOpenSubmissionsAdmin_as_controller(network: str) -> None:
    """Test getOpenSubmissionsAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getOpenSubmissionsAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getNumOpenSubmissionsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getNumOpenSubmissionsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumOpenSubmissionsAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumOpenSubmissionsAdmin_as_controller(network: str) -> None:
    """Test getNumOpenSubmissionsAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumOpenSubmissionsAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getOpenSubmissionsQueueSizeAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getOpenSubmissionsQueueSizeAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getOpenSubmissionsQueueSizeAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getOpenSubmissionsQueueSizeAdmin_as_controller(network: str) -> None:
    """Test getOpenSubmissionsQueueSizeAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getOpenSubmissionsQueueSizeAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getSubmissionsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getSubmissionsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSubmissionsAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getSubmissionsAdmin_as_controller(network: str) -> None:
    """Test getSubmissionsAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSubmissionsAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getNumSubmissionsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getNumSubmissionsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumSubmissionsAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumSubmissionsAdmin_as_controller(network: str) -> None:
    """Test getNumSubmissionsAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumSubmissionsAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getNumArchivedSubmissionsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getNumArchivedSubmissionsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumArchivedSubmissionsAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumArchivedSubmissionsAdmin_as_controller(network: str) -> None:
    """Test getNumArchivedSubmissionsAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumArchivedSubmissionsAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getNumSubmissionsToMigrateAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getNumSubmissionsToMigrateAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumSubmissionsToMigrateAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumSubmissionsToMigrateAdmin_as_controller(network: str) -> None:
    """Test getNumSubmissionsToMigrateAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumSubmissionsToMigrateAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# Scored Challenges Admin Endpoints
# =============================================================================


def test__getScoredChallengesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getScoredChallengesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getScoredChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getScoredChallengesAdmin_as_controller(network: str) -> None:
    """Test getScoredChallengesAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getScoredChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getNumScoredChallengesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getNumScoredChallengesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumScoredChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumScoredChallengesAdmin_as_controller(network: str) -> None:
    """Test getNumScoredChallengesAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumScoredChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# mAIner Agent Canister Endpoints
# =============================================================================


def test__getMainerAgentCanistersForUser_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getMainerAgentCanistersForUser - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainerAgentCanistersForUser",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getMainerAgentCanistersAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getMainerAgentCanistersAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainerAgentCanistersAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getMainerAgentCanistersAdmin_as_controller(network: str) -> None:
    """Test getMainerAgentCanistersAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainerAgentCanistersAdmin",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getMainerAgentCanisterInfo_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getMainerAgentCanisterInfo - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainerAgentCanisterInfo",
        canister_argument='(record { address = "aaaaa-aa" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Protocol Activity & Winners (Public Queries)
# =============================================================================


def test__getRecentChallengeWinners_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getRecentChallengeWinners - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRecentChallengeWinners",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getRecentProtocolActivity(network: str) -> None:
    """Test getRecentProtocolActivity - public query."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRecentProtocolActivity",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getProtocolTotalCyclesBurnt(network: str) -> None:
    """Test getProtocolTotalCyclesBurnt - public query."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getProtocolTotalCyclesBurnt",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# Official Canisters Admin Endpoint
# =============================================================================


def test__getOfficialCanistersAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getOfficialCanistersAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getOfficialCanistersAdmin",
        canister_argument="()",
        network=network,
    )
    # Returns empty vec for anonymous
    assert response == "(vec {})"


def test__getOfficialCanistersAdmin_as_controller(network: str) -> None:
    """Test getOfficialCanistersAdmin - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getOfficialCanistersAdmin",
        canister_argument="()",
        network=network,
    )
    assert response.startswith("(vec {")


# =============================================================================
# Protocol Cycles Balance Endpoints
# =============================================================================


def test__getProtocolCyclesBalanceBuffer_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getProtocolCyclesBalanceBuffer - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getProtocolCyclesBalanceBuffer",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getProtocolCyclesBalanceBuffer_as_controller(network: str) -> None:
    """Test getProtocolCyclesBalanceBuffer - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getProtocolCyclesBalanceBuffer",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


def test__getCyclesBalanceThresholdFunnaiTopups_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getCyclesBalanceThresholdFunnaiTopups - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCyclesBalanceThresholdFunnaiTopups",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getCyclesBalanceThresholdFunnaiTopups_as_controller(network: str) -> None:
    """Test getCyclesBalanceThresholdFunnaiTopups - controller should succeed."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCyclesBalanceThresholdFunnaiTopups",
        canister_argument="()",
        network=network,
    )
    assert "variant { Ok =" in response


# =============================================================================
# Mockup Endpoints (commented out in source code)
# =============================================================================
# NOTE: Mockup functions are commented out in Main.mo, so tests are disabled


# =============================================================================
# Admin Setter Endpoints
# =============================================================================


def test__setTokenLedgerCanisterId_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setTokenLedgerCanisterId - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setTokenLedgerCanisterId",
        canister_argument='("aaaaa-aa")',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setArchiveCanisterId_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setArchiveCanisterId - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setArchiveCanisterId",
        canister_argument='("aaaaa-aa")',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setApiCanisterId_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setApiCanisterId - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setApiCanisterId",
        canister_argument='("aaaaa-aa")',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setGameStateThresholdsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setGameStateThresholdsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setGameStateThresholdsAdmin",
        canister_argument='(record { thresholdArchiveClosedChallenges = 150; thresholdMaxOpenChallenges = 4; thresholdMaxOpenSubmissions = 140; thresholdScoredResponsesPerChallenge = 27 })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setCyclesBurnRateAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setCyclesBurnRateAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setCyclesBurnRateAdmin",
        canister_argument='(record { cyclesBurnRateDefault = variant { Low }; cyclesBurnRate = record { cycles = 1000000 : nat; timeInterval = variant { Daily } } })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setSubnetsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setSubnetsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setSubnetsAdmin",
        canister_argument='(record { subnetShareAgentCtrl = "test"; subnetShareServiceCtrl = "test"; subnetShareServiceLlm = "test" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setIcpForShareAgentAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setIcpForShareAgentAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setIcpForShareAgentAdmin",
        canister_argument="(10 : nat64)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setIcpForWhitelistShareAgentAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setIcpForWhitelistShareAgentAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setIcpForWhitelistShareAgentAdmin",
        canister_argument="(5 : nat64)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setIcpForOwnMainerAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setIcpForOwnMainerAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setIcpForOwnMainerAdmin",
        canister_argument="(1000 : nat64)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setIcpForWhitelistOwnMainerAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setIcpForWhitelistOwnMainerAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setIcpForWhitelistOwnMainerAdmin",
        canister_argument="(500 : nat64)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setFunnaiCyclesPrice_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setFunnaiCyclesPrice - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setFunnaiCyclesPrice",
        canister_argument="(400000000000 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setMaxFunnaiTopupCyclesAmount_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setMaxFunnaiTopupCyclesAmount - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMaxFunnaiTopupCyclesAmount",
        canister_argument="(1000000000000 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setProtocolCyclesBalanceBuffer_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setProtocolCyclesBalanceBuffer - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setProtocolCyclesBalanceBuffer",
        canister_argument="(400 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setCyclesBalanceThresholdFunnaiTopups_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setCyclesBalanceThresholdFunnaiTopups - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setCyclesBalanceThresholdFunnaiTopups",
        canister_argument="(100 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setNumSubmissionsToMigrateAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setNumSubmissionsToMigrateAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setNumSubmissionsToMigrateAdmin",
        canister_argument="(100 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setOfficialMainerAgentCanisterWasmHashAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setOfficialMainerAgentCanisterWasmHashAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setOfficialMainerAgentCanisterWasmHashAdmin",
        canister_argument='(record { wasmHash = blob "\\00\\01\\02\\03"; textNote = "test" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setRewardPerChallengeAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setRewardPerChallengeAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setRewardPerChallengeAdmin",
        canister_argument="(1000000 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Admin Role Management Endpoints
# =============================================================================


def test__assignAdminRole_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test assignAdminRole - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="assignAdminRole",
        canister_argument='(record { "principal" = "aaaaa-aa"; role = variant { AdminQuery }; note = "test" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__revokeAdminRole_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test revokeAdminRole - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="revokeAdminRole",
        canister_argument='("aaaaa-aa")',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Auction Management Endpoints
# =============================================================================


def test__setupAuctionAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setupAuctionAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setupAuctionAdmin",
        canister_argument="(vec { 100 : nat64; 90 : nat64; 80 : nat64 }, 60 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__startAuctionAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test startAuctionAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="startAuctionAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__stopAuctionAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test stopAuctionAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="stopAuctionAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setAuctionIntervalSecondsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setAuctionIntervalSecondsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setAuctionIntervalSecondsAdmin",
        canister_argument="(60 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setAuctionPricesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setAuctionPricesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setAuctionPricesAdmin",
        canister_argument="(vec { 100 : nat64; 90 : nat64; 80 : nat64 })",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Reset & Migration Endpoints
# =============================================================================


def test__resetIsMigratingChallengesFlagAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test resetIsMigratingChallengesFlagAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="resetIsMigratingChallengesFlagAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__resetRoundRobinTopicIndexAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test resetRoundRobinTopicIndexAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="resetRoundRobinTopicIndexAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__resetRoundRobinChallengeIndexAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test resetRoundRobinChallengeIndexAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="resetRoundRobinChallengeIndexAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__resetCurrentChallengesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test resetCurrentChallengesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="resetCurrentChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__resetCyclesFlowAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test resetCyclesFlowAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="resetCyclesFlowAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__migrateArchivedChallengesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test migrateArchivedChallengesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="migrateArchivedChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__migrateSubmissionsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test migrateSubmissionsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="migrateSubmissionsAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__migrateWinnerDeclarationsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test migrateWinnerDeclarationsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="migrateWinnerDeclarationsAdmin",
        canister_argument='(vec { "challenge1"; "challenge2" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__migrateScoredResponsesForChallengeAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test migrateScoredResponsesForChallengeAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="migrateScoredResponsesForChallengeAdmin",
        canister_argument='("challenge1")',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Transaction Management Endpoints
# =============================================================================


def test__getRedeemedTransactionBlockAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getRedeemedTransactionBlockAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRedeemedTransactionBlockAdmin",
        canister_argument="(record { paymentTransactionBlockId = 1 : nat64 })",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getRedeemedTransactionBlocksAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getRedeemedTransactionBlocksAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRedeemedTransactionBlocksAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__removeRedeemedTransactionBlockAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test removeRedeemedTransactionBlockAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="removeRedeemedTransactionBlockAdmin",
        canister_argument="(record { paymentTransactionBlockId = 1 : nat64 })",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getRedeemedFunnaiTransactionBlockAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getRedeemedFunnaiTransactionBlockAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRedeemedFunnaiTransactionBlockAdmin",
        canister_argument="(record { paymentTransactionBlockId = 1 : nat64 })",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getRedeemedFunnaiTransactionBlocksAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getRedeemedFunnaiTransactionBlocksAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRedeemedFunnaiTransactionBlocksAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__removeRedeemedFunnaiTransactionBlockAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test removeRedeemedFunnaiTransactionBlockAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="removeRedeemedFunnaiTransactionBlockAdmin",
        canister_argument="(record { paymentTransactionBlockId = 1 : nat64 })",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Canister Management Endpoints
# =============================================================================


def test__addOfficialCanister_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test addOfficialCanister - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addOfficialCanister",
        canister_argument='(record { address = "aaaaa-aa"; subnet = "test-subnet"; canisterType = variant { Challenger } })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getSharedServiceCanistersAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getSharedServiceCanistersAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSharedServiceCanistersAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__removeSharedServiceCanisterAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test removeSharedServiceCanisterAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="removeSharedServiceCanisterAdmin",
        canister_argument='(record { canisterId = "aaaaa-aa" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getOfficialChallengerCanisters_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getOfficialChallengerCanisters - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getOfficialChallengerCanisters",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__addMainerAgentCanisterAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test addMainerAgentCanisterAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addMainerAgentCanisterAdmin",
        canister_argument='(record { address = "aaaaa-aa"; subnet = "test-subnet"; canisterType = variant { MainerAgent = variant { ShareAgent } }; creationTimestamp = 0 : nat64; createdBy = principal "aaaaa-aa"; ownedBy = principal "aaaaa-aa"; status = variant { Unlocked }; mainerConfig = record { mainerAgentCanisterType = variant { ShareAgent }; selectedLLM = null; cyclesForMainer = 0 : nat; subnetCtrl = "test"; subnetLlm = "test" } })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getMainerAgentCanistersForUserAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getMainerAgentCanistersForUserAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainerAgentCanistersForUserAdmin",
        canister_argument='("aaaaa-aa")',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumMainerAgentCanistersForUserAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getNumMainerAgentCanistersForUserAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumMainerAgentCanistersForUserAdmin",
        canister_argument='("aaaaa-aa")',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumberMainerAgentsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getNumberMainerAgentsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumberMainerAgentsAdmin",
        canister_argument='(record { mainerType = variant { Own } })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Cycles Flow Endpoints
# =============================================================================


def test__getCyclesFlowAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getCyclesFlowAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getCyclesFlowAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setCyclesFlowAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setCyclesFlowAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setCyclesFlowAdmin",
        canister_argument="(record { cyclesCreateMainerMarginGs = opt (1000000 : nat); cyclesCreatemMainerMarginMc = null; cyclesCreateMainerLlmTargetBalance = null; costCreateMainerCtrl = null; costCreateMainerLlm = null; costCreateMcMainerCtrl = null; costCreateMcMainerLlm = null; costUpgradeMainerCtrl = null })",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getMainerCyclesUsedPerResponse_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getMainerCyclesUsedPerResponse - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainerCyclesUsedPerResponse",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getRewardPerChallengeAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getRewardPerChallengeAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRewardPerChallengeAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Additional Admin Query Endpoints
# =============================================================================


def test__getNumOpenSubmissionsForOpenChallengesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getNumOpenSubmissionsForOpenChallengesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumOpenSubmissionsForOpenChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getOpenSubmissionsForOpenChallengesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getOpenSubmissionsForOpenChallengesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getOpenSubmissionsForOpenChallengesAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Admin Maintenance Endpoints
# =============================================================================


def test__cleanUnlockedMainerStoragesAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test cleanUnlockedMainerStoragesAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="cleanUnlockedMainerStoragesAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__cleanOpenSubmissionsQueueAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test cleanOpenSubmissionsQueueAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="cleanOpenSubmissionsQueueAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__cleanSubmissionsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test cleanSubmissionsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="cleanSubmissionsAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__archiveSubmissionsAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test archiveSubmissionsAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="archiveSubmissionsAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__initializeOpenSubmissionsQueueAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test initializeOpenSubmissionsQueueAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="initializeOpenSubmissionsQueueAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__backupMainersAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test backupMainersAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="backupMainersAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Test Admin Endpoints
# =============================================================================


def test__testTokenMintingAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test testTokenMintingAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="testTokenMintingAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__testDisbursementToTreasuryAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test testDisbursementToTreasuryAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="testDisbursementToTreasuryAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__testMainerCodeIntegrityAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test testMainerCodeIntegrityAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="testMainerCodeIntegrityAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__disburseIcpToTreasuryAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test disburseIcpToTreasuryAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="disburseIcpToTreasuryAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__deriveNewMainerAgentCanisterWasmHashAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test deriveNewMainerAgentCanisterWasmHashAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="deriveNewMainerAgentCanisterWasmHashAdmin",
        canister_argument='(record { address = "aaaaa-aa"; textNote = "test" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Upload/Download Endpoints (Prompt Cache)
# =============================================================================


def test__startUploadMainerPromptCache_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test startUploadMainerPromptCache - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="startUploadMainerPromptCache",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__uploadMainerPromptCacheBytesChunk_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test uploadMainerPromptCacheBytesChunk - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="uploadMainerPromptCacheBytesChunk",
        canister_argument='(record { mainerPromptId = "test"; chunkID = 0 : nat; bytesChunk = blob "\\00\\01\\02" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__finishUploadMainerPromptCache_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test finishUploadMainerPromptCache - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="finishUploadMainerPromptCache",
        canister_argument='(record { mainerPromptId = "test"; promptText = "test prompt"; promptCacheSha256 = "abc123"; promptCacheFilename = "test.bin" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getMainerPromptInfo_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getMainerPromptInfo - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainerPromptInfo",
        canister_argument='("test")',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__downloadMainerPromptCacheBytesChunk_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test downloadMainerPromptCacheBytesChunk - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="downloadMainerPromptCacheBytesChunk",
        canister_argument='(record { mainerPromptId = "test"; chunkID = 0 : nat })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__startUploadJudgePromptCache_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test startUploadJudgePromptCache - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="startUploadJudgePromptCache",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__uploadJudgePromptCacheBytesChunk_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test uploadJudgePromptCacheBytesChunk - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="uploadJudgePromptCacheBytesChunk",
        canister_argument='(record { judgePromptId = "test"; chunkID = 0 : nat; bytesChunk = blob "\\00\\01\\02" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__finishUploadJudgePromptCache_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test finishUploadJudgePromptCache - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="finishUploadJudgePromptCache",
        canister_argument='(record { judgePromptId = "test"; promptText = "test prompt"; promptCacheSha256 = "abc123"; promptCacheFilename = "test.bin" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getJudgePromptInfo_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getJudgePromptInfo - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getJudgePromptInfo",
        canister_argument='("test")',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__downloadJudgePromptCacheBytesChunk_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test downloadJudgePromptCacheBytesChunk - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="downloadJudgePromptCacheBytesChunk",
        canister_argument='(record { judgePromptId = "test"; chunkID = 0 : nat })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Challenge Management Endpoints
# =============================================================================


def test__setInitialChallengeTopics_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setInitialChallengeTopics - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setInitialChallengeTopics",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__addChallengeTopic_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test addChallengeTopic - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addChallengeTopic",
        canister_argument='(record { challengeTopic = "Test Topic"; challengePrompt = "Test prompt" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getRandomOpenChallengeTopicAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getRandomOpenChallengeTopicAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRandomOpenChallengeTopicAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getRandomOpenChallengeAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getRandomOpenChallengeAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRandomOpenChallengeAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# =============================================================================
# Complex Operations - Multi-Canister (skipped for single_canister tests)
# =============================================================================


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__addChallenge_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test addChallenge - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addChallenge",
        canister_argument='(record { challengeTopic = "test"; challengeTopicId = "1"; challengePrompt = "test"; mainerPromptId = "1"; judgePromptId = "1" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__getRandomOpenChallengeTopic_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getRandomOpenChallengeTopic - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRandomOpenChallengeTopic",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__getRandomOpenChallenge_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getRandomOpenChallenge - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getRandomOpenChallenge",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__addMainerAgentCanister_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test addMainerAgentCanister - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addMainerAgentCanister",
        canister_argument='(record { address = "aaaaa-aa"; mainerType = variant { Own }; llmCanisterId = null; status = variant { Registered }; owner = principal "aaaaa-aa"; creationTimestamp = 0 : nat64; lockedForUserPrincipal = null })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__unlockUserMainerAgent_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test unlockUserMainerAgent - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="unlockUserMainerAgent",
        canister_argument='(record { mainerType = variant { Own }; transactionBlock = 1 : nat64 })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__createUserMainerAgent_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test createUserMainerAgent - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="createUserMainerAgent",
        canister_argument='(record { mainerType = variant { Own }; transactionBlock = 1 : nat64 })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__whitelistCreateUserMainerAgent_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test whitelistCreateUserMainerAgent - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="whitelistCreateUserMainerAgent",
        canister_argument='(record { mainerType = variant { Own }; transactionBlock = 1 : nat64; whitelistCode = "test" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__spinUpMainerControllerCanister_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test spinUpMainerControllerCanister - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="spinUpMainerControllerCanister",
        canister_argument='(record { address = "aaaaa-aa"; mainerType = variant { Own }; llmCanisterId = null; status = variant { Registered }; owner = principal "aaaaa-aa"; creationTimestamp = 0 : nat64; lockedForUserPrincipal = null })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__spinUpMainerControllerCanisterForUserAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test spinUpMainerControllerCanisterForUserAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="spinUpMainerControllerCanisterForUserAdmin",
        canister_argument='(record { address = "aaaaa-aa"; mainerType = variant { Own }; llmCanisterId = null; status = variant { Registered }; owner = principal "aaaaa-aa"; creationTimestamp = 0 : nat64; lockedForUserPrincipal = null })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__completeMainerSetupForUserAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test completeMainerSetupForUserAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="completeMainerSetupForUserAdmin",
        canister_argument='(record { address = "aaaaa-aa"; mainerType = variant { Own }; llmCanisterId = null; status = variant { Registered }; owner = principal "aaaaa-aa"; creationTimestamp = 0 : nat64; lockedForUserPrincipal = null })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__setUpMainerLlmCanister_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setUpMainerLlmCanister - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setUpMainerLlmCanister",
        canister_argument='(record { address = "aaaaa-aa"; mainerType = variant { Own }; llmCanisterId = null; status = variant { Registered }; owner = principal "aaaaa-aa"; creationTimestamp = 0 : nat64; lockedForUserPrincipal = null })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__addLlmCanisterToMainer_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test addLlmCanisterToMainer - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addLlmCanisterToMainer",
        canister_argument='(record { address = "aaaaa-aa"; mainerType = variant { Own }; llmCanisterId = null; status = variant { Registered }; owner = principal "aaaaa-aa"; creationTimestamp = 0 : nat64; lockedForUserPrincipal = null })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__upgradeMainerControllerAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test upgradeMainerControllerAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="upgradeMainerControllerAdmin",
        canister_argument='(record { mainerctrlCanisterId = "aaaaa-aa" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__reinstallMainerControllerAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test reinstallMainerControllerAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="reinstallMainerControllerAdmin",
        canister_argument='(record { mainerctrlCanisterId = "aaaaa-aa" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__topUpCyclesForMainerAgent_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test topUpCyclesForMainerAgent - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="topUpCyclesForMainerAgent",
        canister_argument='(record { mainerctrlCanisterId = "aaaaa-aa"; transactionBlock = 1 : nat64 })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__completeTopUpCyclesForMainerAgentAdmin_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test completeTopUpCyclesForMainerAgentAdmin - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="completeTopUpCyclesForMainerAgentAdmin",
        canister_argument='(record { mainerctrlCanisterId = "aaaaa-aa"; transactionBlock = 1 : nat64 })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__topUpCyclesForMainerAgentWithFunnai_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test topUpCyclesForMainerAgentWithFunnai - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="topUpCyclesForMainerAgentWithFunnai",
        canister_argument='(record { mainerctrlCanisterId = "aaaaa-aa"; transactionBlock = 1 : nat64 })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__submitChallengeResponse_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test submitChallengeResponse - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="submitChallengeResponse",
        canister_argument='(record { challengeId = "test"; response = "test response"; mainerAgentCanisterId = "aaaaa-aa" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__getNextSubmissionToJudge_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getNextSubmissionToJudge - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNextSubmissionToJudge",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(TEST_TYPE == "single_canister", reason="Requires multi-canister setup")
def test__addScoredResponse_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test addScoredResponse - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addScoredResponse",
        canister_argument='(record { challengeId = "test"; submissionId = "test"; score = 80; judgeCanisterId = "aaaaa-aa" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getScoreForSubmission_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getScoreForSubmission - anonymous caller should be rejected."""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getScoreForSubmission",
        canister_argument='(record { challengeId = "test"; submissionId = "test" })',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response
