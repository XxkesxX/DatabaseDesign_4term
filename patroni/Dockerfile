FROM postgres:15-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       python3-pip \
       python3-dev \
       gcc \
       libpq-dev \
       curl \
    && python3 -m pip install --break-system-packages "patroni[etcd3]" psycopg2-binary \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*