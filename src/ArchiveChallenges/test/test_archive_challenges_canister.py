"""Test archive_challenges_canister endpoints

First deploy the canister:
$ dfx start --clean --background
$ dfx deploy --network local archive_challenges_canister

Then run all the tests:
$ pytest -vv --exitfirst --network local test/test_archive_challenges_canister.py

Or run a specific test:
$ pytest -vv --network local test/test_archive_challenges_canister.py::test__health

To run it against a deployment to a network on mainnet, just replace `local` with the network in the commands above.
Example:
$ pytest -vv --network testing test/test_archive_challenges_canister.py::test__health

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
CANISTER_NAME = "archive_challenges_canister"


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
    expected_response = (
        '(variant { Ok = record { auth = "You are a controller of this canister.";} })'
    )
    assert response == expected_response


# -----------------------------------------------------------------------------
# Master canister configuration
# -----------------------------------------------------------------------------


def test__setMasterCanisterId_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test setMasterCanisterId rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMasterCanisterId",
        canister_argument='("aaaaa-aa")',
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__setMasterCanisterId(network: str) -> None:
    """Test setMasterCanisterId with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="setMasterCanisterId",
        canister_argument='("aaaaa-aa")',
        network=network,
        timeout_seconds=10,
    )
    expected_response = (
        '(variant { Ok = record { auth = "You set the master canister for this canister.";} })'
    )
    assert response == expected_response


def test__getMasterCanisterId_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getMasterCanisterId rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMasterCanisterId",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getMasterCanisterId(network: str) -> None:
    """Test getMasterCanisterId with controller identity"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMasterCanisterId",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    # Should contain the master canister ID we set in previous test
    assert response.startswith('(variant { Ok = record { auth = "Master canister id for this canister:')
    assert 'aaaaa-aa' in response


# -----------------------------------------------------------------------------
# Challenges archive endpoints
# -----------------------------------------------------------------------------


def test__getChallenges_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getChallenges rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getChallenges",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getChallenges(network: str) -> None:
    """Test getChallenges with controller identity returns Ok"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getChallenges",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = vec")


def test__getNumChallenges_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getNumChallenges rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumChallenges",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumChallenges(network: str) -> None:
    """Test getNumChallenges with controller identity returns Ok with nat"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumChallenges",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert "variant { Ok =" in response and ": nat" in response


def test__addChallenges_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test addChallenges rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addChallenges",
        canister_argument="(record { challenges = vec {} })",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__addChallenges(network: str) -> None:
    """Test addChallenges with controller identity succeeds with empty array"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addChallenges",
        canister_argument="(record { challenges = vec {} })",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { migrated = true;} })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# Mainers backup endpoints
# -----------------------------------------------------------------------------


def test__getMainersAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getMainersAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainersAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getMainersAdmin(network: str) -> None:
    """Test getMainersAdmin with controller identity returns Ok"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainersAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = vec")


def test__getNumMainersAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getNumMainersAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumMainersAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumMainersAdmin(network: str) -> None:
    """Test getNumMainersAdmin with controller identity returns Ok with nat"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumMainersAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert "variant { Ok =" in response and ": nat" in response


def test__addMainersAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test addMainersAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addMainersAdmin",
        canister_argument="(record { mainers = vec {} })",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__addMainersAdmin(network: str) -> None:
    """Test addMainersAdmin with controller identity succeeds with empty array"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addMainersAdmin",
        canister_argument="(record { mainers = vec {} })",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { backedUp = true;} })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# Submissions archive endpoints
# -----------------------------------------------------------------------------


def test__getSubmissionsAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getSubmissionsAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSubmissionsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getSubmissionsAdmin(network: str) -> None:
    """Test getSubmissionsAdmin with controller identity returns Ok"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getSubmissionsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = vec")


def test__getNumSubmissionsAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getNumSubmissionsAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumSubmissionsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumSubmissionsAdmin(network: str) -> None:
    """Test getNumSubmissionsAdmin with controller identity returns Ok with nat"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumSubmissionsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert "variant { Ok =" in response and ": nat" in response


def test__addSubmissions_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test addSubmissions rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addSubmissions",
        canister_argument="(record { submissions = vec {} })",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__addSubmissions(network: str) -> None:
    """Test addSubmissions with controller identity succeeds with empty array"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addSubmissions",
        canister_argument="(record { submissions = vec {} })",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { migrated = true;} })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# Winner declarations archive endpoints
# -----------------------------------------------------------------------------


