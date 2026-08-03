"""Single entry point for every configuration value, loaded from the environment.

No other module may read ``os.environ`` or hardcode a configuration value
(CLAUDE.md, rule 6). :data:`REGISTRY` is the single source of truth: it drives
the parsing, the failure messages and the ``.env.example`` contract test, so a
new key cannot be added to the code without also being declared in the example
file.

Loading never happens at import time. It happens inside :func:`load_settings`
and :func:`get_settings`, so importing this module has no side effect and the
test suite keeps running without any credential (CLAUDE.md, rule 4).

Precedence is ``real environment > .env file > default``. A key that is present
but empty counts as absent: that is the exact state of someone who copied
``.env.example`` and has not filled the secrets yet, and the error must say
"fill this in" instead of forwarding an empty credential that would only fail
later as a 401.
"""

from __future__ import annotations

import functools
import os
import re
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field, fields
from enum import StrEnum
from pathlib import Path
from urllib.parse import quote

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_ENV_FILE = PROJECT_ROOT / ".env"

#: What every secret value is replaced with in reprs, logs and error messages.
SECRET_PLACEHOLDER = "***"

CEFR_LEVELS = ("A1", "A2", "B1", "B2", "C1", "C2")
LOG_LEVELS = ("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")

MIN_PORT = 1
MAX_PORT = 65535

#: RA2 caps the lesson designer at six anchor questions.
ANCHOR_QUESTIONS_CEILING = 6

_E164_PATTERN = re.compile(r"^\+[1-9]\d{7,14}$")
_POSTGRES_SCHEMES = ("postgresql://", "postgres://")
_HTTP_SCHEMES = ("http://", "https://")


class Consumer(StrEnum):
    """Who reads a given key.

    ``INFRA`` keys are declared in ``.env.example`` because the compose stack
    needs them, but they are deliberately not parsed or validated here.
    """

    APP = "app"
    INFRA = "infra"
    BOTH = "both"


@dataclass(frozen=True, slots=True)
class EnvVar:
    """Declaration of one environment variable."""

    name: str
    group: str
    default: str = ""
    required: bool = False
    secret: bool = False
    consumer: Consumer = Consumer.APP


REGISTRY: tuple[EnvVar, ...] = (
    # WhatsApp
    EnvVar("WPP_SESSION_NAME", "whatsapp", "yourtutor", consumer=Consumer.BOTH),
    EnvVar(
        "WPP_SERVER_URL",
        "whatsapp",
        "http://wppconnect:21465",
        consumer=Consumer.BOTH,
    ),
    EnvVar(
        "WPP_SECRET_KEY",
        "whatsapp",
        required=True,
        secret=True,
        consumer=Consumer.BOTH,
    ),
    EnvVar(
        "WPP_WEBHOOK_URL",
        "whatsapp",
        "http://api:8000/webhook",
        consumer=Consumer.BOTH,
    ),
    EnvVar("BOT_PHONE_NUMBER", "whatsapp"),
    EnvVar("WPP_PORT", "whatsapp", "21465", consumer=Consumer.INFRA),
    # OpenAI
    EnvVar("OPENAI_API_KEY", "openai", required=True, secret=True),
    EnvVar("OPENAI_MODEL_CHAT", "openai", "gpt-4o"),
    EnvVar("OPENAI_MODEL_STT", "openai", "whisper-1"),
    EnvVar("OPENAI_MODEL_TTS", "openai", "gpt-4o-mini-tts"),
    EnvVar("OPENAI_TTS_VOICE", "openai", "alloy"),
    EnvVar("OPENAI_TEMPERATURE", "openai", "0.7"),
    EnvVar("OPENAI_MAX_TOKENS", "openai", "800"),
    EnvVar("OPENAI_TIMEOUT_SECONDS", "openai", "30"),
    # Pedagogy
    EnvVar("DEFAULT_LEVEL", "pedagogy", "A1"),
    EnvVar("MAX_TURNS_PER_LESSON", "pedagogy", "10"),
    EnvVar("MAX_ANCHOR_QUESTIONS", "pedagogy", "6"),
    EnvVar("ITEMS_PER_LEVEL", "pedagogy", "12"),
    # Database
    EnvVar("POSTGRES_HOST", "database", "postgres", consumer=Consumer.BOTH),
    EnvVar("POSTGRES_PORT", "database", "5432", consumer=Consumer.BOTH),
    EnvVar("POSTGRES_DB", "database", "yourtutor", consumer=Consumer.BOTH),
    EnvVar("POSTGRES_USER", "database", "yourtutor", consumer=Consumer.BOTH),
    EnvVar(
        "POSTGRES_PASSWORD",
        "database",
        required=True,
        secret=True,
        consumer=Consumer.BOTH,
    ),
    EnvVar("DATABASE_URL", "database", secret=True, consumer=Consumer.BOTH),
    EnvVar("POSTGRES_HOST_PORT", "database", consumer=Consumer.INFRA),
    # Application
    EnvVar("API_PORT", "app", "8000", consumer=Consumer.BOTH),
    EnvVar("LOG_LEVEL", "app", "INFO"),
    EnvVar("COMPOSE_PROJECT_NAME", "app", "yourtutor", consumer=Consumer.INFRA),
)

