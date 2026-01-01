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
	@echo "  smoketest  - Start dfx, deploy canister, and run smoke tests"
	@echo "  help       - Show this help message"

###########################################################################
# Smoke tests
#
.PHONY: smoketest
smoketest:
	dfx stop
	dfx start --clean --background
	dfx deploy challenger_ctrlb_canister
	pytest -vv --exitfirst test/test_challenger_canister.py
	dfx stop
