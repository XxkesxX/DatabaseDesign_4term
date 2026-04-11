FROM python:3.12-alpine

RUN pip install --no-cache-dir prometheus_client

WORKDIR /app
COPY exporter.py /app/exporter.py

CMD ["python", "/app/exporter.py"]