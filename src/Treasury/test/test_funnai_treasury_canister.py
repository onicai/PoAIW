"""Test funnai_treasury_canister endpoints

First deploy the canister:
$ dfx start --clean --background
$ dfx deploy --network local

Then run all the tests:
$ pytest -vv --exitfirst --network local test/test_funnai_treasury_canister.py

Or run a specific test:
$ pytest -vv --network local test/test_funnai_treasury_canister.py::test__health

To run it against a deployment to a network on mainnet, just replace `local` with the network in the commands above.
Example:
$ pytest -vv --network testing test/test_funnai_treasury_canister.py::test__health

"""

from pathlib import Path
import pytest
from icpp.smoketest import call_canister_api

DFX_JSON_PATH = Path(__file__).parent / "../dfx.json"
CANISTER_NAME = "funnai_treasury_canister"

# Test type: "single_canister" or "full_deployment"
# single_canister: Tests that only involve this canister
# full_deployment: Tests that require inter-canister calls
TEST_TYPE = "single_canister"


# ---------------------------------------------------------------------------
# health endpoint - no authentication required
# ---------------------------------------------------------------------------
def test__health(network: str, principal: str) -> None:
    """Test health endpoint returns Ok with status_code 200"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="health",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


def test__health_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test health endpoint works for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="health",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Ok = record { status_code = 200 : nat16;} })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# whoami endpoint - no authentication required
# ---------------------------------------------------------------------------
def test__whoami(network: str, principal: str) -> None:
    """Test whoami endpoint returns the caller's principal"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="whoami",
        canister_argument="()",
        network=network,
    )
    expected_response = f'(principal "{principal}")'
    assert response == expected_response


def test__whoami_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test whoami endpoint returns anonymous principal for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="whoami",
        canister_argument="()",
        network=network,
    )
    expected_response = f'(principal "{identity_anonymous["principal"]}")'
    assert response == expected_response


# ---------------------------------------------------------------------------
# amiController endpoint - controller only
# ---------------------------------------------------------------------------
def test__amiController(network: str, principal: str) -> None:
    """Test amiController returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="amiController",
        canister_argument="()",
        network=network,
    )
    expected_response = (
        '(variant { Ok = record { auth = "You are a controller of this canister.";} })'
    )
    assert response == expected_response


def test__amiController_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test amiController returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="amiController",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# setMasterCanisterId / getMasterCanisterId - controller only
# ---------------------------------------------------------------------------
def test__getMasterCanisterId(network: str, principal: str) -> None:
    """Test getMasterCanisterId returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMasterCanisterId",
        canister_argument="()",
        network=network,
    )
    # Response contains the master canister ID
    assert response.startswith("(variant { Ok = record { auth = ")
    assert "Master canister id:" in response


def test__getMasterCanisterId_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getMasterCanisterId returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMasterCanisterId",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setMasterCanisterId(network: str, principal: str) -> None:
    """Test setMasterCanisterId returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMasterCanisterId",
        canister_argument='("r5m5y-diaaa-aaaaa-qanaa-cai")',
        network=network,
    )
    expected_response = (
        '(variant { Ok = record { auth = "You set the master canister for this canister.";} })'
    )
    assert response == expected_response


def test__setMasterCanisterId_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setMasterCanisterId returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMasterCanisterId",
        canister_argument='("r5m5y-diaaa-aaaaa-qanaa-cai")',
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# toggleConvertIcpToFunnaiFlagAdmin / getConvertIcpToFunnaiFlag - controller only
# ---------------------------------------------------------------------------
def test__getConvertIcpToFunnaiFlag(network: str, principal: str) -> None:
    """Test getConvertIcpToFunnaiFlag returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getConvertIcpToFunnaiFlag",
        canister_argument="()",
        network=network,
    )
    # Response contains the flag value
    assert response.startswith("(variant { Ok = record { flag = ")


def test__getConvertIcpToFunnaiFlag_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test getConvertIcpToFunnaiFlag returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getConvertIcpToFunnaiFlag",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__toggleConvertIcpToFunnaiFlagAdmin(network: str, principal: str) -> None:
    """Test toggleConvertIcpToFunnaiFlagAdmin returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleConvertIcpToFunnaiFlagAdmin",
        canister_argument="()",
        network=network,
    )
    # Response contains the new flag value
    assert response.startswith("(variant { Ok = record { auth = ")
    assert "You set the flag to" in response


def test__toggleConvertIcpToFunnaiFlagAdmin_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test toggleConvertIcpToFunnaiFlagAdmin returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleConvertIcpToFunnaiFlagAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# setMinimumIcpBalance / getMinimumIcpBalance - controller only
# ---------------------------------------------------------------------------
def test__getMinimumIcpBalance(network: str, principal: str) -> None:
    """Test getMinimumIcpBalance returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMinimumIcpBalance",
        canister_argument="()",
        network=network,
    )
    # Response contains the balance value
    assert response.startswith("(variant { Ok = ")