def test__getWinnerDeclarationsAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getWinnerDeclarationsAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getWinnerDeclarationsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getWinnerDeclarationsAdmin(network: str) -> None:
    """Test getWinnerDeclarationsAdmin with controller identity returns Ok"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getWinnerDeclarationsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = vec")


def test__getNumWinnerDeclarationsAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getNumWinnerDeclarationsAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumWinnerDeclarationsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumWinnerDeclarationsAdmin(network: str) -> None:
    """Test getNumWinnerDeclarationsAdmin with controller identity returns Ok with nat"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumWinnerDeclarationsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert "variant { Ok =" in response and ": nat" in response


def test__addWinnerDeclarations_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test addWinnerDeclarations rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addWinnerDeclarations",
        canister_argument="(record { winnerDeclarations = vec {} })",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__addWinnerDeclarations(network: str) -> None:
    """Test addWinnerDeclarations with controller identity succeeds with empty array"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addWinnerDeclarations",
        canister_argument="(record { winnerDeclarations = vec {} })",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { migrated = true;} })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# Scored responses archive endpoints
# -----------------------------------------------------------------------------


def test__getScoredResponsesAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getScoredResponsesAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getScoredResponsesAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getScoredResponsesAdmin(network: str) -> None:
    """Test getScoredResponsesAdmin with controller identity returns Ok"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getScoredResponsesAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert response.startswith("(variant { Ok = vec")


def test__getNumScoredResponsesAdmin_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test getNumScoredResponsesAdmin rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumScoredResponsesAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__getNumScoredResponsesAdmin(network: str) -> None:
    """Test getNumScoredResponsesAdmin with controller identity returns Ok with nat"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumScoredResponsesAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert "variant { Ok =" in response and ": nat" in response


def test__addScoredResponsesForChallenge_anonymous(
    identity_anonymous: Dict[str, str], network: str
) -> None:
    """Test addScoredResponsesForChallenge rejects anonymous callers"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addScoredResponsesForChallenge",
        canister_argument="(record { scoredResponses = vec {} })",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Err = variant { Unauthorized } })"
    assert response == expected_response


def test__addScoredResponsesForChallenge(network: str) -> None:
    """Test addScoredResponsesForChallenge with controller identity succeeds with empty array"""
    response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addScoredResponsesForChallenge",
        canister_argument="(record { scoredResponses = vec {} })",
        network=network,
        timeout_seconds=10,
    )
    expected_response = "(variant { Ok = record { migrated = true;} })"
    assert response == expected_response


# -----------------------------------------------------------------------------
# CRUD Tests - Add data and verify retrieval
# -----------------------------------------------------------------------------


def extract_count_from_response(response: str) -> int:
    """Extract the count value from a response like '(variant { Ok = 0 : nat })'"""
    import re
    match = re.search(r'Ok = (\d+) : nat', response)
    if match:
        return int(match.group(1))
    raise ValueError(f"Could not extract count from response: {response}")


# Sample ChallengeParticipantEntry for reuse in tests
SAMPLE_PARTICIPANT = """record {
    submissionId = "test-sub-1";
    submittedBy = principal "aaaaa-aa";
    ownedBy = principal "aaaaa-aa";
    result = variant { Winner };
    reward = record {
        rewardType = variant { Cycles };
        amount = 1000 : nat;
        rewardDetails = "Test reward";
        distributed = false;
        distributedTimestamp = null;
    };
}"""

SAMPLE_PARTICIPANT_2 = """record {
    submissionId = "test-sub-2";
    submittedBy = principal "aaaaa-aa";
    ownedBy = principal "aaaaa-aa";
    result = variant { SecondPlace };
    reward = record {
        rewardType = variant { Cycles };
        amount = 500 : nat;
        rewardDetails = "Second place reward";
        distributed = false;
        distributedTimestamp = null;
    };
}"""

SAMPLE_PARTICIPANT_3 = """record {
    submissionId = "test-sub-3";
    submittedBy = principal "aaaaa-aa";
    ownedBy = principal "aaaaa-aa";
    result = variant { ThirdPlace };
    reward = record {
        rewardType = variant { Cycles };
        amount = 250 : nat;
        rewardDetails = "Third place reward";
        distributed = false;
        distributedTimestamp = null;
    };
}"""


