#!/usr/bin/env bash
set -euo pipefail

mc alias set local "${MINIO_ENDPOINT}" "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}"

mc mb --ignore-existing "local/${BUCKET_BACKUP_NAME}"

mc admin user add local "${MINIO_BACKUP_ACCESS_KEY}" "${MINIO_BACKUP_SECRET_KEY}" || true

cat > /tmp/backup-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": ["s3:ListBucket"],
      "Effect": "Allow",
      "Resource": ["arn:aws:s3:::${BUCKET_BACKUP_NAME}"]
    },
    {
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Effect": "Allow",
      "Resource": ["arn:aws:s3:::${BUCKET_BACKUP_NAME}/*"]
    }
  ]
}
EOF

mc admin policy create local backup-policy /tmp/backup-policy.json || true
mc admin policy attach local backup-policy --user "${MINIO_BACKUP_ACCESS_KEY}"