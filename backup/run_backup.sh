#!/usr/bin/env bash
set -euo pipefail

export PGPASSWORD="${POSTGRES_PASSWORD}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
FILE_NAME="${POSTGRES_DB}_${TIMESTAMP}.dump"
LOCAL_FILE="/backups/${FILE_NAME}"
REMOTE_PATH="local/${BUCKET_BACKUP_NAME}/${FILE_NAME}"

TMP_METRICS="/state/backup_metrics.prom.tmp"
FINAL_METRICS="/state/backup_metrics.prom"
STATE_JSON="/state/backup_state.json"

mc alias set local "${MINIO_ENDPOINT}" "${MINIO_BACKUP_ACCESS_KEY}" "${MINIO_BACKUP_SECRET_KEY}"

echo "[$(date --iso-8601=seconds)] starting backup ${FILE_NAME}"

pg_dump \
  -h "${POSTGRES_HOST}" \
  -p "${POSTGRES_PORT}" \
  -U "${POSTGRES_USER}" \
  -d "${POSTGRES_DB}" \
  -Fc \
  -f "${LOCAL_FILE}"

SIZE_BYTES="$(stat -c%s "${LOCAL_FILE}")"

mc cp "${LOCAL_FILE}" "${REMOTE_PATH}"

mapfile -t OLD_FILES < <(
  mc ls --json "local/${BUCKET_BACKUP_NAME}" \
    | jq -r 'select(.type=="file") | [.lastModified, .key] | @tsv' \
    | sort \
    | awk -v keep="${BACKUP_RETENTION_COUNT}" '{
        lines[NR]=$0
      }
      END {
        for (i=1; i<=NR-keep; i++) {
          split(lines[i], a, "\t")
          print a[2]
        }
      }'
)

for old_file in "${OLD_FILES[@]:-}"; do
  [ -n "${old_file}" ] && mc rm "local/${BUCKET_BACKUP_NAME}/${old_file}"
done

LAST_TS="$(date +%s)"

cat > "${TMP_METRICS}" <<EOF
# HELP backup_last_success_timestamp_seconds Unix timestamp of last successful backup
# TYPE backup_last_success_timestamp_seconds gauge
backup_last_success_timestamp_seconds ${LAST_TS}

# HELP backup_last_size_bytes Size of last successful backup in bytes
# TYPE backup_last_size_bytes gauge
backup_last_size_bytes ${SIZE_BYTES}
EOF

mv "${TMP_METRICS}" "${FINAL_METRICS}"

cat > "${STATE_JSON}" <<EOF
{
  "last_success_timestamp_seconds": ${LAST_TS},
  "last_size_bytes": ${SIZE_BYTES},
  "last_file": "${FILE_NAME}"
}
EOF

rm -f "${LOCAL_FILE}"

echo "[$(date --iso-8601=seconds)] backup completed ${FILE_NAME}, size=${SIZE_BYTES}"