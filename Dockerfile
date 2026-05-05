FROM python:3.13-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

COPY pyproject.toml uv.lock ./

RUN uv venv /app/.venv --python 3.13 && \
    uv sync --frozen --no-dev && \
    uv pip install --python /app/.venv \
        opentelemetry-distro \
        opentelemetry-exporter-otlp

COPY . .

ENV PYTHONPATH=/app
ENV VIRTUAL_ENV=/app/.venv
ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

CMD ["opentelemetry-instrument", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]







# # Use Python 3.13 slim image
# FROM python:3.13-slim

# # Install uv
# COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# # Set working directory
# WORKDIR /app

# # Copy dependency files for caching
# COPY pyproject.toml uv.lock ./

# # Install dependencies with uv (uses lockfile for reproducibility)
# RUN uv venv --python 3.13 .venv && \
#     uv sync --frozen

# # Copy application code
# COPY . .

# # Set Python path
# ENV PYTHONPATH=/app

# # Expose port
# EXPOSE 8000

# # Run application (without --reload for production)
# CMD ["/bin/bash", "-c", "source .venv/bin/activate && exec uvicorn src.main:app --host 0.0.0.0 --port 8000"]