SPECS: Mapping[str, EnvVar] = {spec.name: spec for spec in REGISTRY}

#: Keys without a default: the environment is unusable until they are set.
REQUIRED_KEYS: tuple[str, ...] = tuple(s.name for s in REGISTRY if s.required)

#: Keys whose value must never reach a log, a repr or an error message.
SECRET_KEYS: tuple[str, ...] = tuple(s.name for s in REGISTRY if s.secret)


class ConfigError(Exception):
    """Raised when the environment does not yield a usable configuration.

    It aggregates every problem instead of failing on the first one: whoever is
    bringing the project up for the first time needs the whole list at once,
    not one missing key per attempt.
    """

    def __init__(self, problems: Iterable[str]) -> None:
        self.problems: list[str] = list(problems)
        details = "\n".join(f"  - {problem}" for problem in self.problems)
        super().__init__(
            "invalid configuration, fix the following environment variable(s) "
            f"(see .env.example):\n{details}"
        )


# --------------------------------------------------------------------------
# .env file parsing
# --------------------------------------------------------------------------


def _strip_quotes(value: str) -> tuple[str, bool]:
    """Return the value without surrounding quotes, and whether it was quoted."""
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1], True
    return value, False


def _strip_inline_comment(value: str) -> str:
    """Drop a trailing ``# comment`` from an unquoted value."""
    if value.startswith("#"):
        return ""
    marker = value.find(" #")
    return value[:marker] if marker != -1 else value


def _read_env_file(path: Path) -> dict[str, str]:
    """Parse a ``.env`` file with the standard library only.

    A missing file is not an error: that is the normal case inside the
    container, which receives everything through the process environment.
    """
    try:
        # utf-8-sig also swallows the BOM that Windows editors like to add.
        content = path.read_text(encoding="utf-8-sig")
    except FileNotFoundError:
        return {}
    except OSError as exc:
        raise ConfigError([f"{path}: could not be read ({exc.strerror})"]) from exc

    values: dict[str, str] = {}
    for raw_line in content.splitlines():
        line = raw_line.strip().removeprefix("export ").strip()
        if not line or line.startswith("#"):
            continue
        name, separator, raw_value = line.partition("=")
        if not separator:
            # Malformed line: ignore it instead of breaking the whole startup.
            continue
        value, quoted = _strip_quotes(raw_value.strip())
        if not quoted:
            value = _strip_inline_comment(value).strip()
        values[name.strip()] = value
    return values


def _resolve_values(
    env_file: Path | str | None,
    environ: Mapping[str, str],
) -> dict[str, str]:
    """Collapse environment and ``.env`` file into one value per declared key."""
    file_values = _read_env_file(Path(env_file)) if env_file is not None else {}
    resolved: dict[str, str] = {}
    for name in SPECS:
        value = environ.get(name, "").strip()
        if not value:
            value = file_values.get(name, "").strip()
        resolved[name] = value
    return resolved


# --------------------------------------------------------------------------
# Typed readers
# --------------------------------------------------------------------------


