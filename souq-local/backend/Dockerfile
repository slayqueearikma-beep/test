FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN groupadd --system margem && useradd --system --gid margem --create-home margem

COPY requirements.txt requirements-telemetry.txt ./
RUN pip install --no-cache-dir -r requirements.txt -r requirements-telemetry.txt

COPY app ./app
COPY scripts ./scripts
COPY alembic ./alembic
COPY alembic.ini .

RUN chmod +x /app/scripts/entrypoint.sh \
    && chown -R margem:margem /app

USER margem

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/ready')"

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
