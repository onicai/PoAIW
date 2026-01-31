ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/Treasury/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/Treasury

# Copy project files
COPY Treasury/mops.toml ./
COPY Treasury/dfx.json ./
COPY Treasury/canister_ids.json ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY Treasury/src /app/Treasury/src/
COPY common /app/common/

# Copy scripts
COPY Treasury/scripts /app/Treasury/scripts/

CMD ["/bin/bash"]