def test__getMinimumIcpBalance_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test getMinimumIcpBalance returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMinimumIcpBalance",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setMinimumIcpBalance(network: str, principal: str) -> None:
    """Test setMinimumIcpBalance returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMinimumIcpBalance",
        canister_argument="(30 : nat)",
        network=network,
    )
    expected_response = '(variant { Ok = record { auth = "You set the balance.";} })'
    assert response == expected_response


def test__setMinimumIcpBalance_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test setMinimumIcpBalance returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMinimumIcpBalance",
        canister_argument="(30 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# setIcpBaseAmount / getIcpBaseAmount - controller only
# ---------------------------------------------------------------------------
def test__getIcpBaseAmount(network: str, principal: str) -> None:
    """Test getIcpBaseAmount returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getIcpBaseAmount",
        canister_argument="()",
        network=network,
    )
    # Response contains the ICP base amount
    assert response.startswith("(variant { Ok = record { auth = ")
    assert "ICP base amount:" in response


def test__getIcpBaseAmount_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getIcpBaseAmount returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getIcpBaseAmount",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setIcpBaseAmount(network: str, principal: str) -> None:
    """Test setIcpBaseAmount returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setIcpBaseAmount",
        canister_argument="(8_000_000 : nat)",
        network=network,
    )
    expected_response = (
        '(variant { Ok = record { auth = "You set the ICP base amount.";} })'
    )
    assert response == expected_response


def test__setIcpBaseAmount_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setIcpBaseAmount returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setIcpBaseAmount",
        canister_argument="(8_000_000 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# toggleDisburseFundsToDevelopersFlagAdmin / getDisburseFundsToDevelopersFlag
# ---------------------------------------------------------------------------
def test__getDisburseFundsToDevelopersFlag(network: str, principal: str) -> None:
    """Test getDisburseFundsToDevelopersFlag returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDisburseFundsToDevelopersFlag",
        canister_argument="()",
        network=network,
    )
    # Response contains the flag value
    assert response.startswith("(variant { Ok = record { flag = ")


def test__getDisburseFundsToDevelopersFlag_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test getDisburseFundsToDevelopersFlag returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDisburseFundsToDevelopersFlag",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__toggleDisburseFundsToDevelopersFlagAdmin(
    network: str, principal: str
) -> None:
    """Test toggleDisburseFundsToDevelopersFlagAdmin returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleDisburseFundsToDevelopersFlagAdmin",
        canister_argument="()",
        network=network,
    )
    # Response contains the new flag value
    assert response.startswith("(variant { Ok = record { auth = ")
    assert "You set the flag to" in response


def test__toggleDisburseFundsToDevelopersFlagAdmin_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test toggleDisburseFundsToDevelopersFlagAdmin returns Unauthorized"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleDisburseFundsToDevelopersFlagAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# toggleDisburseCyclesToDevelopersFlagAdmin / getDisburseCyclesToDevelopersFlag
# ---------------------------------------------------------------------------
def test__getDisburseCyclesToDevelopersFlag(network: str, principal: str) -> None:
    """Test getDisburseCyclesToDevelopersFlag returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDisburseCyclesToDevelopersFlag",
        canister_argument="()",
        network=network,
    )
    # Response contains the flag value
    assert response.startswith("(variant { Ok = record { flag = ")


def test__getDisburseCyclesToDevelopersFlag_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test getDisburseCyclesToDevelopersFlag returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDisburseCyclesToDevelopersFlag",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__toggleDisburseCyclesToDevelopersFlagAdmin(
    network: str, principal: str
) -> None:
    """Test toggleDisburseCyclesToDevelopersFlagAdmin returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleDisburseCyclesToDevelopersFlagAdmin",
        canister_argument="()",
        network=network,
    )
    # Response contains the new flag value
    assert response.startswith("(variant { Ok = record { auth = ")
    assert "You set the flag to" in response


def test__toggleDisburseCyclesToDevelopersFlagAdmin_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test toggleDisburseCyclesToDevelopersFlagAdmin returns Unauthorized"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleDisburseCyclesToDevelopersFlagAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# setDeveloperShareIcp / getDeveloperShareIcp - controller only
# ---------------------------------------------------------------------------
def test__getDeveloperShareIcp(network: str, principal: str) -> None:
    """Test getDeveloperShareIcp returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDeveloperShareIcp",
        canister_argument="()",
        network=network,
    )
    # Response contains the developer share
    assert response.startswith("(variant { Ok = record { auth = ")
    assert "ICP developer share:" in response


