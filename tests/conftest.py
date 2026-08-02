"""Shared pytest fixtures for the whole test suite."""

import os

import pytest

# Environment variables that must never be visible to the test suite.
# The tests have to run without any real credential (see CLAUDE.md, rule 4).
FORBIDDEN_ENV_PREFIXES = ("OPENAI_", "WPP_")


@pytest.fixture(autouse=True, scope="session")
def _strip_external_credentials() -> None:
    """Remove provider credentials from the environment for the whole session.

    This is the structural guarantee that no test can reach a real external
    API by accident, even on a developer machine with a populated ``.env``.
    """
    for name in [key for key in os.environ if key.startswith(FORBIDDEN_ENV_PREFIXES)]:
        del os.environ[name]
