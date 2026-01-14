SHELL := /bin/bash

# Disable built-in rules and variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

###########################################################################
# Help
#
.PHONY: help
help:
	@echo "Makefile targets:"
	@echo "  smoketest               - Run all smoke tests (share-agent and share-service)"
	@echo "  smoketest-share-agent   - Start dfx, deploy mainer_ctrlb_canister_0, and run smoke tests"
	@echo "  smoketest-share-service - Start dfx, deploy mainer_service_canister, and run smoke tests"
	@echo "  help                    - Show this help message"

###########################################################################
# Smoke tests
#
.PHONY: smoketest
smoketest:
	dfx stop
	dfx start --clean --background
	dfx deploy mainer_ctrlb_canister_0
	dfx deploy mainer_service_canister
	pytest -vv --exitfirst test/test_mainer_ctrlb_canister_0.py
	pytest -vv --exitfirst test/test_mainer_service_canister.py
	dfx stop

.PHONY: smoketest-share-agent
smoketest-share-agent:
	dfx stop
	dfx start --clean --background
	dfx deploy mainer_ctrlb_canister_0
	pytest -vv --exitfirst test/test_mainer_ctrlb_canister_0.py
	dfx stop

.PHONY: smoketest-share-service
smoketest-share-service:
	dfx stop
	dfx start --clean --background
	dfx deploy mainer_service_canister
	pytest -vv --exitfirst test/test_mainer_service_canister.py
	dfx stop
