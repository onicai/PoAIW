ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/GameState/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/GameState

# Copy project files
COPY GameState/mops.toml ./
COPY GameState/dfx.json ./
COPY GameState/canister_ids.json ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY GameState/src /app/GameState/src/
COPY common /app/common/

# Copy scripts
COPY GameState/scripts /app/GameState/scripts/

CMD ["/bin/bash"]
