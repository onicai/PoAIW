ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/Challenger/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/Challenger

# Copy project files
# mops.lock pins the exact dependency versions, so it is part of the reproducible build.
# canister_ids.json is deliberately NOT copied: building a wasm needs no canister ids.
COPY Challenger/mops.toml ./
COPY Challenger/mops.lock ./
COPY Challenger/icp.yaml ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY Challenger/src /app/Challenger/src/
COPY common /app/common/

# Copy scripts
COPY Challenger/scripts /app/Challenger/scripts/

CMD ["/bin/bash"]
