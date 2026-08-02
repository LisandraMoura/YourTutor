"""Smoke test: the suite must import the app and run without any OpenAI key."""

import os

import app


def test_app_package_is_importable() -> None:
    assert app.__name__ == "app"


def test_suite_runs_without_openai_key() -> None:
    assert "OPENAI_API_KEY" not in os.environ