@dataclass(slots=True)
class _Loader:
    """Reads declared keys, accumulating every problem instead of raising."""

    values: Mapping[str, str]
    errors: list[str] = field(default_factory=list)

    def _report(self, name: str, reason: str) -> None:
        self.errors.append(f"{name}: {reason}")

    def _shown(self, name: str, raw: str) -> str:
        """Render a value for an error message, never leaking a secret."""
        return SECRET_PLACEHOLDER if SPECS[name].secret else repr(raw)

    def _raw(self, name: str) -> str | None:
        """Return the effective raw value, or ``None`` if it is missing."""
        spec = SPECS[name]
        raw = self.values.get(name, "")
        if raw:
            return raw
        if spec.required:
            self._report(name, "is required and has no default, set it in your .env")
            return None
        return spec.default

    def _check_range(
        self,
        name: str,
        value: float,
        minimum: float | None,
        maximum: float | None,
        exclusive_minimum: float | None,
    ) -> None:
        if minimum is not None and value < minimum:
            self._report(name, f"expected a value >= {minimum}, got {value}")
        if exclusive_minimum is not None and value <= exclusive_minimum:
            self._report(name, f"expected a value > {exclusive_minimum}, got {value}")
        if maximum is not None and value > maximum:
            self._report(name, f"expected a value <= {maximum}, got {value}")

    def text(self, name: str) -> str:
        raw = self._raw(name)
        return "" if raw is None else raw

    def integer(
        self,
        name: str,
        *,
        minimum: int | None = None,
        maximum: int | None = None,
    ) -> int:
        raw = self._raw(name)
        if raw is None:
            return 0
        try:
            value = int(raw)
        except ValueError:
            self._report(name, f"expected an integer, got {self._shown(name, raw)}")
            return 0
        self._check_range(name, value, minimum, maximum, None)
        return value

    def port(self, name: str) -> int:
        return self.integer(name, minimum=MIN_PORT, maximum=MAX_PORT)

    def number(
        self,
        name: str,
        *,
        minimum: float | None = None,
        maximum: float | None = None,
        exclusive_minimum: float | None = None,
    ) -> float:
        raw = self._raw(name)
        if raw is None:
            return 0.0
        try:
            value = float(raw)
        except ValueError:
            self._report(name, f"expected a number, got {self._shown(name, raw)}")
            return 0.0
        self._check_range(name, value, minimum, maximum, exclusive_minimum)
        return value

    def choice(self, name: str, allowed: tuple[str, ...]) -> str:
        raw = self._raw(name)
        if raw is None:
            return allowed[0]
        value = raw.upper()
        if value not in allowed:
            self._report(
                name,
                f"expected one of {', '.join(allowed)}, got {raw!r}",
            )
            return allowed[0]
        return value

    def http_url(self, name: str) -> str:
        raw = self._raw(name)
        if raw is None:
            return ""
        if not raw.startswith(_HTTP_SCHEMES):
            self._report(
                name,
                f"expected a URL starting with http:// or https://, got {raw!r}",
            )
        return raw

    def optional_database_url(self, name: str) -> str:
        raw = self._raw(name)
        if not raw:
            return ""
        if not raw.startswith(_POSTGRES_SCHEMES):
            # The value carries the password, so it is never echoed back.
            self._report(name, "expected a URL starting with postgresql://")
        return raw

    def optional_phone(self, name: str) -> str:
        raw = self._raw(name)
        if not raw:
            return ""
        if not _E164_PATTERN.fullmatch(raw):
            # Not echoed back: it is personal data, and the format alone is
            # enough to fix the typo.
            self._report(
                name,
                "expected an E.164 phone number: '+' followed by 8 to 15 digits",
            )
        return raw


# --------------------------------------------------------------------------
# Settings
# --------------------------------------------------------------------------


def _masked_repr(instance: object, secret_fields: frozenset[str]) -> str:
    parts = []
    for spec in fields(instance):  # type: ignore[arg-type]
        value = getattr(instance, spec.name)
        if spec.name in secret_fields and value:
            value = SECRET_PLACEHOLDER
        parts.append(f"{spec.name}={value!r}")
    return f"{type(instance).__name__}({', '.join(parts)})"


def redact_url_password(url: str) -> str:
    """Return ``url`` with its password replaced by :data:`SECRET_PLACEHOLDER`."""
    scheme, separator, rest = url.partition("://")
    if not separator or "@" not in rest:
        return url
    credentials, _, location = rest.rpartition("@")
    user, has_password, _ = credentials.partition(":")
    if not has_password:
        return url
    return f"{scheme}://{user}:{SECRET_PLACEHOLDER}@{location}"


@dataclass(frozen=True, slots=True, repr=False)
class WhatsAppSettings:
    session_name: str
    server_url: str
    secret_key: str
    webhook_url: str
    bot_phone_number: str

    def __repr__(self) -> str:
        return _masked_repr(self, frozenset({"secret_key"}))


@dataclass(frozen=True, slots=True, repr=False)
class OpenAISettings:
    api_key: str
    model_chat: str
    model_stt: str
    model_tts: str
    tts_voice: str
    temperature: float
    max_tokens: int
    timeout_seconds: float

    def __repr__(self) -> str:
        return _masked_repr(self, frozenset({"api_key"}))


