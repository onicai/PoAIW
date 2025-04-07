"""Uploads mainer agent llm canister wasm

Run with:

    python -m scripts.upload_mainer_llm_canister_wasm.py
"""

# pylint: disable=invalid-name, too-few-public-methods, no-member, too-many-statements

import sys
import time
from pathlib import Path
from typing import Generator
from .ic_py_canister import get_canister
from .parse_args_upload import parse_args

ROOT_PATH = Path(__file__).parent.parent

#  0 - none
#  1 - minimal
#  2 - a lot
DEBUG_VERBOSE = 1


# ------------------------------------------------------------------------------
def read_file_bytes(file_path: Path) -> bytes:
    """Returns the file as a bytes array"""
    file_bytes = b""
    try:
        with open(file_path, "rb") as file:
            file_bytes = file.read()

    except FileNotFoundError:
        print(f"ERROR: Unable to open the file {file_path}!")
        sys.exit(1)

    return file_bytes


def generate_chunks(data: bytes, chunk_size: int) -> Generator[bytes, None, None]:
    """Generator function to iterate over chunks"""
    for i in range(0, len(data), chunk_size):
        yield data[i : i + chunk_size]


def main() -> int:
    """Uploads the canister wasm."""

    selectedModel = { "Qwen2_5_500M": None}

    args = parse_args()

    network = args.network
    canister_name = args.canister
    canister_id = args.canister_id
    candid_path = ROOT_PATH / args.candid
    chunksize = args.chunksize
    wasm_path = ROOT_PATH / args.wasm

    dfx_json_path = ROOT_PATH / "dfx.json"

    print(
        f"Summary:"
        f"\n - network         = {network}"
        f"\n - canister        = {canister_name}"
        f"\n - canister_id     = {canister_id}"
        f"\n - dfx_json_path   = {dfx_json_path}"
        f"\n - candid_path     = {candid_path}"
        f"\n - wasm_path       = {wasm_path}",
        f"\n - chunksize       = {chunksize} ({chunksize/1024/1024:.3f} Mb)"
    )

    # ---------------------------------------------------------------------------
    # get ic-py based Canister instance
    canister_creator = get_canister(canister_name, candid_path, network, canister_id)

    # ---------------------------------------------------------------------------
    # reset existing storage, we will overwrite with new wasm file
    print("--\nResetting the canister wasm storage")
    response = canister_creator.start_upload_mainer_llm_canister_wasm(selectedModel)  # pylint: disable=no-member
    if "Ok" in response[0].keys():  # pylint: disable=no-member
        print("OK!")
    else:
        print("Something went wrong:")
        print(response)
        sys.exit(1)

    # ---------------------------------------------------------------------------
    # THE WASM FILE

    # Read the wasm from disk
    print(f"--\nReading the wasm file into a bytes object: {wasm_path}")
    wasm_bytes = read_file_bytes(wasm_path)

    # Upload wasm_bytes to the canister
    print("--\nUploading the wasm bytes")

    # Iterate over all chunks
    count_bytes = 0
    for i, chunk in enumerate(generate_chunks(wasm_bytes, chunksize)):
        count_bytes += len(chunk)
        if DEBUG_VERBOSE == 0:
            pass
        elif DEBUG_VERBOSE == 1:
            if i % 10 == 0:
                print(
                    f"chunk size = {len(chunk)} bytes "
                    f"({count_bytes / len(wasm_bytes) * 100:.1f}%)"
                )
        else:
            print("+++++++++++++++++++++++++++++++++++++++++++++++++++++")
            print(f"Sending candid for {len(chunk)} bytes :")
            print(f"- i         = {i}")
            print(f"- progress  = {count_bytes / len(wasm_bytes) * 100:.1f} % ")
            print(f"- chunk[0]  = {chunk[0]}")
            print(f"- chunk[-1] = {chunk[-1]}")

        # Handle exceptions in case the Ingress is busy and it throws this message:
        # Ingress message ... timed out waiting to start executing.

        max_retries = 10
        retry_delay = 2  # seconds
        for attempt in range(1, max_retries + 1):
            try:
                response = canister_creator.upload_mainer_llm_canister_wasm_bytes_chunk(
                    selectedModel,
                    chunk
                )  # pylint: disable=no-member
                break  # Exit the loop if the request is successful
            except Exception as e:
                print(f"Attempt {attempt} failed: {e}")
                if attempt == max_retries:
                    print("Max retries reached. Failing.")
                    # Re-raise the exception if max retries are reached,
                    # which will exit the program
                    raise

                print(f"Retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)  # Wait before retrying

        if "Ok" in response[0].keys():
            print("OK!")
        else:
            print("Something went wrong:")
            print(response)
            sys.exit(1)

    # ---------------------------------------------------------------------------
    return 0


if __name__ == "__main__":
    sys.exit(main())
