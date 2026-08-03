"""Tests for the typed configuration loader in ``app.config``.

Every test builds its own environment explicitly and passes ``env_file=None``:
the loader must never depend on a ``.env`` sitting on the developer machine, and
no test may reach a real credential (CLAUDE.md, rule 4).
"""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import pytest

from app.config import (
    ANCHOR_QUESTIONS_CEILING,
    PROJECT_ROOT,
    REQUIRED_KEYS,
    SECRET_PLACEHOLDER,
    SPECS,
    ConfigError,
    _read_env_file,
    get_settings,
    load_settings,
    redact_url_password,
)

# Fake values, never a real credential.
FAKE_WPP_SECRET = "wpp-secret-for-tests"
FAKE_OPENAI_KEY = "openai-key-for-tests"
FAKE_DB_PASSWORD = "postgres-password-for-tests"


@pytest.fixture
def env() -> dict[str, str]:
    """Minimal valid environment: only the keys without a default."""
    return {
        "WPP_SECRET_KEY": FAKE_WPP_SECRET,
        "OPENAI_API_KEY": FAKE_OPENAI_KEY,
        "POSTGRES_PASSWORD": FAKE_DB_PASSWORD,
    }


# --------------------------------------------------------------------------
# Import safety
# --------------------------------------------------------------------------


def test_importing_config_module_does_not_require_env() -> None:
    """Importing must have no side effect, otherwise the suite needs credentials."""
    result = subprocess.run(
        [sys.executable, "-c", "import app.config"],
        cwd=PROJECT_ROOT,
        env={"PATH": os.environ.get("PATH", ""), "PYTHONPATH": str(PROJECT_ROOT)},
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr


# --------------------------------------------------------------------------
# Defaults
# --------------------------------------------------------------------------


def test_defaults_applied_when_optional_keys_absent(env: dict[str, str]) -> None:
    settings = load_settings(env_file=None, environ=env)

    assert settings.whatsapp.session_name == "yourtutor"
    assert settings.whatsapp.server_url == "http://wppconnect:21465"
    assert settings.whatsapp.webhook_url == "http://api:8000/webhook"
    assert settings.whatsapp.bot_phone_number == ""

    assert settings.openai.model_chat == "gpt-4o"
    assert settings.openai.model_stt == "whisper-1"
    assert settings.openai.model_tts == "gpt-4o-mini-tts"
    assert settings.openai.tts_voice == "alloy"
    assert settings.openai.temperature == pytest.approx(0.7)
    assert settings.openai.max_tokens == 800
    assert settings.openai.timeout_seconds == pytest.approx(30.0)

    assert settings.pedagogy.default_level == "A1"
    assert settings.pedagogy.max_turns_per_lesson == 10  # D2
    assert settings.pedagogy.max_anchor_questions == 6  # RA2
    assert settings.pedagogy.items_per_level == 12  # D1

    assert settings.database.host == "postgres"
    assert settings.database.port == 5432
    assert settings.database.database == "yourtutor"
    assert settings.database.user == "yourtutor"

    assert settings.app.api_port == 8000
    assert settings.app.log_level == "INFO"


# --------------------------------------------------------------------------
# Required keys and error reporting
# --------------------------------------------------------------------------


@pytest.mark.parametrize("missing", REQUIRED_KEYS)
def test_missing_required_key_raises_config_error(
    env: dict[str, str], missing: str
) -> None:
    del env[missing]
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=None, environ=env)
    assert missing in str(excinfo.value)


def test_all_missing_keys_reported_at_once() -> None:
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=None, environ={})
    message = str(excinfo.value)
    for key in REQUIRED_KEYS:
        assert key in message


def test_empty_required_key_is_treated_as_missing(env: dict[str, str]) -> None:
    env["OPENAI_API_KEY"] = "   "
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=None, environ=env)
    assert "OPENAI_API_KEY" in str(excinfo.value)


def test_error_message_never_leaks_secret_values(env: dict[str, str]) -> None:
    env["MAX_TURNS_PER_LESSON"] = "not-a-number"
    env["DATABASE_URL"] = f"mysql://user:{FAKE_DB_PASSWORD}@db:3306/x"
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=None, environ=env)
    message = str(excinfo.value)
    assert "MAX_TURNS_PER_LESSON" in message
    for secret in (FAKE_WPP_SECRET, FAKE_OPENAI_KEY, FAKE_DB_PASSWORD):
        assert secret not in message


def test_invalid_secret_value_is_masked_in_error(env: dict[str, str]) -> None:
    env["DATABASE_URL"] = "not-a-url"
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=None, environ=env)
    assert "not-a-url" not in str(excinfo.value)


def test_repr_masks_secrets(env: dict[str, str]) -> None:
    settings = load_settings(env_file=None, environ=env)
    rendered = repr(settings)
    for secret in (FAKE_WPP_SECRET, FAKE_OPENAI_KEY, FAKE_DB_PASSWORD):
        assert secret not in rendered
    assert SECRET_PLACEHOLDER in rendered


