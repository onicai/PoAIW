"""Returns the icp-py-core Canister instance, for calling the endpoints."""

import re
import os
import json
import sys
import subprocess
from pathlib import Path
from typing import Any, List, Optional
from icp_core import Agent, Identity, Client, Canister
from icpp.run_shell_cmd import run_shell_cmd

ROOT_PATH = Path(__file__).parent.parent

# Same name icpp-pro and llama_cpp_canister use.
IDENTITY_ENV_VAR = "ICPP_PRO_TEST_IDENTITY"

# We use the `icp` CLI to look up the network URL, the active identity's key and
# canister ids. (dfx is deprecated; icp-cli is its successor.)
ICP = "icp"

# dfx 0.32.0 emits this deprecation banner on every invocation. Because
# run_shell_cmd merges stderr into stdout, the banner ends up in the
# captured output and gets glued onto things like the identity name —
# corrupting the next dfx call's arguments. Strip exactly this known line.
# Mirrors the fix in icpp-pro src/icpp/smoketest.py (commit 6f401c4).
_DFX_DEPRECATION_RE = re.compile(
    r"^WARNING: dfx is deprecated.*$\n?", flags=re.MULTILINE
)


def _strip_dfx_warnings(s: str) -> str:
    """Remove the known dfx deprecation banner from captured shell output (kept for any residual dfx call; icp emits no such banner)."""
    return _DFX_DEPRECATION_RE.sub("", s)


def extract_variant(response: List[Any]) -> Any:
    """Extract variant result from icp-py-core response.

    icp-py-core returns: [{'type': 'variant', 'value': {'Ok': {...}}}]
    old ic-py returned:  [{'Ok': {...}}]
    This helper normalizes both formats to {'Ok': {...}} or {'Err': ...}.
    """
    item = response[0]
    if "value" in item:
        return item["value"]
    return item


def run_icp_command(cmd: str, quiet: bool = False) -> Optional[str]:
    """Runs an `icp` command as a subprocess and returns its stripped stdout."""
    try:
        return _strip_dfx_warnings(run_shell_cmd(cmd, capture_output=True)).rstrip("\n")
    except subprocess.CalledProcessError as e:
        if not quiet:
            print(f"Failed icp command: '{cmd}' with error: \n{e.output}")
    return None


def get_agent(network: str = "local") -> Agent:
    """Returns an icp-py-core Agent instance"""

    # icp assigns the local network a RANDOM ephemeral port on every start
    # (gateway.port: 0), so the URL has to be read back rather than assumed.
    print(f"--\nReading the '{network}' network status...")
    status_json = run_icp_command(f"{ICP} network status -e {network} --json")
    if status_json is None:
        print(f"Error: could not get network status for environment '{network}'.")
        print("If this is the local network, start it first:  icp network start -d")
        sys.exit(1)
    # Strip the trailing slash icp reports: icp-py-core/ic-py append "/api/v3/...", and
    # "//api/v3" is rejected by the replica with a 400.
    network_url = json.loads(status_json)["api_url"].rstrip("/")

    print(f"Network URL        = {network_url}")

    # Which identity to act as. $ICPP_PRO_TEST_IDENTITY wins over the machine default, so a
    # caller can choose one WITHOUT `icp identity default <name>` -- which is global and
    # persistent. The name matches icpp-pro and llama_cpp_canister, so one variable covers
    # the pytest suites and every ic-py uploader.
    #
    # This matters because the very next line exports that identity's PRIVATE KEY. Falling
    # back to the machine default means exporting whatever the developer uses for MAINNET,
    # pulling it out of the OS keychain and through a pipe, for what is usually a throwaway
    # local upload. Point it at a local identity and the mainnet key is never read.
    identity_whoami = os.environ.get(IDENTITY_ENV_VAR, "").strip() or run_icp_command(
        f"{ICP} identity default "
    )
    print(f"Using identity = {identity_whoami}")

    # Get the private key of the current identity
    private_key = run_icp_command(f"{ICP} identity export {identity_whoami} ")

    # Create an Identity instance using the private key
    identity = Identity.from_pem(private_key)

    # Create an HTTP client instance for making HTTPS calls to the IC
    # https://smartcontracts.org/docs/interface-spec/index.html#http-interface
    client = Client(url=network_url)

    # Create an IC agent to communicate with IC canisters
    agent = Agent(identity, client)
    return agent


def get_canister(
    canister_name: str,
    candid_path: Path,
    network: str = "local",
    canister_id: Optional[str] = "",
) -> Canister:
    """Returns an icp-py-core Canister instance"""

    agent = get_agent(network=network)

    # Try to get the id of the canister if not provided explicitly
    # This only works from the same directory as where you deployed from.
    # So we also provide the option to just pass in the canister_id directly
    if canister_id == "":
        canister_id = run_icp_command(
            f"{ICP} canister status {canister_name} -e {network} --id-only "
        )
    print(f"Canister ID = {canister_id}")

    # Read canister's candid from file
    with open(
        candid_path,
        "r",
        encoding="utf-8",
    ) as f:
        canister_did = f.read()

    # Create a Canister instance
    return Canister(agent=agent, canister_id=canister_id, candid_str=canister_did)
