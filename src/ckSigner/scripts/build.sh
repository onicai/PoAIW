#!/bin/bash
set -euo pipefail

CANISTER_NAME=ck_signer_canister
OUT_DIR=out

# `icp build` needs an environment to resolve the project, but the wasm it produces is
# environment-independent -- all of prd/testing/development/demo point at the same
# mainnet and none of them influences codegen. (Same reasoning as the old
# `dfx build --network prd`.)
ENVIRONMENT=prd

mkdir -p ${OUT_DIR}

echo "Building ${CANISTER_NAME} with icp-cli (@dfinity/motoko recipe -> mops build)..."
icp build ${CANISTER_NAME} -e ${ENVIRONMENT}

# icp-cli writes the finished module -- shrunk and metadata-stamped -- here. This is the
# artifact that actually gets installed, so this is the one to hash and ship.
# NOTE: it is NOT .mops/.build/<name>.wasm; that is the pre-shrink intermediate.
cp .icp/cache/artifacts/${CANISTER_NAME} ${OUT_DIR}/${CANISTER_NAME}.wasm

# The Candid interface travels inside the wasm (icp:public candid:service), but the
# standalone .did is still handy for icp-py-core callers and binding generation.
cp .mops/.build/${CANISTER_NAME}.did ${OUT_DIR}/${CANISTER_NAME}.did

echo "Wasm hash:"
sha256sum ${OUT_DIR}/${CANISTER_NAME}.wasm