# --------------------------------------------------------------------------
# Casting and ranges
# --------------------------------------------------------------------------


def test_invalid_integer_raises_clear_error(env: dict[str, str]) -> None:
    env["MAX_TURNS_PER_LESSON"] = "abc"
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=None, environ=env)
    assert "MAX_TURNS_PER_LESSON: expected an integer" in str(excinfo.value)


def test_invalid_float_raises_clear_error(env: dict[str, str]) -> None:
    env["OPENAI_TEMPERATURE"] = "warm"
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=None, environ=env)
    assert "OPENAI_TEMPERATURE: expected a number" in str(excinfo.value)


@pytest.mark.parametrize(
    ("key", "value"),
    [
        ("OPENAI_TEMPERATURE", "-1"),
        ("OPENAI_TEMPERATURE", "2.5"),
        ("OPENAI_MAX_TOKENS", "0"),
        ("OPENAI_TIMEOUT_SECONDS", "0"),
        ("MAX_ANCHOR_QUESTIONS", str(ANCHOR_QUESTIONS_CEILING + 1)),
        ("MAX_ANCHOR_QUESTIONS", "0"),
        ("MAX_TURNS_PER_LESSON", "0"),
        ("ITEMS_PER_LEVEL", "0"),
        ("API_PORT", "70000"),
        ("API_PORT", "0"),
        ("POSTGRES_PORT", "99999"),
    ],
)
def test_out_of_range_values_rejected(
    env: dict[str, str], key: str, value: str
) -> None:
    env[key] = value
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=None, environ=env)
    assert key in str(excinfo.value)


def test_cefr_level_is_case_insensitive(env: dict[str, str]) -> None:
    env["DEFAULT_LEVEL"] = "b2"
    settings = load_settings(env_file=None, environ=env)
    assert settings.pedagogy.default_level == "B2"


def test_invalid_cefr_level_rejected(env: dict[str, str]) -> None:
    env["DEFAULT_LEVEL"] = "A7"
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=None, environ=env)
    message = str(excinfo.value)
    assert "DEFAULT_LEVEL" in message
    assert "A1" in message  # the error lists the accepted values


def test_log_level_is_case_insensitive(env: dict[str, str]) -> None:
    env["LOG_LEVEL"] = "debug"
    settings = load_settings(env_file=None, environ=env)
    assert settings.app.log_level == "DEBUG"


def test_invalid_log_level_rejected(env: dict[str, str]) -> None:
    env["LOG_LEVEL"] = "VERBOSE"
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=None, environ=env)
    assert "LOG_LEVEL" in str(excinfo.value)


def test_invalid_url_scheme_rejected(env: dict[str, str]) -> None:
    env["WPP_SERVER_URL"] = "wppconnect:21465"
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=None, environ=env)
    assert "WPP_SERVER_URL" in str(excinfo.value)


# Synthetic numbers: valid E.164 shape, nobody's real line (CLAUDE.md, rule 5).
@pytest.mark.parametrize("value", ["", "+5511900000000", "+550000000000"])
def test_bot_phone_number_accepts_empty_or_e164(
    env: dict[str, str], value: str
) -> None:
    env["BOT_PHONE_NUMBER"] = value
    settings = load_settings(env_file=None, environ=env)
    assert settings.whatsapp.bot_phone_number == value


@pytest.mark.parametrize("value", ["12345", "5511900000000", "+55 11 90000-0000"])
def test_invalid_bot_phone_number_rejected(env: dict[str, str], value: str) -> None:
    env["BOT_PHONE_NUMBER"] = value
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=None, environ=env)
    assert "BOT_PHONE_NUMBER" in str(excinfo.value)


# --------------------------------------------------------------------------
# Database URL
# --------------------------------------------------------------------------


def test_database_url_derived_from_postgres_keys(env: dict[str, str]) -> None:
    env |= {
        "POSTGRES_HOST": "db.internal",
        "POSTGRES_PORT": "6543",
        "POSTGRES_DB": "tutor",
        "POSTGRES_USER": "tutor_user",
        "POSTGRES_PASSWORD": "p@ss/word:1",
    }
    settings = load_settings(env_file=None, environ=env)
    assert settings.database.url == (
        "postgresql://tutor_user:p%40ss%2Fword%3A1@db.internal:6543/tutor"
    )


def test_explicit_database_url_wins_over_derived(env: dict[str, str]) -> None:
    env["DATABASE_URL"] = "postgresql://outside:secret@managed.example.com:5432/tutor"
    settings = load_settings(env_file=None, environ=env)
    assert settings.database.url == env["DATABASE_URL"]


def test_database_url_safe_masks_password(env: dict[str, str]) -> None:
    settings = load_settings(env_file=None, environ=env)
    assert FAKE_DB_PASSWORD not in settings.database.url_safe
    assert SECRET_PLACEHOLDER in settings.database.url_safe


