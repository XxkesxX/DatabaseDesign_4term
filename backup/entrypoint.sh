#!/usr/bin/env bash
set -euo pipefail

mkdir -p /state /backups

/scripts/setup-minio.sh

cat > /etc/crontabs/root <<EOF
${BACKUP_INTERVAL} /scripts/run_backup.sh >> /proc/1/fd/1 2>> /proc/1/fd/2
EOF

echo "=== Active cron schedule ==="
cat /etc/crontabs/root

exec crond -f -l 2