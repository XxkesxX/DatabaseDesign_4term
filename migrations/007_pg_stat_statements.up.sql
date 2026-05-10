CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

GRANT SELECT ON pg_stat_statements TO metrics_user;
