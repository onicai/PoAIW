ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/Api/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/Api

# mops.lock pins the exact dependency versions, so it is part of the reproducible
# build. canister_ids.json is NOT copied: building a wasm needs no canister ids.
COPY Api/mops.toml ./
COPY Api/mops.lock ./
COPY Api/icp.yaml ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY Api/src /app/Api/src/
COPY common /app/common/

# Copy scripts
COPY Api/scripts /app/Api/scripts/

CMD ["/bin/bash"]
