"""Helpers for the icp-cli end-to-end tests.

Everything here targets a LOCAL icp-cli managed network. `require_local_gateway`
is the hard guard: it refuses to proceed unless the gateway resolves to loopback,
so a misconfigured environment cannot send these tests - which move ICP - at
mainnet.
"""

import json
import subprocess
from pathlib import Path
from urllib.parse import urlparse

GAMESTATE_DIR = Path(__file__).parent.parent
CANISTER_NAME = "game_state_canister"

# Identity used by the tests. Created on demand so the harness never touches the
# developer's own identities. icp-cli's default identity is `anonymous`, which the
# canister rejects, so a named identity is required.
E2E_IDENTITY = "topup-e2e"

LOOPBACK_HOSTS = {"127.0.0.1", "localhost", "::1", "[::1]"}


def icp(*args: str, identity: str | None = None) -> str:
    """Run an `icp` command in the GameState project and return stdout."""
    cmd = ["icp", *args]
    if identity is not None:
        cmd += ["--identity", identity]
    result = subprocess.run(
        cmd, cwd=GAMESTATE_DIR, capture_output=True, text=True, check=True
    )
    return result.stdout.strip()


def gateway_url() -> str:
    """Gateway URL of the running local network.

    Read dynamically rather than hardcoded: the port is configurable and defaults
    collide between icp-cli projects.
    """
    status = json.loads(icp("network", "status", "--json"))
    # icp-cli reports it with a trailing slash ("http://127.0.0.1:8000/"), which
    # icp-py-core turns into a double slash in the request path and the replica
    # answers 400. Strip it.
    return status["gateway_url"].rstrip("/")


def require_local_gateway() -> str:
    """Return the gateway URL, refusing anything that is not loopback.

    These tests transfer ICP. Running them against a non-local network would move
    real funds, so this fails closed.
    """
    url = gateway_url()
    host = urlparse(url).hostname
    if host not in LOOPBACK_HOSTS:
        raise RuntimeError(
            f"refusing to run: gateway {url!r} is not a local replica. "
            "These tests transfer ICP and must only ever run against a local "
            "icp-cli network started with `icp network start -d`."
        )
    return url


def gamestate_canister_id() -> str:
    """Canister id of the deployed GameState on the local network.

    Parsed from `icp canister status`, which prints a `Canister Id:` line.
    `icp canister list --json` is not usable for this - it returns only names,
    as {"canisters": ["game_state_canister"]}.

    Needed because the ICP transfer must be addressed to GameState's principal.
    Method calls do not need it: icp-cli resolves the canister NAME directly.
    """
    status = icp("canister", "status", CANISTER_NAME, "-e", "local",
                 identity=E2E_IDENTITY)
    for line in status.splitlines():
        if line.startswith("Canister Id:"):
            return line.split(":", 1)[1].strip()
    raise RuntimeError(
        f"could not read the canister id for {CANISTER_NAME} from:\n{status}\n"
        "Run `make smoketest-icp`, which deploys before testing."
    )


def ensure_identity(name: str = E2E_IDENTITY) -> str:
    """Create the test identity if absent and return its principal."""
    existing = icp("identity", "list")
    if name not in existing.split():
        icp("identity", "new", name)
    return icp("identity", "principal", identity=name)


def identity_pem(name: str, dest: Path) -> Path:
    """Export the identity's PEM so icp-py-core can sign with it."""
    dest.write_text(icp("identity", "export", name))
    dest.chmod(0o600)
    return dest


def call_gamestate(method: str, argument: str, identity: str = E2E_IDENTITY) -> str:
    """Call a GameState method on the local network and return the raw Candid text.

    Addressed by canister NAME - icp-cli resolves it, so no id lookup is needed.
    Always pass the argument explicitly: `icp canister call` drops into an
    interactive prompt when one is omitted, which would hang a test run.
    """
    return icp(
        "canister",
        "call",
        CANISTER_NAME,
        method,
        argument,
        "-e",
        "local",
        identity=identity,
    )
