ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo:
# /app/ckSigner/src/Main.mo
# /app/common/Types.mo
# /app/common/ICManagementCanister.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/ckSigner

# Copy project files
COPY ckSigner/mops.toml ./
COPY ckSigner/dfx.json ./
COPY ckSigner/canister_ids.json ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY ckSigner/src /app/ckSigner/src/
COPY common /app/common/
COPY ckSigner/scripts /app/ckSigner/scripts/

CMD ["/bin/bash"]