def test__getDeveloperShareIcp_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test getDeveloperShareIcp returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getDeveloperShareIcp",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setDeveloperShareIcp(network: str, principal: str) -> None:
    """Test setDeveloperShareIcp returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setDeveloperShareIcp",
        canister_argument="(1 : nat)",
        network=network,
    )
    expected_response = (
        '(variant { Ok = record { auth = "You set the ICP developer share.";} })'
    )
    assert response == expected_response


def test__setDeveloperShareIcp_too_high(network: str, principal: str) -> None:
    """Test setDeveloperShareIcp returns Unauthorized if value > 3000"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setDeveloperShareIcp",
        canister_argument="(3001 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setDeveloperShareIcp_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test setDeveloperShareIcp returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setDeveloperShareIcp",
        canister_argument="(1 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# toggleBurnIncomingFunnaiFlagAdmin / getBurnIncomingFunnaiFlag
# ---------------------------------------------------------------------------
def test__getBurnIncomingFunnaiFlag(network: str, principal: str) -> None:
    """Test getBurnIncomingFunnaiFlag returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getBurnIncomingFunnaiFlag",
        canister_argument="()",
        network=network,
    )
    # Response contains the flag value
    assert response.startswith("(variant { Ok = record { flag = ")


def test__getBurnIncomingFunnaiFlag_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test getBurnIncomingFunnaiFlag returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getBurnIncomingFunnaiFlag",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__toggleBurnIncomingFunnaiFlagAdmin(network: str, principal: str) -> None:
    """Test toggleBurnIncomingFunnaiFlagAdmin returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleBurnIncomingFunnaiFlagAdmin",
        canister_argument="()",
        network=network,
    )
    # Response contains the new flag value
    assert response.startswith("(variant { Ok = record { auth = ")
    assert "You set the flag to" in response


def test__toggleBurnIncomingFunnaiFlagAdmin_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test toggleBurnIncomingFunnaiFlagAdmin returns Unauthorized"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleBurnIncomingFunnaiFlagAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# setBurnShareFunnai / getBurnShareFunnai - controller only
# ---------------------------------------------------------------------------
def test__getBurnShareFunnai(network: str, principal: str) -> None:
    """Test getBurnShareFunnai returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getBurnShareFunnai",
        canister_argument="()",
        network=network,
    )
    # Response contains the burn share
    assert response.startswith("(variant { Ok = record { auth = ")
    assert "FUNNAI burn share:" in response


def test__getBurnShareFunnai_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test getBurnShareFunnai returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getBurnShareFunnai",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setBurnShareFunnai(network: str, principal: str) -> None:
    """Test setBurnShareFunnai returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setBurnShareFunnai",
        canister_argument="(1 : nat)",
        network=network,
    )
    expected_response = (
        '(variant { Ok = record { auth = "You set the FUNNAI burn share.";} })'
    )
    assert response == expected_response


def test__setBurnShareFunnai_too_high(network: str, principal: str) -> None:
    """Test setBurnShareFunnai returns Unauthorized if value > 10000"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setBurnShareFunnai",
        canister_argument="(10001 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setBurnShareFunnai_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test setBurnShareFunnai returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setBurnShareFunnai",
        canister_argument="(1 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# toggleLiquidityAdditionIncomingFunnaiFlagAdmin / getLiquidityAdditionIncomingFunnaiFlag
# ---------------------------------------------------------------------------
def test__getLiquidityAdditionIncomingFunnaiFlag(network: str, principal: str) -> None:
    """Test getLiquidityAdditionIncomingFunnaiFlag returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getLiquidityAdditionIncomingFunnaiFlag",
        canister_argument="()",
        network=network,
    )
    # Response contains the flag value
    assert response.startswith("(variant { Ok = record { flag = ")


