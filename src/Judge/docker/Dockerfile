ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/Judge/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/Judge

# Copy project files
COPY Judge/mops.toml ./
COPY Judge/dfx.json ./
COPY Judge/canister_ids.json ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY Judge/src /app/Judge/src/
COPY common /app/common/

# Copy scripts
COPY Judge/scripts /app/Judge/scripts/

CMD ["/bin/bash"]
