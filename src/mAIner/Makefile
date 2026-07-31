SHELL := /bin/bash

# Disable built-in rules and variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

CANISTER_NAME  = mainer_service_canister
VERIFY_NETWORK ?= prd

# Which identity to act as. Empty means "whatever `icp identity default` is set to on this
# machine" -- i.e. yours. icp-cli keeps its own identity store and does not import dfx's,
# so import your key once (see README-developer-migration-guide-from-dfx-to-icp-cli.md).
# Override for a single run with:  make <target> IDENTITY=my-deploy-key
IDENTITY ?=

###########################################################################
# Help
#
.PHONY: help
help:
	@echo "Makefile targets:"
	@echo "  smoketest          - Start a local network, deploy canister, and run smoke tests"
	@echo "  build-wasm         - builds wasm using icp-cli and prints wasm-hash"
	@echo "  docker-build-base  - builds the Docker base image with icp-cli, mops, moc"
	@echo "  docker-build-wasm  - builds wasm using Docker (reproducible build)"
	@echo "  docker-verify-wasm - verifies Docker-built wasm matches deployed canister"
	@echo "  help               - Show this help message"

###########################################################################
# Smoke tests
#
# icp-cli has no `--clean`: a managed network keeps its state in .icp/cache, so removing
# that directory is the equivalent. NEVER remove .icp itself -- .icp/data/mappings holds
# the mainnet canister ids.
#
# icp-cli also does not auto-create a `default` identity the way dfx did, and icpp-pro's
# test fixtures need one. `--storage plaintext` is required: a keyring-backed identity
# makes `icp identity export` prompt for a password and hang the test run.
.PHONY: smoketest
smoketest:
	-icp network stop
	rm -rf .icp/cache
	icp network start -d
	icp identity new default --storage plaintext 2>/dev/null || true
	icp identity default default
	$(MAKE) docker-build-wasm
	icp canister create mainer_ctrlb_canister_0 -e local
	icp canister install mainer_ctrlb_canister_0 --wasm out/$(CANISTER_NAME).wasm \
		--mode install -e local -y
	icp canister create $(CANISTER_NAME) -e local
	icp canister install $(CANISTER_NAME) --wasm out/$(CANISTER_NAME).wasm \
		--mode install -e local -y
	pytest -vv --exitfirst --network local test/test_mainer_ctrlb_canister_0.py
	pytest -vv --exitfirst --network local test/test_mainer_service_canister.py
	icp network stop

# The two mAIner roles are also tested separately: a ShareAgent controller instance
# (mainer_ctrlb_canister_0) and the ShareService instance. Both run the same wasm.
.PHONY: smoketest-share-agent
smoketest-share-agent:
	-icp network stop
	rm -rf .icp/cache
	icp network start -d
	icp identity new default --storage plaintext 2>/dev/null || true
	icp identity default default
	$(MAKE) docker-build-wasm
	icp canister create mainer_ctrlb_canister_0 -e local
	icp canister install mainer_ctrlb_canister_0 --wasm out/$(CANISTER_NAME).wasm \
		--mode install -e local -y
	pytest -vv --exitfirst --network local test/test_mainer_ctrlb_canister_0.py
	icp network stop

.PHONY: smoketest-share-service
smoketest-share-service:
	-icp network stop
	rm -rf .icp/cache
	icp network start -d
	icp identity new default --storage plaintext 2>/dev/null || true
	icp identity default default
	$(MAKE) docker-build-wasm
	icp canister create $(CANISTER_NAME) -e local
	icp canister install $(CANISTER_NAME) --wasm out/$(CANISTER_NAME).wasm \
		--mode install -e local -y
	pytest -vv --exitfirst --network local test/test_mainer_service_canister.py
	icp network stop

