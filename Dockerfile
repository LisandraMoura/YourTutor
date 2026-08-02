# API image: Python + ffmpeg (RI3) + project dependencies resolved from uv.lock.
FROM python:3.12-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    PATH=/opt/venv/bin:$PATH

# RI3: ffmpeg converts the OpenAI TTS output to OGG/Opus so WhatsApp treats it
# as a voice message (PTT) instead of a file attachment (RF6).
#
# Deliberately not pinning the apt version: Debian drops superseded versions
# from the archive, so a pinned ffmpeg makes the build fail for every
# contributor the moment a security update ships. The base image tag is the
# reproducibility boundary; the `ffmpeg -version` check below is the guard.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ffmpeg \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Fail the build — loudly, here — if ffmpeg ever disappears from the base image,
# instead of failing at runtime when a lesson is already being sent.
RUN ffmpeg -version

COPY --from=ghcr.io/astral-sh/uv:0.12.1 /uv /uvx /usr/local/bin/

WORKDIR /app

# Dependencies in their own layer so editing app/ does not invalidate the cache.
# --frozen makes the build fail on a stale lock instead of silently resolving a
# different version than the one CI uses.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

COPY app ./app

# Non-root. The temporary audio directory lives in the container's ephemeral
# filesystem (/tmp) — no media volume is ever mounted (RF11).
RUN useradd --create-home --uid 1000 app \
    && chown -R app:app /app /opt/venv
# The name is backed by a fixed numeric uid (1000) created just above, which is
# the portability concern the rule is about; the name is kept for readability.
# hadolint ignore=DL3066
USER app

# No EXPOSE: the port comes from API_PORT and EXPOSE does not interpolate at
# runtime. Publishing is handled by docker-compose.yml.

# TODO(#12): replace with the webhook server once it exists. Today the project
# has no HTTP framework (dependencies = []), and adding one here would be both a
# new dependency and out of this issue's scope.
CMD ["sleep", "infinity"]
