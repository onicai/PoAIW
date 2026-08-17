ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/mAInerCreator/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/mAInerCreator

# mops.lock pins the exact dependency versions, so it is part of the reproducible
# build. canister_ids.json is NOT copied: building a wasm needs no canister ids.
COPY mAInerCreator/mops.toml ./
COPY mAInerCreator/mops.lock ./
COPY mAInerCreator/icp.yaml ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY mAInerCreator/src /app/mAInerCreator/src/
COPY common /app/common/

# Copy scripts
COPY mAInerCreator/scripts /app/mAInerCreator/scripts/

CMD ["/bin/bash"]
