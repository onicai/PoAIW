#!/bin/bash
set -euo pipefail

# One source (src/Main.mo) serves TWO deployment roles:
#   - the ShareService canister  (mainer_service_canister in dfx.json)
#   - every ShareAgent mAIner    (mainer_ctrlb_canister_N in dfx.json)
#
# So the artifact is named after the SOURCE, not either role. Naming it
# mainer_service_canister.wasm implied it was only the ShareService's wasm, which
# is how ShareAgents ended up being built by a different, non-reproducible path.
#
# CANISTER_NAME is the dfx.json entry to build (any of the 745 would give the same
# wasm; the ShareService entry is used because it is the stable, non-indexed one).
# WASM_NAME is what we call the resulting artifact.
CANISTER_NAME=mainer_service_canister
WASM_NAME=mainer_canister

# --network is required by dfx build but does not impact the wasm output.
# The wasm binary is identical regardless of network.
NETWORK=prd
OUT_DIR=out
DFX_DIR=.dfx/${NETWORK}/canisters/${CANISTER_NAME}

mkdir -p ${OUT_DIR}
echo "Building ${CANISTER_NAME} with dfx, as ${WASM_NAME}..."
dfx build ${CANISTER_NAME} --network ${NETWORK}

# Copy everything, then re-name the two artifacts we hand onward.
cp -r ${DFX_DIR}/* ${OUT_DIR}/
mv ${OUT_DIR}/${CANISTER_NAME}.wasm ${OUT_DIR}/${WASM_NAME}.wasm
mv ${OUT_DIR}/${CANISTER_NAME}.did  ${OUT_DIR}/${WASM_NAME}.did

echo "Wasm hash:"
sha256sum ${OUT_DIR}/${WASM_NAME}.wasm