def test__addWinnerDeclarations_with_data(network: str) -> None:
    """Test addWinnerDeclarations with actual data and verify count increases"""
    # First get the current count
    count_before = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumWinnerDeclarationsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )

    # Add a winner declaration
    add_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addWinnerDeclarations",
        canister_argument=f"""(record {{ winnerDeclarations = vec {{
            record {{
                challengeId = "crud-test-challenge-1";
                finalizedTimestamp = 1734567890 : nat64;
                winner = {SAMPLE_PARTICIPANT};
                secondPlace = {SAMPLE_PARTICIPANT_2};
                thirdPlace = {SAMPLE_PARTICIPANT_3};
                participants = null;
            }}
        }} }})""",
        network=network,
        timeout_seconds=10,
    )
    assert add_response == "(variant { Ok = record { migrated = true;} })"

    # Verify count increased
    count_after_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumWinnerDeclarationsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )

    # Extract the count values and compare - count_before must be lower than count_after
    count_before_val = extract_count_from_response(count_before)
    count_after_val = extract_count_from_response(count_after_response)
    assert count_before_val < count_after_val, f"Expected count to increase: {count_before_val} < {count_after_val}"

    # Verify data can be retrieved
    get_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getWinnerDeclarationsAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert "crud-test-challenge-1" in get_response
    assert "test-sub-1" in get_response


def test__addMainersAdmin_with_data(network: str) -> None:
    """Test addMainersAdmin with actual data and verify count increases"""
    # First get the current count
    count_before = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumMainersAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )

    # Add a mainer backup entry (tuple of Text and OfficialMainerAgentCanister)
    add_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addMainersAdmin",
        canister_argument="""(record { mainers = vec {
            record {
                "crud-test-mainer-id";
                record {
                    address = "crud-test-canister-addr";
                    subnet = "test-subnet";
                    canisterType = variant { MainerAgent = variant { Own } };
                    creationTimestamp = 1734567890 : nat64;
                    createdBy = principal "aaaaa-aa";
                    ownedBy = principal "aaaaa-aa";
                    status = variant { Running };
                    mainerConfig = record {
                        mainerAgentCanisterType = variant { Own };
                        selectedLLM = opt variant { Qwen2_5_500M };
                        cyclesForMainer = 1000000000 : nat;
                        subnetCtrl = "ctrl-subnet";
                        subnetLlm = "llm-subnet";
                    };
                };
            }
        } })""",
        network=network,
        timeout_seconds=10,
    )
    assert add_response == "(variant { Ok = record { backedUp = true;} })"

    # Verify count increased
    count_after_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumMainersAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )

    # Extract the count values and compare - count_before must be lower than count_after
    count_before_val = extract_count_from_response(count_before)
    count_after_val = extract_count_from_response(count_after_response)
    assert count_before_val < count_after_val, f"Expected count to increase: {count_before_val} < {count_after_val}"

    # Verify data can be retrieved
    get_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getMainersAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert "crud-test-mainer-id" in get_response
    assert "crud-test-canister-addr" in get_response


def test__addChallenges_with_data(network: str) -> None:
    """Test addChallenges with actual data and verify count increases"""
    # First get the current count
    count_before = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumChallenges",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )

    # Add a challenge with all required fields from the Challenge type
    add_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addChallenges",
        canister_argument="""(record { challenges = vec {
            record {
                challengeTopic = "Test Topic";
                challengeTopicId = "crud-test-topic-id";
                challengeTopicCreationTimestamp = 1734567880 : nat64;
                challengeTopicStatus = variant { Open };
                cyclesGenerateChallengeGsChctrl = 1000 : nat;
                cyclesGenerateChallengeChctrlChllm = 500 : nat;
                challengeQuestion = "What is the test question?";
                challengeQuestionSeed = 12345 : nat32;
                mainerPromptId = "crud-test-prompt-id";
                mainerMaxContinueLoopCount = 5 : nat;
                mainerNumTokens = 100 : nat64;
                mainerTemp = 0.7 : float64;
                judgePromptId = "crud-test-judge-prompt-id";
                challengeId = "crud-test-challenge-id";
                challengeCreationTimestamp = 1734567890 : nat64;
                challengeCreatedBy = "aaaaa-aa";
                challengeStatus = variant { Open };
                challengeClosedTimestamp = null;
                cyclesSubmitResponse = 1000 : nat;
                protocolOperationFeesCut = 100 : nat;
                cyclesGenerateResponseSactrlSsctrl = 200 : nat;
                cyclesGenerateResponseSsctrlGs = 150 : nat;
                cyclesGenerateResponseSsctrlSsllm = 300 : nat;
                cyclesGenerateResponseOwnctrlGs = 250 : nat;
                cyclesGenerateResponseOwnctrlOwnllmLOW = 400 : nat;
                cyclesGenerateResponseOwnctrlOwnllmMEDIUM = 600 : nat;
                cyclesGenerateResponseOwnctrlOwnllmHIGH = 800 : nat;
            }
        } })""",
        network=network,
        timeout_seconds=10,
    )
    assert add_response == "(variant { Ok = record { migrated = true;} })"

    # Verify count increased
    count_after_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumChallenges",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )

    # Extract the count values and compare - count_before must be lower than count_after
    count_before_val = extract_count_from_response(count_before)
    count_after_val = extract_count_from_response(count_after_response)
    assert count_before_val < count_after_val, f"Expected count to increase: {count_before_val} < {count_after_val}"

    # Verify data can be retrieved
    get_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getChallenges",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert "crud-test-challenge-id" in get_response
    assert "What is the test question?" in get_response