@dataclass(frozen=True, slots=True)
class PedagogySettings:
    default_level: str
    max_turns_per_lesson: int
    max_anchor_questions: int
    items_per_level: int


@dataclass(frozen=True, slots=True, repr=False)
class DatabaseSettings:
    host: str
    port: int
    database: str
    user: str
    password: str
    url_override: str

    @property
    def url(self) -> str:
        """Connection URL: the explicit override wins, otherwise it is derived."""
        if self.url_override:
            return self.url_override
        return self._build_url(quote(self.password, safe=""))

    @property
    def url_safe(self) -> str:
        """Same URL with the password masked. This is the one safe to log (RNF4)."""
        if self.url_override:
            return redact_url_password(self.url_override)
        return self._build_url(SECRET_PLACEHOLDER)

    def _build_url(self, password: str) -> str:
        user = quote(self.user, safe="")
        return f"postgresql://{user}:{password}@{self.host}:{self.port}/{self.database}"

    def __repr__(self) -> str:
        return _masked_repr(self, frozenset({"password", "url_override"}))


@dataclass(frozen=True, slots=True)
class AppSettings:
    api_port: int
    log_level: str


@dataclass(frozen=True, slots=True)
class Settings:
    """Every configuration value of the system, validated and immutable."""

    whatsapp: WhatsAppSettings
    openai: OpenAISettings
    pedagogy: PedagogySettings
    database: DatabaseSettings
    app: AppSettings


def load_settings(
    *,
    env_file: Path | str | None = DEFAULT_ENV_FILE,
    environ: Mapping[str, str] | None = None,
) -> Settings:
    """Build the settings object, or raise :class:`ConfigError` listing every problem.

    Args:
        env_file: ``.env`` to read; ``None`` skips file loading entirely.
        environ: process environment to use; defaults to :data:`os.environ`.
    """
    values = _resolve_values(env_file, os.environ if environ is None else environ)
    loader = _Loader(values)

    whatsapp = WhatsAppSettings(
        session_name=loader.text("WPP_SESSION_NAME"),
        server_url=loader.http_url("WPP_SERVER_URL"),
        secret_key=loader.text("WPP_SECRET_KEY"),
        webhook_url=loader.http_url("WPP_WEBHOOK_URL"),
        bot_phone_number=loader.optional_phone("BOT_PHONE_NUMBER"),
    )
    openai = OpenAISettings(
        api_key=loader.text("OPENAI_API_KEY"),
        model_chat=loader.text("OPENAI_MODEL_CHAT"),
        model_stt=loader.text("OPENAI_MODEL_STT"),
        model_tts=loader.text("OPENAI_MODEL_TTS"),
        tts_voice=loader.text("OPENAI_TTS_VOICE"),
        temperature=loader.number("OPENAI_TEMPERATURE", minimum=0.0, maximum=2.0),
        max_tokens=loader.integer("OPENAI_MAX_TOKENS", minimum=1),
        timeout_seconds=loader.number("OPENAI_TIMEOUT_SECONDS", exclusive_minimum=0.0),
    )
    pedagogy = PedagogySettings(
        default_level=loader.choice("DEFAULT_LEVEL", CEFR_LEVELS),
        max_turns_per_lesson=loader.integer("MAX_TURNS_PER_LESSON", minimum=1),
        max_anchor_questions=loader.integer(
            "MAX_ANCHOR_QUESTIONS",
            minimum=1,
            maximum=ANCHOR_QUESTIONS_CEILING,
        ),
        items_per_level=loader.integer("ITEMS_PER_LEVEL", minimum=1),
    )
    database = DatabaseSettings(
        host=loader.text("POSTGRES_HOST"),
        port=loader.port("POSTGRES_PORT"),
        database=loader.text("POSTGRES_DB"),
        user=loader.text("POSTGRES_USER"),
        password=loader.text("POSTGRES_PASSWORD"),
        url_override=loader.optional_database_url("DATABASE_URL"),
    )
    app = AppSettings(
        api_port=loader.port("API_PORT"),
        log_level=loader.choice("LOG_LEVEL", LOG_LEVELS),
    )

    if loader.errors:
        raise ConfigError(loader.errors)

    return Settings(
        whatsapp=whatsapp,
        openai=openai,
        pedagogy=pedagogy,
        database=database,
        app=app,
    )


@functools.lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Process-wide cached settings. Use ``get_settings.cache_clear()`` in tests."""
    return load_settings()
