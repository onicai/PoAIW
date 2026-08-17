ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/Judge/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/Judge

# mops.lock pins the exact dependency versions, so it is part of the reproducible
# build. canister_ids.json is NOT copied: building a wasm needs no canister ids.
COPY Judge/mops.toml ./
COPY Judge/mops.lock ./
COPY Judge/icp.yaml ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY Judge/src /app/Judge/src/
COPY common /app/common/

# Copy scripts
COPY Judge/scripts /app/Judge/scripts/

CMD ["/bin/bash"]