def test_database_url_safe_masks_password_of_explicit_url(env: dict[str, str]) -> None:
    env["DATABASE_URL"] = "postgresql://outside:topsecret@managed.example.com:5432/t"
    settings = load_settings(env_file=None, environ=env)
    assert "topsecret" not in settings.database.url_safe
    assert settings.database.url_safe.startswith("postgresql://outside:")


def test_redact_url_password_leaves_url_without_credentials_untouched() -> None:
    assert redact_url_password("postgresql://db:5432/tutor") == (
        "postgresql://db:5432/tutor"
    )
    assert redact_url_password("postgresql://user@db:5432/tutor") == (
        "postgresql://user@db:5432/tutor"
    )
    assert redact_url_password("not a url") == "not a url"


def test_invalid_database_url_scheme_rejected(env: dict[str, str]) -> None:
    env["DATABASE_URL"] = "mysql://user:pwd@db:3306/tutor"
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=None, environ=env)
    assert "DATABASE_URL" in str(excinfo.value)


# --------------------------------------------------------------------------
# .env file handling and precedence
# --------------------------------------------------------------------------


def test_real_environment_wins_over_env_file(
    env: dict[str, str], tmp_path: Path
) -> None:
    env_file = tmp_path / ".env"
    env_file.write_text("LOG_LEVEL=ERROR\nAPI_PORT=9999\n", encoding="utf-8")
    env["LOG_LEVEL"] = "DEBUG"
    settings = load_settings(env_file=env_file, environ=env)
    assert settings.app.log_level == "DEBUG"  # environment wins
    assert settings.app.api_port == 9999  # file fills what the environment lacks


def test_env_file_parsing_handles_comments_quotes_and_export(
    tmp_path: Path,
) -> None:
    env_file = tmp_path / ".env"
    env_file.write_text(
        # \ufeff is the BOM that Windows editors add; the maintainer
        # works on WSL over Windows.
        "\ufeff# a comment\n"
        "\n"
        "export WPP_SESSION_NAME=exported\r\n"
        'OPENAI_MODEL_CHAT="quoted-model"\r\n'
        "OPENAI_TTS_VOICE='single-quoted'\n"
        "LOG_LEVEL=DEBUG # trailing comment\n"
        "a line without an equals sign\n"
        "OPENAI_MAX_TOKENS=# commented out value\n"
        "WPP_WEBHOOK_URL=http://api:8000/webhook?a=1&b=2\n",
        encoding="utf-8",
    )
    values = _read_env_file(env_file)
    assert values["WPP_SESSION_NAME"] == "exported"
    assert values["OPENAI_MODEL_CHAT"] == "quoted-model"
    assert values["OPENAI_TTS_VOICE"] == "single-quoted"
    assert values["LOG_LEVEL"] == "DEBUG"
    assert values["OPENAI_MAX_TOKENS"] == ""
    assert values["WPP_WEBHOOK_URL"] == "http://api:8000/webhook?a=1&b=2"


def test_missing_env_file_is_not_an_error(env: dict[str, str], tmp_path: Path) -> None:
    settings = load_settings(env_file=tmp_path / "absent.env", environ=env)
    assert settings.app.log_level == "INFO"


def test_unreadable_env_file_reports_the_path(
    env: dict[str, str], tmp_path: Path
) -> None:
    with pytest.raises(ConfigError) as excinfo:
        load_settings(env_file=tmp_path, environ=env)
    assert str(tmp_path) in str(excinfo.value)


# --------------------------------------------------------------------------
# Caching
# --------------------------------------------------------------------------


def test_get_settings_is_cached(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in SPECS:
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("WPP_SECRET_KEY", FAKE_WPP_SECRET)
    monkeypatch.setenv("OPENAI_API_KEY", FAKE_OPENAI_KEY)
    monkeypatch.setenv("POSTGRES_PASSWORD", FAKE_DB_PASSWORD)
    get_settings.cache_clear()
    try:
        assert get_settings() is get_settings()
    finally:
        get_settings.cache_clear()


# --------------------------------------------------------------------------
# No configuration hardcoded elsewhere
# --------------------------------------------------------------------------

# Literals that would mean a configuration value escaped app/config.py.
HARDCODED_MARKERS = (
    "gpt-",
    "whisper-",
    "postgresql://",
    "sk-",
)


def test_no_hardcoded_configuration_outside_config() -> None:
    offenders = []
    for path in sorted((PROJECT_ROOT / "app").rglob("*.py")):
        if path.name == "config.py":
            continue
        content = path.read_text(encoding="utf-8")
        offenders.extend(
            f"{path.relative_to(PROJECT_ROOT)}: {marker}"
            for marker in HARDCODED_MARKERS
            if marker in content
        )
    assert not offenders, (
        f"configuration must come from app/config.py, not from literals: {offenders}"
    )