def test__getLiquidityAdditionIncomingFunnaiFlag_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test getLiquidityAdditionIncomingFunnaiFlag returns Unauthorized for anonymous"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getLiquidityAdditionIncomingFunnaiFlag",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__toggleLiquidityAdditionIncomingFunnaiFlagAdmin(
    network: str, principal: str
) -> None:
    """Test toggleLiquidityAdditionIncomingFunnaiFlagAdmin returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleLiquidityAdditionIncomingFunnaiFlagAdmin",
        canister_argument="()",
        network=network,
    )
    # Response contains the new flag value
    assert response.startswith("(variant { Ok = record { auth = ")
    assert "You set the flag to" in response


def test__toggleLiquidityAdditionIncomingFunnaiFlagAdmin_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test toggleLiquidityAdditionIncomingFunnaiFlagAdmin returns Unauthorized"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleLiquidityAdditionIncomingFunnaiFlagAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# setLiquidityShareFunnai / getLiquidityShareFunnai - controller only
# ---------------------------------------------------------------------------
def test__getLiquidityShareFunnai(network: str, principal: str) -> None:
    """Test getLiquidityShareFunnai returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getLiquidityShareFunnai",
        canister_argument="()",
        network=network,
    )
    # Response contains the liquidity share
    assert response.startswith("(variant { Ok = record { auth = ")
    assert "FUNNAI liquidity share:" in response


def test__getLiquidityShareFunnai_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test getLiquidityShareFunnai returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getLiquidityShareFunnai",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setLiquidityShareFunnai(network: str, principal: str) -> None:
    """Test setLiquidityShareFunnai returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setLiquidityShareFunnai",
        canister_argument="(1 : nat)",
        network=network,
    )
    expected_response = (
        '(variant { Ok = record { auth = "You set the FUNNAI liquidity share.";} })'
    )
    assert response == expected_response


def test__setLiquidityShareFunnai_too_high(network: str, principal: str) -> None:
    """Test setLiquidityShareFunnai returns Unauthorized if value > 10000"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setLiquidityShareFunnai",
        canister_argument="(10001 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setLiquidityShareFunnai_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test setLiquidityShareFunnai returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setLiquidityShareFunnai",
        canister_argument="(1 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# toggleMatchLiquidityAdditionIcpFlagAdmin / getMatchLiquidityAdditionIcpFlag
# ---------------------------------------------------------------------------
def test__getMatchLiquidityAdditionIcpFlag(network: str, principal: str) -> None:
    """Test getMatchLiquidityAdditionIcpFlag returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMatchLiquidityAdditionIcpFlag",
        canister_argument="()",
        network=network,
    )
    # Response contains the flag value
    assert response.startswith("(variant { Ok = record { flag = ")


def test__getMatchLiquidityAdditionIcpFlag_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test getMatchLiquidityAdditionIcpFlag returns Unauthorized for anonymous"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMatchLiquidityAdditionIcpFlag",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__toggleMatchLiquidityAdditionIcpFlagAdmin(
    network: str, principal: str
) -> None:
    """Test toggleMatchLiquidityAdditionIcpFlagAdmin returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleMatchLiquidityAdditionIcpFlagAdmin",
        canister_argument="()",
        network=network,
    )
    # Response contains the new flag value
    assert response.startswith("(variant { Ok = record { auth = ")
    assert "You set the flag to" in response


def test__toggleMatchLiquidityAdditionIcpFlagAdmin_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test toggleMatchLiquidityAdditionIcpFlagAdmin returns Unauthorized"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleMatchLiquidityAdditionIcpFlagAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# setAmountFunnaiToSend / getAmountFunnaiToSend - controller only
# ---------------------------------------------------------------------------
def test__getAmountFunnaiToSend(network: str, principal: str) -> None:
    """Test getAmountFunnaiToSend returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getAmountFunnaiToSend",
        canister_argument="()",
        network=network,
    )
    # Response contains the amount
    assert response.startswith("(variant { Ok = record { auth = ")
    assert "FUNNAI to send:" in response


def test__getAmountFunnaiToSend_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test getAmountFunnaiToSend returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getAmountFunnaiToSend",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setAmountFunnaiToSend(network: str, principal: str) -> None:
    """Test setAmountFunnaiToSend returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setAmountFunnaiToSend",
        canister_argument="(7000 : nat)",
        network=network,
    )
    expected_response = (
        '(variant { Ok = record { auth = "You set the FUNNAI amount.";} })'
    )
    assert response == expected_response


def test__setAmountFunnaiToSend_too_high(network: str, principal: str) -> None:
    """Test setAmountFunnaiToSend returns Unauthorized if value > 40000"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setAmountFunnaiToSend",
        canister_argument="(40001 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setAmountFunnaiToSend_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test setAmountFunnaiToSend returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setAmountFunnaiToSend",
        canister_argument="(7000 : nat)",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# toggleSendOutFunnaiFlagAdmin / getSendOutFunnaiFlag - controller only
# ---------------------------------------------------------------------------
def test__getSendOutFunnaiFlag(network: str, principal: str) -> None:
    """Test getSendOutFunnaiFlag returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSendOutFunnaiFlag",
        canister_argument="()",
        network=network,
    )
    # Response contains the flag value
    assert response.startswith("(variant { Ok = record { flag = ")


