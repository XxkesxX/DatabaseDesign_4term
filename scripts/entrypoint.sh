set -e

echo "Waiting for Postgres..."
sleep 5

export DATABASE_URL=$TEST_DATABASE_URL

echo "Running Seqwall staircase..."

seqwall staircase \
  --postgres-url "$TEST_DATABASE_URL" \
  --migrations-path /migrations \
  --upgrade "/scripts/ci-up-one.sh" \
  --downgrade "/scripts/ci-down-one.sh"

echo "Seqwall passed!"

export DATABASE_URL=$MAIN_DATABASE_URL

echo "Applying migrations to MAIN DB..."

migrate -path /migrations \
  -database "$DATABASE_URL" \
  up

echo "Done"