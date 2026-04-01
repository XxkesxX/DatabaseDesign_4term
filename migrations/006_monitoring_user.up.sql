DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'metrics_user'
    ) THEN
        CREATE ROLE metrics_user WITH LOGIN PASSWORD 'metrics_password';
    END IF;
END
$$;

GRANT pg_monitor TO metrics_user;