###########################################################################
# Local builds
#
# NOTE: on macOS this hash will NOT match the Docker build, and that is expected.
# Motoko codegen is deterministic across platforms -- every wasm section is byte-identical
# -- but the @dfinity/motoko recipe stamps `moc --version` into an `icp:private
# moc:version` metadata section, and moc reports a platform-specific build hash:
#   linux/amd64 : Motoko compiler 1.4.1 (source k8r4z8c3-...)
#   darwin/arm64: Motoko compiler 1.4.1 (source 0r7vgklj-...)
# That 90-byte string is the ONLY difference. The Docker build is the canonical,
# reproducible artifact; this target is a fast local convenience.
.PHONY: build-wasm
build-wasm:
	icp build $(CANISTER_NAME) -e prd
	@echo "Wasm hash (SHA256) -- local build, differs from Docker on non-linux/amd64:"
	@shasum -a 256 .icp/cache/artifacts/$(CANISTER_NAME) | cut -d ' ' -f 1

###########################################################################
# Docker-based reproducible builds
#
.PHONY: docker-build-base
docker-build-base:
	cd docker && docker compose build base

# Under dfx this target also copied out/* into .dfx/<net>/canisters/<name>/ so that a
# later `dfx deploy` would reuse the Docker-built wasm. icp-cli takes the wasm path
# explicitly (see docker-deploy), so that copy is gone.
.PHONY: docker-build-wasm
docker-build-wasm:
	cd docker && docker compose build --no-cache wasm && docker compose run --rm wasm
	@echo "Wasm hash (Docker build):"
	@shasum -a 256 out/$(CANISTER_NAME).wasm | cut -d ' ' -f 1

# Deploy the reproducible, Docker-built wasm.
#
# NOTE: guarded to the local environment on purpose. Mainnet redeploys are a separate
# project -- see WASM-HASHES.md. Override deliberately with DEPLOY_ENV=<env> once that
# project starts.
DEPLOY_ENV ?= local
.PHONY: docker-deploy
docker-deploy:
	@if [ "$(DEPLOY_ENV)" != "local" ]; then \
		echo "Refusing to deploy to '$(DEPLOY_ENV)': mainnet deploys are out of scope"; \
		echo "for the dfx -> icp-cli migration. See WASM-HASHES.md."; \
		exit 1; \
	fi
	icp canister install $(CANISTER_NAME) --wasm out/$(CANISTER_NAME).wasm \
		--mode upgrade -e $(DEPLOY_ENV) -y

# `icp canister status <principal> -n ic -p` reads the public state tree, so this works
# without being a controller of the canister (dfx needed `canister info` for that).
.PHONY: docker-verify-wasm
docker-verify-wasm:
	@echo "Building wasm with Docker..."
	@cd docker && docker compose build --no-cache wasm && docker compose run --rm wasm
	@LOCAL_HASH=$$(shasum -a 256 out/$(CANISTER_NAME).wasm | cut -d ' ' -f 1); \
	echo "Docker wasm hash:   $$LOCAL_HASH"; \
	CID=$$(icp canister status $(CANISTER_NAME) -e $(VERIFY_NETWORK) --id-only); \
	DEPLOYED_HASH=$$(icp canister status $$CID -n ic -p | grep "Module hash:" | sed 's/.*0x//'); \
	echo "Deployed wasm hash ($(VERIFY_NETWORK)): $$DEPLOYED_HASH"; \
	if [ "$$LOCAL_HASH" = "$$DEPLOYED_HASH" ]; then \
		echo "✅ MATCH: Docker build matches deployed canister $(CANISTER_NAME) on $(VERIFY_NETWORK)"; \
	else \
		echo "❌ MISMATCH: Docker build does NOT match deployed canister $(CANISTER_NAME) on $(VERIFY_NETWORK)"; \
		echo "   Expected during the dfx -> icp-cli migration: the build chain changed"; \
		echo "   (moc now comes from mops.toml, not from dfx). See WASM-HASHES.md."; \
		exit 1; \
	fi
