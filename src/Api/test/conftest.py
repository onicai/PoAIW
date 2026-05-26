"""The pytest fixtures
   https://docs.pytest.org/en/latest/fixture.html
"""
# pylint: disable=missing-function-docstring, unused-import, wildcard-import, unused-wildcard-import, line-too-long, unused-argument
import pytest
from icpp.conftest_base import *  # pytest fixtures provided by icpp


def pytest_configure(config):
    config.addinivalue_line(
        "markers",
        "live_http: tests that make real HTTPS outcalls to external services "
        "(Coinbase, IC API). Skipped in CI to avoid network flakiness; "
        "run locally with `pytest -m live_http`.",
    )


# Define your pytest fixtures below
