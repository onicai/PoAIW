"""Uploads mainer agent llm canister model file

Run with:

    python -m scripts.upload_mainer_llm_canister_modelfile.py
"""

# pylint: disable=invalid-name, too-few-public-methods, no-member, too-many-statements

import sys
import time
import asyncio
from pathlib import Path
from typing import Generator
from .calculate_sha256 import calculate_sha256
from .ic_py_canister import get_canister, get_agent, run_dfx_command
from ic.candid import Types, encode, decode
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


async def main() -> int:
    """Uploads the model file."""

    args = parse_args()

    network = args.network
    canister_name = args.canister
    canister_id = args.canister_id
    candid_path = ROOT_PATH / args.candid
    chunksize = args.chunksize
    hf_sha256 = args.hf_sha256
    wasm_path = ROOT_PATH / args.wasm

    dfx_json_path = ROOT_PATH / "dfx.json"

    if canister_id == "":
        canister_id = run_dfx_command(
            f"dfx canister --network {network} id {canister_name} "
        )

    print(
        f"Summary:"
        f"\n - network         = {network}"
        f"\n - canister        = {canister_name}"
        f"\n - canister_id     = {canister_id}"
        f"\n - dfx_json_path   = {dfx_json_path}"
        f"\n - candid_path     = {candid_path}"
        f"\n - wasm_path       = {wasm_path}",
        f"\n - chunksize       = {chunksize} ({chunksize/1024/1024:.3f} Mb)"
        f"\n - hf_sha256       = {hf_sha256}"
    )

    # ---------------------------------------------------------------------------
    # get ic-py based Canister instance
    # This is not working for the complex candid file 
    # canister_creator = get_canister(canister_name, candid_path, network, canister_id)
    agent_instance = get_agent(network)

    # 1) Prime the root key & keep the HTTP session alive
    await agent_instance.fetch_root_key()

    # ---------------------------------------------------------------------------
    print("--\nChecking the canister health")
    canister_method = "health"
    method_args = []
    method_args_encoded = encode(method_args)
    response = await agent_instance.query_raw_async(
        canister_id,
        canister_method,
        method_args_encoded
    )
    print(f"Response: {response}")
    if "Ok" in response[0].keys() or "_17724" in response[0]['value'].keys():  # pylint: disable=no-member
        print("OK!")
    else:
        print("Something went wrong:")
        print(response)
        sys.exit(1)

    # ---------------------------------------------------------------------------
    # Start the upload process -> this results in replacing an existing model file
    print("--\nCalling start_upload_mainer_llm")
    # response = canister_creator.start_upload_mainer_llm()  # pylint: disable=no-member
    canister_method = "start_upload_mainer_llm"
    method_args = []
    method_args_encoded = encode(method_args)
    response = await agent_instance.update_raw_async(
        canister_id,
        canister_method,
        method_args_encoded
    )
    print(f"Response: {response}")
    if "Ok" in response[0].keys() or "_17724" in response[0]['value'].keys():  # pylint: disable=no-member
        print("OK!")
    else:
        print("Something went wrong:")
        print(response)
        sys.exit(1)

    # ---------------------------------------------------------------------------
    # THE LLM FILE
    local_model_sha256 = calculate_sha256(wasm_path)
    local_model_filesize = wasm_path.stat().st_size

    print(f"--\nUploading the file     : {wasm_path}")
    print(f"Calculated filesize : {local_model_filesize}")
    print(f"Calculated SHA256 hash : {local_model_sha256}")
    if hf_sha256 is not None:
        if local_model_sha256 != hf_sha256:
            print(" ")
            print("ERROR - local file does not match the --hf-sha256:")
            print(f"- local_model_sha256: {local_model_sha256}")
            print(f"- hf_sha256         : {hf_sha256}")
            sys.exit(1)
        else:
            print("SHA256 of the local file is correct.")
    else:
        print(
            "You did not specify --hf-sha256, "
            "so can't check the hash against HuggingFace reference."
        )

    # Read the wasm from disk (this is actually the LLM model file...)
    print(f"--\nReading the LLM file into a bytes object: {wasm_path}")
    wasm_bytes = read_file_bytes(wasm_path)

    # Upload wasm_bytes to the canister
    print("--\nUploading the wasm bytes")

    model_variant = Types.Variant({
        "Qwen2_5_500M": Types.Null
    })
    selectedModel = { "Qwen2_5_500M": None}
    modelFileSha256 = local_model_sha256

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
        retry_delay = 4  # seconds
        for attempt in range(1, max_retries + 1):
            try:
                # Send i as the chunkId
                # response = canister_creator.upload_mainer_llm_bytes_chunk(
                #     chunk, i
                # )  # pylint: disable=no-member
                # break  # Exit the loop if the request is successful
                canister_method = "upload_mainer_llm_bytes_chunk"
                method_args = [
                    {'type': Types.Vec(Types.Nat8), 'value': chunk},
                    {'type': Types.Nat, 'value': i}
                ]
                method_args_encoded = encode(method_args)
                response = await agent_instance.update_raw_async(
                    canister_id,
                    canister_method,
                    method_args_encoded
                )
            except Exception as e:
                print(f"Attempt {attempt} failed: {e}")
                if attempt == max_retries:
                    print("Max retries reached. Failing.")
                    # Re-raise the exception if max retries are reached,
                    # which will exit the program
                    raise

                print(f"Retrying in {retry_delay} seconds...")
                await asyncio.sleep(retry_delay)  # Wait before retrying

        if "Ok" in response[0].keys() or "_17724" in response[0]['value'].keys():
            print("OK!")
        else:
            print("Something went wrong:")
            print(response)
            sys.exit(1)

    # ---------------------------------------------------------------------------
    # Store the expected sha256 hash of the model file
    # finishResponse = canister_creator.finish_upload_mainer_llm(
    #     selectedModel,
    #     modelFileSha256
    # )  # pylint: disable=no-member
    canister_method = "finish_upload_mainer_llm"
    method_args = [
        {"type":  model_variant, "value": selectedModel},
        {'type': Types.Text, 'value': modelFileSha256}
    ]
    method_args_encoded = encode(method_args)
    finishResponse = await agent_instance.update_raw_async(
        canister_id,
        canister_method,
        method_args_encoded
    )
    print(finishResponse)
    return 0


if __name__ == "__main__":
    # sys.exit(main())
    sys.exit(asyncio.run(main()))