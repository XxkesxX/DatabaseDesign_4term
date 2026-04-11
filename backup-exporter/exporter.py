import os
import time
from prometheus_client import Gauge, start_http_server

STATE_FILE = os.getenv("BACKUP_STATE_FILE", "/state/backup_state.json")

last_success = Gauge(
    "backup_last_success_timestamp_seconds",
    "Unix timestamp of last successful backup"
)

last_size = Gauge(
    "backup_last_size_bytes",
    "Size of last successful backup in bytes"
)

def read_state():
    import json
    try:
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None

if __name__ == "__main__":
    start_http_server(8000)

    while True:
        state = read_state()
        if state:
            last_success.set(state.get("last_success_timestamp_seconds", 0))
            last_size.set(state.get("last_size_bytes", 0))
        time.sleep(15)