\copy (SELECT regexp_replace(query, '\s+', ' ', 'g') AS query, mean_exec_time, calls, shared_blks_hit, shared_blks_read FROM pg_stat_statements ORDER BY mean_exec_time DESC) TO STDOUT WITH CSV HEADER
