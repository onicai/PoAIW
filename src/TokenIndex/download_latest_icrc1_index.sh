#!/bin/bash

# Download the latest ICRC-1 Index canister wasm and did files

RELEASE_TAG="ledger-suite-icrc-2025-01-07"
BASE_URL="https://github.com/dfinity/ic/releases/download/${RELEASE_TAG}"

echo "Downloading ICRC-1 Index canister files from release: ${RELEASE_TAG}"

# Download wasm file
echo "Downloading ic-icrc1-index-ng.wasm.gz..."
curl -L "${BASE_URL}/ic-icrc1-index-ng.wasm.gz" -o ic-icrc1-index-ng.wasm.gz

# Download candid file
echo "Downloading index-ng.did..."
curl -L "${BASE_URL}/index-ng.did" -o index-ng.did

# Verify downloads
if [ -f "ic-icrc1-index-ng.wasm.gz" ] && [ -f "index-ng.did" ]; then
    echo "✓ Successfully downloaded ICRC-1 Index canister files"
    echo "  - ic-icrc1-index-ng.wasm.gz"
    echo "  - index-ng.did"
else
    echo "✗ Error: Failed to download one or more files"
    exit 1
fi

# Optional: Decompress wasm
echo "Decompressing wasm file..."
gunzip -k ic-icrc1-index-ng.wasm.gz
echo "✓ Created ic-icrc1-index-ng.wasm"

echo "Done!"