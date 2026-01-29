ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/Api/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/Api

# Copy project files
COPY Api/mops.toml ./
COPY Api/dfx.json ./
COPY Api/canister_ids.json ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY Api/src /app/Api/src/
COPY common /app/common/

# Copy scripts
COPY Api/scripts /app/Api/scripts/

CMD ["/bin/bash"]
