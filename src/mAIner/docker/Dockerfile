ARG IMAGE
FROM --platform=linux/amd64 ${IMAGE}

# Structure mirrors the source repo for correct imports:
# /app/mAIner/src/Main.mo
# /app/common/Types.mo
# This allows import "../../common/Types" to work correctly

WORKDIR /app/mAIner

# Copy project files
COPY mAIner/mops.toml ./
COPY mAIner/dfx.json ./
COPY mAIner/canister_ids.json ./

# Install mops dependencies
RUN mops install

# Copy source files
COPY mAIner/src /app/mAIner/src/
COPY common /app/common/

# Copy scripts
COPY mAIner/scripts /app/mAIner/scripts/

CMD ["/bin/bash"]
