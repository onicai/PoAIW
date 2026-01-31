ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/ArchiveChallenges/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/ArchiveChallenges

# Copy project files
COPY ArchiveChallenges/mops.toml ./
COPY ArchiveChallenges/dfx.json ./
COPY ArchiveChallenges/canister_ids.json ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY ArchiveChallenges/src /app/ArchiveChallenges/src/
COPY common /app/common/

# Copy scripts
COPY ArchiveChallenges/scripts /app/ArchiveChallenges/scripts/

CMD ["/bin/bash"]
