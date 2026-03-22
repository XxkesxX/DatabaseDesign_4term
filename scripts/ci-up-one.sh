#!/bin/bash
set -e

echo "UP 1 migration"

migrate -path /migrations \
  -database "$DATABASE_URL" \
  up 1