def test__getSendOutFunnaiFlag_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test getSendOutFunnaiFlag returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSendOutFunnaiFlag",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__toggleSendOutFunnaiFlagAdmin(network: str, principal: str) -> None:
    """Test toggleSendOutFunnaiFlagAdmin returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleSendOutFunnaiFlagAdmin",
        canister_argument="()",
        network=network,
    )
    # Response contains the new flag value
    assert response.startswith("(variant { Ok = record { auth = ")
    assert "You set the flag to" in response


def test__toggleSendOutFunnaiFlagAdmin_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test toggleSendOutFunnaiFlagAdmin returns Unauthorized"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="toggleSendOutFunnaiFlagAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# getLiquidityPositionsAdmin - controller only
# ---------------------------------------------------------------------------
def test__getLiquidityPositionsAdmin(network: str, principal: str) -> None:
    """Test getLiquidityPositionsAdmin returns Ok for controller"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getLiquidityPositionsAdmin",
        canister_argument="()",
        network=network,
    )
    # Response contains the liquidity positions (may be empty)
    assert response.startswith("(variant { Ok = record { liquidityPositions = ")


def test__getLiquidityPositionsAdmin_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test getLiquidityPositionsAdmin returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getLiquidityPositionsAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


# ---------------------------------------------------------------------------
# notifyDisbursement - requires master canister (multi-canister test)
# ---------------------------------------------------------------------------
def test__notifyDisbursement_anonymous(network: str, identity_anonymous: dict) -> None:
    """Test notifyDisbursement returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="notifyDisbursement",
        canister_argument="(record { transactionId = 1 : nat64; disbursementAmount = 1000 : nat })",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__notifyDisbursement_not_master(network: str, principal: str) -> None:
    """Test notifyDisbursement returns Unauthorized for non-master canister"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="notifyDisbursement",
        canister_argument="(record { transactionId = 1 : nat64; disbursementAmount = 1000 : nat })",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(
    TEST_TYPE == "single_canister",
    reason="Requires master canister to call this endpoint",
)
def test__notifyDisbursement(network: str, principal: str) -> None:
    """Test notifyDisbursement from master canister"""
    # This test requires the master canister to call notifyDisbursement
    # Skipped in single_canister mode
    pass


# ---------------------------------------------------------------------------
# createLiquidityPositionAdmin - requires liquidity pool (multi-canister test)
# ---------------------------------------------------------------------------
def test__createLiquidityPositionAdmin_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test createLiquidityPositionAdmin returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="createLiquidityPositionAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(
    TEST_TYPE == "single_canister",
    reason="Requires liquidity pool and token ledger canisters",
)
def test__createLiquidityPositionAdmin(network: str, principal: str) -> None:
    """Test createLiquidityPositionAdmin creates a new liquidity position"""
    # This test requires the liquidity pool and token ledger canisters
    # Skipped in single_canister mode
    pass


# ---------------------------------------------------------------------------
# sendFunnaiForPoolSetupAdmin - requires token ledger (multi-canister test)
# ---------------------------------------------------------------------------
def test__sendFunnaiForPoolSetupAdmin_anonymous(
    network: str, identity_anonymous: dict
) -> None:
    """Test sendFunnaiForPoolSetupAdmin returns Unauthorized for anonymous users"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sendFunnaiForPoolSetupAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__sendFunnaiForPoolSetupAdmin_flag_disabled(
    network: str, principal: str
) -> None:
    """Test sendFunnaiForPoolSetupAdmin returns Unauthorized when flag is disabled"""
    # First ensure the flag is disabled
    # Get current state
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSendOutFunnaiFlag",
        canister_argument="()",
        network=network,
    )
    # If flag is true, toggle it to false
    if "true" in response:
        call_canister_api(
            dfx_json_path=DFX_JSON_PATH,
            canister_name=CANISTER_NAME,
            canister_method="toggleSendOutFunnaiFlagAdmin",
            canister_argument="()",
            network=network,
        )

    # Now try to send - should fail with Unauthorized because flag is disabled
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="sendFunnaiForPoolSetupAdmin",
        canister_argument="()",
        network=network,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


@pytest.mark.skipif(
    TEST_TYPE == "single_canister",
    reason="Requires token ledger canister and FUNNAI balance",
)
def test__sendFunnaiForPoolSetupAdmin(network: str, principal: str) -> None:
    """Test sendFunnaiForPoolSetupAdmin sends FUNNAI for pool setup"""
    # This test requires the token ledger canister and FUNNAI balance
    # Skipped in single_canister mode
    pass
