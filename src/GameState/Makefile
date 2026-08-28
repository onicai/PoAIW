SHELL := /bin/bash

# Disable built-in rules and variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

CANISTER_NAME  = game_state_canister
NETWORKS       = prd testing development demo
VERIFY_NETWORK ?= prd

###########################################################################
# Help
#
.PHONY: help
help:
	@echo "Makefile targets:"
	@echo "  smoketest          - Start dfx, deploy canister, and run smoke tests"
	@echo "  smoketest-icp      - Same, on an icp-cli network that HAS the ICP ledger + CMC"
	@echo "  build-wasm         - builds wasm using dfx and prints wasm-hash"
	@echo "  docker-build-base  - builds the Docker base image with dfx, mops"
	@echo "  docker-build-wasm  - builds wasm using Docker (reproducible build)"
	@echo "  docker-verify-wasm - verifies Docker-built wasm matches deployed canister"
	@echo "  help               - Show this help message"

###########################################################################
# Smoke tests
#
.PHONY: smoketest
smoketest:
	dfx stop
	dfx start --clean --background
	$(MAKE) docker-build-wasm
	dfx canister create $(CANISTER_NAME)
	dfx canister install --wasm out/$(CANISTER_NAME).wasm \
		--mode install $(CANISTER_NAME)
	pytest -vv --exitfirst test/test_game_state_canister.py
	dfx stop

# End-to-end smoke tests against a local icp-cli network.
#
# WHY THIS EXISTS ALONGSIDE `smoketest`: the dfx local network has no ICP ledger, so
# notifyMainerTopUp cannot get past its ledger read there and only its pre-await
# gates are reachable. An icp-cli managed network starts with the NNS system
# canisters installed, and the ICP ledger and CMC use the SAME ids as mainnet - the
# ids hardcoded in ../../common/Types.mo - so the real payment paths run unmodified.
#
# `smoketest` remains the authoritative target and the one CI runs. This is an
# additional local-only target; icp-cli is not used for building or for any mainnet
# network. See icp.yaml.
#
# The canister is deployed from a NAMED identity on purpose. icp-cli's default
# identity is `anonymous`, and the deploying identity becomes the controller - but
# GameState's admin methods reject anonymous callers outright, so an
# anonymous-controlled canister cannot be seeded with test mAIners.
E2E_IDENTITY = topup-e2e

.PHONY: smoketest-icp
smoketest-icp:
	$(MAKE) docker-build-wasm
	@icp identity list | grep -qx "$(E2E_IDENTITY)" || icp identity new $(E2E_IDENTITY)
	icp network start -d
	icp deploy -e local --identity $(E2E_IDENTITY)
	pytest -vv --exitfirst test_icp/ || ($(MAKE) smoketest-icp-stop && false)
	$(MAKE) smoketest-icp-stop

.PHONY: smoketest-icp-stop
smoketest-icp-stop:
	icp network stop

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
	@shasum -a 256 out/$(CANISTER_NAME).wasm | cut -d ' ' -f 1
	@for net in $(NETWORKS); do \
		mkdir -p .dfx/$$net/canisters/$(CANISTER_NAME); \
		cp -r out/* .dfx/$$net/canisters/$(CANISTER_NAME)/; \
	done
	@echo "Copied dfx build artifacts to .dfx/{$(NETWORKS)}/canisters/$(CANISTER_NAME)/"

.PHONY: docker-verify-wasm
docker-verify-wasm:
	@echo "Building wasm with Docker..."
	@cd docker && docker compose build --no-cache wasm && docker compose run --rm wasm
	@LOCAL_HASH=$$(shasum -a 256 out/$(CANISTER_NAME).wasm | cut -d ' ' -f 1); \
	echo "Docker wasm hash:   $$LOCAL_HASH"; \
	DEPLOYED_HASH=$$(dfx canister info $(CANISTER_NAME) --network $(VERIFY_NETWORK) | grep "Module hash:" | sed 's/Module hash: 0x//'); \
	echo "Deployed wasm hash ($(VERIFY_NETWORK)): $$DEPLOYED_HASH"; \
	if [ "$$LOCAL_HASH" = "$$DEPLOYED_HASH" ]; then \
		echo "✅ MATCH: Docker build matches deployed canister $(CANISTER_NAME) on $(VERIFY_NETWORK)"; \
	else \
		echo "❌ MISMATCH: Docker build does NOT match deployed canister $(CANISTER_NAME) on $(VERIFY_NETWORK)"; \
		exit 1; \
	fi
