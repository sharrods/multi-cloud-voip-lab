FROM python:3.9-slim

# Install Docker CLI
RUN apt-get update && \
    apt-get install -y curl && \
    curl -fsSL https://get.docker.com -o get-docker.sh && \
    sh get-docker.sh && \
    rm get-docker.sh && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir prometheus-client

COPY exporter.py /exporter.py
RUN chmod +x /exporter.py

CMD ["python", "/exporter.py"]
