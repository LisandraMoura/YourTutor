"""Check that the source tree matches the repository map documented in CLAUDE.md."""

import importlib
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parent.parent

# Packages listed in the repository map of CLAUDE.md.
EXPECTED_PACKAGES = [
    "app",
    "app.agents",
    "app.audio",
    "app.db",
    "app.llm",
    "app.orchestrator",
    "app.prompts",
    "app.webhook",
    "app.whatsapp",
]

# Single-file modules listed in the repository map of CLAUDE.md.
EXPECTED_MODULES = ["app.config"]


@pytest.mark.parametrize("package_name", EXPECTED_PACKAGES)
def test_expected_packages_exist(package_name: str) -> None:
    package_dir = PROJECT_ROOT.joinpath(*package_name.split("."))
    assert package_dir.is_dir(), f"missing directory: {package_dir}"
    assert (package_dir / "__init__.py").is_file(), (
        f"missing __init__.py in {package_dir}"
    )
    assert importlib.import_module(package_name) is not None


@pytest.mark.parametrize("module_name", EXPECTED_MODULES)
def test_expected_modules_exist(module_name: str) -> None:
    module_path = PROJECT_ROOT.joinpath(*module_name.split(".")).with_suffix(".py")
    assert module_path.is_file(), f"missing module: {module_path}"
    assert importlib.import_module(module_name) is not None


def test_tests_directory_exists() -> None:
    assert (PROJECT_ROOT / "tests").is_dir()
