ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/Treasury/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/Treasury

# mops.lock pins the exact dependency versions, so it is part of the reproducible
# build. canister_ids.json is NOT copied: building a wasm needs no canister ids.
COPY Treasury/mops.toml ./
COPY Treasury/mops.lock ./
COPY Treasury/icp.yaml ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY Treasury/src /app/Treasury/src/
COPY common /app/common/

# Copy scripts
COPY Treasury/scripts /app/Treasury/scripts/

CMD ["/bin/bash"]
