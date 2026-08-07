SHELL := /bin/bash

# Disable built-in rules and variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

CANISTER_NAME  = game_state_canister
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
# The identity to test as. icpp-pro 6.0.0 no longer reads or writes the machine-wide active
# identity: pytest is told which one to use, via ${ICPP_PRO_TEST_IDENTITY} or
# `pytest --identity <name>`. A run with neither stops at session start, so there is no way
# to silently test as the wrong principal.
#
# The canister below is DEPLOYED as this same identity on purpose. A canister's controller
# is whoever installed it, so if the deploy and the tests disagree, every is_controller
# assertion flips -- and `Err = Unauthorized` looks like a legitimate response, not a bug.
#
# `--storage plaintext` is required, not cosmetic: a keyring-backed identity makes
# `icp identity export` prompt for a password and hang the run.
#
# Nothing here ever runs `icp identity default <x>` -- that is global and persistent, and
# would clobber the identity you use for mainnet work.
export ICPP_PRO_TEST_IDENTITY = funnAI-local
TEST_IDENTITY := --identity $(ICPP_PRO_TEST_IDENTITY)

.PHONY: smoketest
smoketest:
	-icp network stop
	rm -rf .icp/cache
	icp network start -d
	icp identity new $(ICPP_PRO_TEST_IDENTITY) --storage plaintext 2>/dev/null || true
	$(MAKE) docker-build-wasm
	icp canister create $(CANISTER_NAME) -e local $(TEST_IDENTITY)
	icp canister install $(CANISTER_NAME) --wasm out/$(CANISTER_NAME).wasm \
		--mode install -e local -y $(TEST_IDENTITY)
	pytest -vv --exitfirst --network local test/test_game_state_canister.py
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

# The base image is the pinned toolchain (icp-cli, mops, moc, ic-wasm) that makes the
# build reproducible. It lives only on this machine -- it is never pushed -- so a
# `docker system prune -a` deletes it and the wasm build then fails trying to PULL it
# from Docker Hub, where it has never existed. Rebuild it automatically when it is
# missing, so a pruned Docker does not become a broken checkout.
#
# The name is read from docker-compose.yml rather than repeated here: that file already
# pins the tool versions the name encodes, and two copies would drift.
BASE_IMAGE := $(shell sed -n 's/^  name: &base_name "\(.*\)"/\1/p' docker/docker-compose.yml)

# Under dfx this target also copied out/* into .dfx/<net>/canisters/<name>/ so that a
# later `dfx deploy` would reuse the Docker-built wasm. icp-cli takes the wasm path
# explicitly (see docker-deploy), so that copy is gone.
.PHONY: docker-build-wasm
docker-build-wasm:
	@docker image inspect $(BASE_IMAGE) >/dev/null 2>&1 || { \
	  echo "base image $(BASE_IMAGE) is missing -- building it first"; \
	  $(MAKE) docker-build-base; \
	}
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
