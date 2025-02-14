/*
FERRAMENTAS PARA MONITORAMENTO DE BANCOS DE DADOS POSTGRES
*/

--  1. System Catalog Tables
   /*- 'pg_stat_activity': Provides information about current database sessions, 
   including queries being executed, their state, and the user running them.
     sql */
     SELECT * FROM pg_stat_activity;
     
   /*- 'pg_stat_database': Contains statistics about database-wide activity, such as 
   the number of transactions, commits, rollbacks, and more.
     sql */
     SELECT * FROM pg_stat_database;
     
   /*- 'pg_stat_user_tables': Provides statistics about user tables, including sequential scans, index scans, and row counts.
     sql */
     SELECT * FROM pg_stat_user_tables;
     
   /*- 'pg_stat_user_indexes': Contains statistics about index usage, including the number of scans and rows fetched.
     sql */
     SELECT * FROM pg_stat_user_indexes;
     
   /*- 'pg_locks': Shows information about current locks held by active processes.
     sql */
     SELECT * FROM pg_locks;
     

 -- 2. Performance Monitoring Queries
   /*- Long-running queries:
     sql */
    SELECT pid, age(clock_timestamp(), query_start), usename, query
    FROM pg_stat_activity
    WHERE state <> 'idle' -- !=
    AND query_start < current_timestamp - interval '5' MINUTE -- verificar funcionamento correto
    ORDER BY query_start;
     
   /*- Blocking queries:
     sql */
     SELECT blocked_locks.pid AS blocked_pid,
            blocked_activity.usename AS blocked_user,
            blocking_locks.pid AS blocking_pid,
            blocking_activity.usename AS blocking_user,
            blocked_activity.query AS blocked_query,
            blocking_activity.query AS blocking_query
     FROM pg_catalog.pg_locks blocked_locks
     JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
     JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
                                             AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
                                             AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
                                             AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
                                             AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
                                             AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
                                             AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
                                             AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
                                             AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
                                             AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
                                             AND blocking_locks.pid <> blocked_locks.pid -- !=
     JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
     WHERE NOT blocked_locks.granted;
     
   /*- Cache hit ratio:
     sql */
     SELECT sum(heap_blks_read) as heap_read,
            sum(heap_blks_hit)  as heap_hit,
            (sum(heap_blks_hit) - sum(heap_blks_read)) / sum(heap_blks_hit) as ratio
     FROM pg_statio_user_tables;
     

 -- 3. Built-in Functions
   /*- 'pg_size_pretty(size)': Converts a size in bytes to a human-readable format.
     sql */
     SELECT pg_size_pretty(pg_database_size('mydatabase')); -- substituir o database em si
     
   /*- 'pg_stat_get_activity(pid)': Returns information about a specific backend process.
     sql */
     SELECT * FROM pg_stat_get_activity(12345); -- numero do PID
     
   /*- 'pg_stat_get_snapshot_timestamp()': Returns the timestamp of the last statistics snapshot.
     sql */
     SELECT pg_stat_get_snapshot_timestamp();
     

 -- 4. Index Usage and Maintenance
   /*- Unused indexes:
     sql */
     SELECT indexrelid::regclass AS index_name,
            relid::regclass AS table_name,
            idx_scan,
            idx_tup_read,
            idx_tup_fetch
     FROM pg_stat_user_indexes
     WHERE idx_scan = 0;
     
   /*- Index size:
     sql */
     SELECT indexrelid::regclass AS index_name,
            pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
     FROM pg_index
     ORDER BY pg_relation_size(indexrelid) DESC;
     

