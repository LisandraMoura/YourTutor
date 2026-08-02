"""Contract tests for ``.env.example``.

``.env.example`` is the only configuration documentation a contributor reads
before running the project, and the compose stack of the infrastructure issues
reads the very same keys. These tests keep three things aligned: §9 of the
specification, the registry in ``app.config`` and the example file itself.
"""

from __future__ import annotations

import re

import pytest

from app.config import (
    PROJECT_ROOT,
    REQUIRED_KEYS,
    SECRET_KEYS,
    SPECS,
    ConfigError,
    _read_env_file,
    load_settings,
)

ENV_EXAMPLE = PROJECT_ROOT / ".env.example"
SPEC = PROJECT_ROOT / "docs" / "requisitos" / "requisitos-tutor-ingles.md"

# Values that would mean a real credential leaked into the repository.
CREDENTIAL_PATTERNS = (
    re.compile(r"sk-[A-Za-z0-9_-]{16,}"),
    re.compile(r"[A-Za-z0-9+/=_-]{32,}"),
)


@pytest.fixture(scope="module")
def declared() -> dict[str, str]:
    return _read_env_file(ENV_EXAMPLE)


def _spec_section_9_keys() -> list[str]:
    """Extract the keys of the ``env`` block under §9 of the specification."""
    content = SPEC.read_text(encoding="utf-8")
    section = content.split("\n## 9. ", 1)[1].split("\n## ", 1)[0]
    block = section.split("```env", 1)[1].split("```", 1)[0]
    return [
        line.split("=", 1)[0].strip()
        for line in block.splitlines()
        if "=" in line and not line.lstrip().startswith("#")
    ]


def test_env_example_exists() -> None:
    assert ENV_EXAMPLE.is_file(), "the repository must ship a versioned .env.example"


def test_env_example_declares_every_registered_key(declared: dict[str, str]) -> None:
    missing = sorted(set(SPECS) - set(declared))
    assert not missing, (
        f"keys known to app/config.py but absent from .env.example: {missing}"
    )


def test_env_example_has_no_undeclared_key(declared: dict[str, str]) -> None:
    unknown = sorted(set(declared) - set(SPECS))
    assert not unknown, (
        f"keys in .env.example that app/config.py does not know: {unknown}"
    )


def test_env_example_covers_spec_section_9(declared: dict[str, str]) -> None:
    missing = sorted(key for key in _spec_section_9_keys() if key not in declared)
    assert not missing, (
        f"keys required by §9 of the spec and absent from .env.example: {missing}"
    )


def test_env_example_documents_the_real_defaults(declared: dict[str, str]) -> None:
    """The example doubles as the defaults documentation, so it must not drift."""
    drifted = {
        name: (value, SPECS[name].default)
        for name, value in declared.items()
        if name in SPECS and value != SPECS[name].default
    }
    assert not drifted, (
        f"example value differs from the default in app/config.py: {drifted}"
    )


def test_env_example_leaves_required_secrets_empty(declared: dict[str, str]) -> None:
    for name in REQUIRED_KEYS:
        assert declared[name] == "", f"{name} must ship empty, never with a value"


def test_env_example_has_no_real_secret(declared: dict[str, str]) -> None:
    for name in SECRET_KEYS:
        assert declared[name] == "", f"{name} must ship empty"
    for name, value in declared.items():
        for pattern in CREDENTIAL_PATTERNS:
            assert not pattern.search(value), (
                f"{name} holds a value that looks like a real credential"
            )


def test_env_example_has_no_real_phone_number(declared: dict[str, str]) -> None:
    assert declared["BOT_PHONE_NUMBER"] == ""
    content = ENV_EXAMPLE.read_text(encoding="utf-8")
    assert not re.search(r"\+\d{8,15}", content), (
        "no phone number, real or plausible, may be versioned (CLAUDE.md, rule 5)"
    )


def test_env_example_as_is_fails_only_on_the_required_keys() -> None:
    """`cp .env.example .env` must fail only where the README says: the secrets."""
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=ENV_EXAMPLE, environ={})
    reported = {problem.split(":", 1)[0] for problem in excinfo.value.problems}
    assert reported == set(REQUIRED_KEYS)


def test_env_example_loads_cleanly_once_the_secrets_are_filled(
    declared: dict[str, str],
) -> None:
    filled = dict(declared)
    filled.update(dict.fromkeys(REQUIRED_KEYS, "filled-for-tests"))
    settings = load_settings(env_file=None, environ=filled)
    assert settings.app.log_level == "INFO"
