ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/GameStateSidecar/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/GameStateSidecar

# Copy project files
COPY GameStateSidecar/mops.toml ./
COPY GameStateSidecar/dfx.json ./
COPY GameStateSidecar/canister_ids.json ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY GameStateSidecar/src /app/GameStateSidecar/src/
COPY common /app/common/

# Copy scripts
COPY GameStateSidecar/scripts /app/GameStateSidecar/scripts/

CMD ["/bin/bash"]
