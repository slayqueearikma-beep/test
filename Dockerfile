FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN adduser --disabled-password --gecos "" botuser \
    && mkdir -p /app/data \
    && chown -R botuser:botuser /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY bot.py .
COPY sevenamidelmath ./sevenamidelmath

USER botuser

CMD ["python", "bot.py"]