-- 5. Vacuum and Analyze Statistics
   /*- Last vacuum and analyze times:
     sql */
     SELECT relname,
            last_vacuum,
            last_autovacuum,
            last_analyze,
            last_autoanalyze
     FROM pg_stat_user_tables;
     
   /*- Dead tuples:
     sql */
     SELECT relname,
            n_dead_tup,
            n_live_tup,
            (n_dead_tup / (n_live_tup + n_dead_tup))::numeric(10,2) AS dead_ratio
     FROM pg_stat_user_tables
     WHERE n_live_tup + n_dead_tup > 0;
     

 -- 6. Replication Monitoring
   /*- Replication status:
     sql */
     SELECT * FROM pg_stat_replication;
     
   /*- Replication lag:
     sql */
     SELECT client_addr,
            application_name,
            state,
            sent_lsn,
            write_lsn,
            flush_lsn,
            replay_lsn,
            pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn) AS send_lag,
            pg_wal_lsn_diff(sent_lsn, write_lsn) AS write_lag,
            pg_wal_lsn_diff(write_lsn, flush_lsn) AS flush_lag,
            pg_wal_lsn_diff(flush_lsn, replay_lsn) AS replay_lag
     FROM pg_stat_replication;
     

 -- 7. Disk Usage
   /*- Database size:
     sql */
     SELECT pg_size_pretty(pg_database_size('mydatabase')); -- database em questao
     
   /*- Table size:
     sql */
     SELECT relname AS table_name,
            pg_size_pretty(pg_relation_size(relid)) AS table_size
     FROM pg_stat_user_tables
     ORDER BY pg_relation_size(relid) DESC;
     

 -- 8. Connection and Session Monitoring
   /*- Active connections:
     sql */
     SELECT count(*) FROM pg_stat_activity;
     
   /*- Idle connections:
     sql */
     SELECT count(*) FROM pg_stat_activity WHERE state = 'idle';
     

 -- 9. Query Performance Analysis
   /*- Slow queries:
     sql */
     SELECT query, calls, total_time, mean_time
     FROM pg_stat_statements
     ORDER BY total_time DESC
     LIMIT 10;
     
   /*- Query execution time:
     sql */
     SELECT query, calls, total_time, rows
     FROM pg_stat_statements
     ORDER BY total_time DESC;
     

 -- 10. Log Analysis
   /*- Enable query logging:
     sql */
     SET log_statement = 'all';
     
   /*- Check log file location:
     sql */
     SHOW log_directory;
     SHOW log_filename;
     

 -- 11. Resource Usage
   /*- CPU and memory usage:
     sql */
     SELECT pid, usename, state, query, cpu_time, memory_usage
     FROM pg_stat_activity;
     

 -- 12. Autovacuum Monitoring
   /*- Autovacuum status:
     sql */
     SELECT relname, last_autovacuum, last_autoanalyze
     FROM pg_stat_user_tables;
     

 -- 13. Deadlocks
   /*- Deadlock detection:
     sql */
     SELECT * FROM pg_stat_activity WHERE waiting = true;
     

 -- 14. Checkpoint Activity
   /*- Checkpoint statistics:
     sql */
     SELECT * FROM pg_stat_bgwriter;
     

 -- 15. Backup and Recovery
   /*- Backup status:
     sql */
     SELECT * FROM pg_stat_archiver;
     

 -- 16. Configuration Settings
   /*- Current configuration:
     sql */
     SHOW ALL;
     

 -- 17. User and Role Management
   /*- User activity:
     sql */
     SELECT usename, state, count(*)
     FROM pg_stat_activity
     GROUP BY usename, state;
     

 -- 18. Table Bloat
   /*- Table bloat estimation:
     sql */
     SELECT schemaname, tablename,
            pg_size_pretty(pg_relation_size(schemaname || '.' || tablename)) AS table_size,
            pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size
     FROM pg_tables
     ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC;
     

 -- 19. Transaction and Lock Monitoring
   /*- Long-running transactions:
     sql */
     SELECT pid, age(clock_timestamp(), query_start), usename, query
     FROM pg_stat_activity
     WHERE state <> 'idle' -- !=
       AND query_start < current_timestamp - interval '5' MINUTE
     ORDER BY query_start;
     

 -- 20. Database Health Checks
   /*- Database health:
     sql */
     SELECT datname, age(datfrozenxid) AS frozen_age
     FROM pg_database
     ORDER BY frozen_age DESC;

-- Queries for dealing with deadlocks

-- Kill process by PID

SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE pid = -- PID
;

-- Kill all blocking processes

SELECT pg_terminate_backend(blocking_pid)
FROM (
    SELECT blocking_locks.pid AS blocking_pid
    FROM pg_catalog.pg_locks blocked_locks
    JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
                                            AND blocking_locks.pid != blocked_locks.pid
    WHERE NOT blocked_locks.granted
) AS blockers;


-- Postgres configuration


 -- 1. View Current Configuration
