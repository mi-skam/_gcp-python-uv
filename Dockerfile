# Dockerfile.simple (alternative, simpler approach)
FROM python:3.12-slim

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

# Copy and install dependencies
COPY pyproject.toml uv.lock ./
RUN uv pip install --system --no-cache -r pyproject.toml

# Copy app
COPY main.py .

# Non-root user
RUN useradd -m appuser
USER appuser

CMD ["sh", "-c", "gunicorn --bind :$PORT --workers 1 --threads 8 main:app"]