ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/Challenger/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/Challenger

# Copy project files
COPY Challenger/mops.toml ./
COPY Challenger/dfx.json ./
COPY Challenger/canister_ids.json ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY Challenger/src /app/Challenger/src/
COPY common /app/common/

# Copy scripts
COPY Challenger/scripts /app/Challenger/scripts/

CMD ["/bin/bash"]
