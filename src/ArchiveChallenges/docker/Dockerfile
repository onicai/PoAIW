ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/ArchiveChallenges/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/ArchiveChallenges

# mops.lock pins the exact dependency versions, so it is part of the reproducible
# build. canister_ids.json is NOT copied: building a wasm needs no canister ids.
COPY ArchiveChallenges/mops.toml ./
COPY ArchiveChallenges/mops.lock ./
COPY ArchiveChallenges/icp.yaml ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY ArchiveChallenges/src /app/ArchiveChallenges/src/
COPY common /app/common/

# Copy scripts
COPY ArchiveChallenges/scripts /app/ArchiveChallenges/scripts/

CMD ["/bin/bash"]
