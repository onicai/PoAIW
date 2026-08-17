ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo:
# /app/ckSigner/src/Main.mo
# /app/common/Types.mo
# /app/common/ICManagementCanister.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/ckSigner

# mops.lock pins the exact dependency versions, so it is part of the reproducible
# build. canister_ids.json is NOT copied: building a wasm needs no canister ids.
COPY ckSigner/mops.toml ./
COPY ckSigner/mops.lock ./
COPY ckSigner/icp.yaml ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY ckSigner/src /app/ckSigner/src/
COPY common /app/common/
COPY ckSigner/scripts /app/ckSigner/scripts/

CMD ["/bin/bash"]
