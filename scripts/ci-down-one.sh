#!/bin/bash
set -e

echo "DOWN 1 migration"

migrate -path /migrations \
  -database "$DATABASE_URL" \
  down 1