ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/mAInerCreator/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/mAInerCreator

# Copy project files
COPY mAInerCreator/mops.toml ./
COPY mAInerCreator/dfx.json ./
COPY mAInerCreator/canister_ids.json ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY mAInerCreator/src /app/mAInerCreator/src/
COPY common /app/common/

# Copy scripts
COPY mAInerCreator/scripts /app/mAInerCreator/scripts/

CMD ["/bin/bash"]
