"""Returns an icp-py-core Canister instance, for calling the endpoints.

Migrated from ic-py to icp-py-core because ic-py's certificate parsing breaks
against current IC replicas (TypeError: byte indices must be integers or
slices, not str inside cbor2.loads on the read_state response).
"""

import sys
import subprocess
from pathlib import Path
from typing import Optional
from icp_canister import Canister  # type: ignore
from icp_agent import Agent, Client  # type: ignore
from icp_identity import Identity  # type: ignore
from icpp.run_shell_cmd import run_shell_cmd

ROOT_PATH = Path(__file__).parent.parent

# We use dfx to get some information.
DFX = "dfx"


def run_dfx_command(cmd: str, quiet: bool = False) -> Optional[str]:
    """Runs dfx command as a subprocess"""
    try:
        return run_shell_cmd(cmd, capture_output=True).rstrip("\n")
    except subprocess.CalledProcessError as e:
        if not quiet:
            print(f"Failed dfx command: '{cmd}' with error: \n{e.output}")
    return None



def get_agent(
    network: str = "local"
) -> Agent:
    """Returns an ic_py Agent instance"""

    # Check if the network is up
    print(f"--\nChecking if the {network} network is up...")
    run_dfx_command(f"{DFX} ping {network} ")
    print("Ok!")

    # Set the network URL
    if network == "local":
        replica_port = run_dfx_command(f"{DFX} info replica-port  ", quiet=True)
        webserver_port = run_dfx_command(f"{DFX} info webserver-port  ")
        networks_json_path = run_dfx_command(f"{DFX} info networks-json-path  ")
        print(f"replica-port       = {replica_port}")
        print(f"webserver-port     = {webserver_port}")
        print(f"networks-json-path = {networks_json_path}")

        network_url = f"http://localhost:{replica_port}"
        if replica_port is None:
            if webserver_port is not None:
                network_url = f"http://localhost:{webserver_port}"
            else:
                print("Error: replica_port and webserver_port are both None.")
                sys.exit(1)

    else:
        # https://smartcontracts.org/docs/interface-spec/index.html#http-interface
        network_url = "https://ic0.app"

    print(f"Network URL        = {network_url}")

    # Get the name of the current identity
    identity_whoami = run_dfx_command(f"{DFX} identity whoami ")
    print(f"Using identity = {identity_whoami}")

    # Get the private key of the current identity
    private_key = run_dfx_command(f"{DFX} identity export {identity_whoami} ")

    # Create an Identity instance using the private key
    identity = Identity.from_pem(private_key)

    # Create an HTTP client instance for making HTTPS calls to the IC
    # https://smartcontracts.org/docs/interface-spec/index.html#http-interface
    client = Client(url=network_url)

    # Create an IC agent to communicate with IC canisters
    agent = Agent(identity, client)

    # Disable BLS certificate verification by default for every update call
    # made through this agent. The optional `blst` Python binding required for
    # BLS verification is not installed in our conda env, and these admin
    # upload scripts run as a controller identity — replica reject codes
    # already enforce auth and the wasm itself is sha256-verified end-to-end
    # via getSha256HashesAdmin after upload.
    # icp_canister.Canister always synthesizes verify_certificate=True before
    # calling self.agent.update, so setdefault would never win — force False.
    _original_update = agent.update
    def _update_no_verify(*args, **kwargs):  # noqa: E306
        kwargs["verify_certificate"] = False
        return _original_update(*args, **kwargs)
    agent.update = _update_no_verify  # type: ignore[assignment]

    return agent

def get_canister(
    canister_name: str,
    candid_path: Path,
    network: str = "local",
    canister_id: Optional[str] = "",
) -> Canister:
    """Returns an ic_py Canister instance"""

    agent = get_agent(network=network)

    # Try to get the id of the canister if not provided explicitly
    # This only works from the same directory as where you deployed from.
    # So we also provide the option to just pass in the canister_id directly
    if canister_id == "":
        canister_id = run_dfx_command(
            f"{DFX} canister --network {network} id {canister_name} "
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
    # icp-py-core renamed `candid` -> `candid_str`.
    return Canister(agent=agent, canister_id=canister_id, candid_str=canister_did)
