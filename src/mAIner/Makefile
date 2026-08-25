SHELL := /bin/bash

# Disable built-in rules and variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

# The dfx.json entry to build. One source serves both the ShareService and every
# ShareAgent, so the ARTIFACT is named after the source (WASM_NAME) while
# CANISTER_NAME stays the dfx entry used to build and to resolve canister ids.
CANISTER_NAME  = mainer_service_canister
WASM_NAME      = mainer_canister

# Which canister `docker-verify-wasm` compares the build against. Defaults to the
# ShareService. Override to verify any ShareAgent against the same build, e.g.
#   make docker-verify-wasm VERIFY_NETWORK=prd VERIFY_CANISTER=2fzyu-lyaaa-aaaaa-qhmka-cai
VERIFY_CANISTER ?= $(CANISTER_NAME)
NETWORKS       = prd testing development demo
VERIFY_NETWORK ?= prd

###########################################################################
# Help
#
.PHONY: help
help:
	@echo "Makefile targets:"
	@echo "  smoketest               - Run all smoke tests (share-agent and share-service)"
	@echo "  smoketest-share-agent   - Start dfx, deploy mainer_ctrlb_canister_0, and run smoke tests"
	@echo "  smoketest-share-service - Start dfx, deploy mainer_service_canister, and run smoke tests"
	@echo "  build-wasm              - builds wasm using dfx and prints wasm-hash"
	@echo "  docker-build-base       - builds the Docker base image with dfx, mops"
	@echo "  docker-build-wasm       - builds wasm using Docker (reproducible build)"
	@echo "  docker-verify-wasm      - verifies Docker-built wasm matches deployed canister"
	@echo "  help                    - Show this help message"

###########################################################################
# Smoke tests
#
.PHONY: smoketest
smoketest:
	dfx stop
	dfx start --clean --background
	$(MAKE) docker-build-wasm
	dfx canister create mainer_ctrlb_canister_0
	dfx canister install --wasm out/$(WASM_NAME).wasm \
		--mode install mainer_ctrlb_canister_0
	dfx canister create $(CANISTER_NAME)
	dfx canister install --wasm out/$(WASM_NAME).wasm \
		--mode install $(CANISTER_NAME)
	pytest -vv --exitfirst test/test_mainer_ctrlb_canister_0.py
	pytest -vv --exitfirst test/test_mainer_service_canister.py
	dfx stop

.PHONY: smoketest-share-agent
smoketest-share-agent:
	dfx stop
	dfx start --clean --background
	$(MAKE) docker-build-wasm
	dfx canister create mainer_ctrlb_canister_0
	dfx canister install --wasm out/$(WASM_NAME).wasm \
		--mode install mainer_ctrlb_canister_0
	pytest -vv --exitfirst test/test_mainer_ctrlb_canister_0.py
	dfx stop

.PHONY: smoketest-share-service
smoketest-share-service:
	dfx stop
	dfx start --clean --background
	$(MAKE) docker-build-wasm
	dfx canister create $(CANISTER_NAME)
	dfx canister install --wasm out/$(WASM_NAME).wasm \
		--mode install $(CANISTER_NAME)
	pytest -vv --exitfirst test/test_mainer_service_canister.py
	dfx stop

###########################################################################
# Local builds
#
.PHONY: build-wasm
build-wasm:
	dfx build $(CANISTER_NAME) --network ic
	@echo "Wasm hash (SHA256):"
	@shasum -a 256 .dfx/ic/canisters/$(CANISTER_NAME)/$(CANISTER_NAME).wasm | cut -d ' ' -f 1

###########################################################################
# Docker-based reproducible builds
#
.PHONY: docker-build-base
docker-build-base:
	cd docker && docker compose build base

.PHONY: docker-build-wasm
docker-build-wasm:
	cd docker && docker compose build --no-cache wasm && docker compose run --rm wasm
	@echo "Wasm hash (Docker build):"
	@shasum -a 256 out/$(WASM_NAME).wasm | cut -d ' ' -f 1
	@for net in $(NETWORKS); do \
		mkdir -p .dfx/$$net/canisters/$(CANISTER_NAME); \
		cp -r out/* .dfx/$$net/canisters/$(CANISTER_NAME)/; \
		cp out/$(WASM_NAME).wasm .dfx/$$net/canisters/$(CANISTER_NAME)/$(CANISTER_NAME).wasm; \
		cp out/$(WASM_NAME).did  .dfx/$$net/canisters/$(CANISTER_NAME)/$(CANISTER_NAME).did; \
	done
	@echo "Copied dfx build artifacts to .dfx/{$(NETWORKS)}/canisters/$(CANISTER_NAME)/"
	@echo "  artifact  : out/$(WASM_NAME).wasm            (role-neutral, what you deploy)"
	@echo "  dfx alias : .dfx/<net>/canisters/$(CANISTER_NAME)/$(CANISTER_NAME).wasm  (so name-based dfx still works)"

.PHONY: docker-verify-wasm
docker-verify-wasm:
	@echo "Building wasm with Docker..."
	@cd docker && docker compose build --no-cache wasm && docker compose run --rm wasm
	@LOCAL_HASH=$$(shasum -a 256 out/$(WASM_NAME).wasm | cut -d ' ' -f 1); \
	echo "Docker wasm hash:   $$LOCAL_HASH"; \
	DEPLOYED_HASH=$$(dfx canister info $(VERIFY_CANISTER) --network $(VERIFY_NETWORK) | grep "Module hash:" | sed 's/Module hash: 0x//'); \
	echo "Deployed wasm hash ($(VERIFY_NETWORK)): $$DEPLOYED_HASH"; \
	if [ "$$LOCAL_HASH" = "$$DEPLOYED_HASH" ]; then \
		echo "✅ MATCH: Docker build matches deployed canister $(VERIFY_CANISTER) on $(VERIFY_NETWORK)"; \
	else \
		echo "❌ MISMATCH: Docker build does NOT match deployed canister $(VERIFY_CANISTER) on $(VERIFY_NETWORK)"; \
		exit 1; \
	fi
