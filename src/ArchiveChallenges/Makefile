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
	@echo "  smoketest - Start dfx, deploy archive_challenges_canister, and run smoke tests"
	@echo "  help      - Show this help message"

###########################################################################
# Smoke tests
#
.PHONY: smoketest
smoketest:
	dfx stop
	dfx start --clean --background
	dfx deploy archive_challenges_canister
	pytest -vv --exitfirst test/test_archive_challenges_canister.py
	dfx stop