-- Show all configuration settings:
  --sql
  SHOW ALL;
  
-- Show a specific configuration parameter:
  --sql
  SHOW parameter_name;
  
  --Example:
  --sql
  SHOW shared_buffers;
  

-- View configuration settings from `pg_settings`:
  --sql
  SELECT name, setting, unit, category, short_desc
  FROM pg_settings
  WHERE name = 'parameter_name';
  

--- 2. Modify Configuration
-- Change a parameter temporarily (for the current session):
  --sql
  SET parameter_name TO 'value';
  
  --Example:
  --sql
  SET work_mem TO '64MB';
  

-- Change a parameter globally (persists across restarts):
  --sql
  ALTER SYSTEM SET parameter_name = 'value';
  
  --Example:
  sql
  ALTER SYSTEM SET shared_buffers = '512MB';
  

-- Reload configuration changes without restarting PostgreSQL:
  --sql
  SELECT pg_reload_conf();
  

--- 3. Common Configuration Parameters
-- Memory-related settings:
  --sql
  SHOW shared_buffers; -- Memory used for caching data
  SHOW work_mem;      -- Memory used for sorting and hashing operations
  SHOW maintenance_work_mem; -- Memory for maintenance operations (e.g., VACUUM)
  

-- Connection settings:
  --sql
  SHOW max_connections; -- Maximum number of concurrent connections
  SHOW listen_addresses; -- IP addresses PostgreSQL listens on
  

-- Logging settings:
  --sql
  SHOW logging_collector; -- Enable or disable logging
  SHOW log_directory;     -- Directory where logs are stored
  SHOW log_filename;      -- Log file naming pattern
  

-- Autovacuum settings:
  --sql
  SHOW autovacuum; -- Enable or disable autovacuum
  SHOW autovacuum_max_workers; -- Number of autovacuum worker processes
  

-- Checkpoint settings:
  --sql
  SHOW checkpoint_timeout; -- Time between automatic checkpoints
  SHOW checkpoint_completion_target; -- Fraction of time for checkpoint spreading
  

-- Replication settings:
  --sql
  SHOW wal_level; -- Write-Ahead Log (WAL) level
  SHOW max_wal_senders; -- Maximum number of WAL sender processes
  

--- 4. Reset Configuration
-- Reset a parameter to its default value:
  --sql
  ALTER SYSTEM RESET parameter_name;
  
  --Example:
  --sql
  ALTER SYSTEM RESET shared_buffers;
  

-- Reset all parameters to default:
  --sql
  ALTER SYSTEM RESET ALL;
  

--- 5. Edit `postgresql.conf` Directly
-- Locate the `postgresql.conf` file (usually in the data directory).
-- Edit the file manually:
  --conf
  shared_buffers = 512MB
  work_mem = 64MB
  max_connections = 100
  
-- Reload the configuration:
  --bash
  pg_ctl reload -D /path/to/data/directory
  

--- 6. Backup and Restore Configuration
-- Backup the current configuration:
  --sql
  COPY (SELECT * FROM pg_settings) TO '/path/to/backup.csv' WITH CSV HEADER;
  

-- Restore configuration from a backup:
  Use the `ALTER SYSTEM` or `SET` commands to reapply settings.

--- 7. Check Configuration File Location
-- Find the location of `postgresql.conf`:
  --sql
  SHOW config_file;
  

-- Find the location of the data directory:
  --sql
  SHOW data_directory;
  

--- 8. Performance Tuning
-- Increase shared buffers for better caching:
  --sql
  ALTER SYSTEM SET shared_buffers = '1GB';
  

-- Adjust work memory for sorting and hashing:
  --sql
  ALTER SYSTEM SET work_mem = '128MB';
  

-- Enable parallel query execution:
  --sql
  ALTER SYSTEM SET max_parallel_workers_per_gather = 4;
  

--- 9. Security Configuration
-- Enable SSL:
  --conf
  ssl = on
  ssl_cert_file = '/path/to/server.crt'
  ssl_key_file = '/path/to/server.key'
  

-- Restrict access using `pg_hba.conf`:
  --conf
  host    all             all             192.168.1.0/24          md5
  

--- 10. Monitor Configuration Changes
-- Check when the configuration was last reloaded:
  --sql
  SELECT pg_conf_load_time();