def test__addScoredResponsesForChallenge_with_data(network: str) -> None:
    """Test addScoredResponsesForChallenge with actual data and verify count increases"""
    # First get the current count
    count_before = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumScoredResponsesAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )

    # Add a scored response - this is a complex nested type
    # ScoredResponse = ScoredResponseInput and { judgedTimestamp }
    # ScoredResponseInput = ChallengeResponseSubmission and { judgedBy, score, scoreSeed }
    # ChallengeResponseSubmission = ChallengeResponseSubmissionInput and ChallengeResponseSubmissionMetadata
    # ChallengeResponseSubmissionInput = ChallengeQueueInput and { challengeAnswer, challengeAnswerSeed, submittedBy }
    # ChallengeQueueInput = Challenge and { challengeQueuedId, challengeQueuedBy, challengeQueuedTo, challengeQueuedTimestamp }
    add_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="addScoredResponsesForChallenge",
        canister_argument="""(record { scoredResponses = vec {
            record {
                challengeTopic = "Scored Response Test Topic";
                challengeTopicId = "crud-sr-topic-id";
                challengeTopicCreationTimestamp = 1734567880 : nat64;
                challengeTopicStatus = variant { Open };
                cyclesGenerateChallengeGsChctrl = 1000 : nat;
                cyclesGenerateChallengeChctrlChllm = 500 : nat;
                challengeQuestion = "Scored response test question?";
                challengeQuestionSeed = 12345 : nat32;
                mainerPromptId = "crud-sr-prompt-id";
                mainerMaxContinueLoopCount = 5 : nat;
                mainerNumTokens = 100 : nat64;
                mainerTemp = 0.7 : float64;
                judgePromptId = "crud-sr-judge-prompt-id";
                challengeId = "crud-sr-challenge-id";
                challengeCreationTimestamp = 1734567890 : nat64;
                challengeCreatedBy = "aaaaa-aa";
                challengeStatus = variant { Closed };
                challengeClosedTimestamp = opt (1734567900 : nat64);
                cyclesSubmitResponse = 1000 : nat;
                protocolOperationFeesCut = 100 : nat;
                cyclesGenerateResponseSactrlSsctrl = 200 : nat;
                cyclesGenerateResponseSsctrlGs = 150 : nat;
                cyclesGenerateResponseSsctrlSsllm = 300 : nat;
                cyclesGenerateResponseOwnctrlGs = 250 : nat;
                cyclesGenerateResponseOwnctrlOwnllmLOW = 400 : nat;
                cyclesGenerateResponseOwnctrlOwnllmMEDIUM = 600 : nat;
                cyclesGenerateResponseOwnctrlOwnllmHIGH = 800 : nat;
                challengeQueuedId = "crud-sr-queued-id";
                challengeQueuedBy = principal "aaaaa-aa";
                challengeQueuedTo = principal "aaaaa-aa";
                challengeQueuedTimestamp = 1734567895 : nat64;
                challengeAnswer = "This is the test answer";
                challengeAnswerSeed = 54321 : nat32;
                submittedBy = principal "aaaaa-aa";
                submissionId = "crud-sr-submission-id";
                submittedTimestamp = 1734567910 : nat64;
                submissionStatus = variant { Judged };
                cyclesGenerateScoreGsJuctrl = 500 : nat;
                cyclesGenerateScoreJuctrlJullm = 400 : nat;
                judgedBy = principal "aaaaa-aa";
                score = 85 : nat;
                scoreSeed = 99999 : nat32;
                judgedTimestamp = 1734567920 : nat64;
            }
        } })""",
        network=network,
        timeout_seconds=10,
    )
    assert add_response == "(variant { Ok = record { migrated = true;} })"

    # Verify count increased
    count_after_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getNumScoredResponsesAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )

    # Extract the count values and compare - count_before must be lower than count_after
    count_before_val = extract_count_from_response(count_before)
    count_after_val = extract_count_from_response(count_after_response)
    assert count_before_val < count_after_val, f"Expected count to increase: {count_before_val} < {count_after_val}"

    # Verify data can be retrieved
    get_response = call_canister_api(
        dfx_json_path=DFX_JSON_PATH,
        canister_name=CANISTER_NAME,
        canister_method="getScoredResponsesAdmin",
        canister_argument="()",
        network=network,
        timeout_seconds=10,
    )
    assert "crud-sr-submission-id" in get_response
    assert "This is the test answer" in get_response
