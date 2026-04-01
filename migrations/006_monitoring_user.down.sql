DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'metrics_user'
    ) THEN
        REVOKE pg_monitor FROM metrics_user;
        DROP ROLE metrics_user;
    END IF;
END
$$;