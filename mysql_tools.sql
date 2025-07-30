-- MySQL tools

-- Database Status

SHOW VARIABLES;

-- innodb_file_per table indica se o purge está ligado

-- Server version and uptime
SELECT VERSION(), @@version_comment, NOW() - INTERVAL variable_value SECOND AS server_started
FROM performance_schema.global_status
WHERE variable_name = 'Uptime';

-- Show all databases with their sizes
SELECT 
    table_schema AS 'Database', 
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables 
GROUP BY table_schema;

-- Performance

SHOW STATUS LIKE 'Threads_connected';
SHOW PROCESSLIST;

-- Key performance metrics
SHOW GLOBAL STATUS LIKE 'Qcache%';
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool%';
SHOW GLOBAL STATUS LIKE 'Key%';

-- Table health

-- Análise

ANALYZE TABLE table_name;

-- Check for fragmented tables
SELECT 
    table_schema, 
    table_name, 
    data_free/1024/1024 AS data_free_mb,
    data_length/1024/1024 AS data_length_mb
FROM information_schema.tables 
WHERE data_free > 0 AND table_schema NOT IN ('information_schema', 'mysql', 'performance_schema')
ORDER BY data_free_mb DESC;

-- Find tables without primary keys
SELECT 
    tables.table_schema, 
    tables.table_name
FROM information_schema.tables
LEFT JOIN information_schema.table_constraints 
    ON tables.table_schema = table_constraints.table_schema
    AND tables.table_name = table_constraints.table_name
    AND table_constraints.constraint_type = 'PRIMARY KEY'
WHERE 
    tables.table_schema NOT IN ('information_schema', 'mysql', 'performance_schema')
    AND table_constraints.constraint_name IS NULL
    AND tables.table_type = 'BASE TABLE';

-- Optimization

OPTIMIZE TABLE my_table;
-- mysqlcheck --check --auto-repair my_database;

-- Replication status

SHOW SLAVE STATUS\G
SHOW MASTER STATUS;

-- Privileges

-- List all users and their hosts
SELECT user, host FROM mysql.user;

-- Check for users with excessive privileges
SELECT * FROM mysql.user WHERE Super_priv = 'Y' OR File_priv = 'Y' OR Process_priv = 'Y' OR Shutdown_priv = 'Y';


-- BKP

-- Check when tables were last analyzed/checked
SELECT 
    table_schema, 
    table_name, 
    update_time 
FROM information_schema.tables 
WHERE table_schema NOT IN ('information_schema', 'mysql', 'performance_schema');

-- Check for tables needing optimization
SELECT 
    table_schema, 
    table_name, 
    engine, 
    table_rows, 
    data_free 
FROM information_schema.tables 
WHERE data_free > 0 AND table_schema NOT IN ('information_schema', 'mysql', 'performance_schema');

-- Idle connections

-- Basic Detection

-- Show all connections with their current state and duration
SELECT 
    id, 
    user, 
    host, 
    db, 
    command, 
    time AS idle_seconds, 
    state, 
    info
FROM information_schema.processlist
WHERE command = 'Sleep' 
ORDER BY time DESC;

-- Detailed analisys

-- Extended idle connection information with thresholds
SELECT 
    p.id, 
    p.user, 
    p.host, 
    p.db, 
    p.command, 
    p.time AS idle_seconds,
    SEC_TO_TIME(p.time) AS idle_time,
    p.state, 
    t.processlist_info AS query_text,
    t.trx_started AS transaction_started,
    IF(t.trx_mysql_thread_id IS NULL, 'No', 'Yes') AS in_transaction
FROM 
    information_schema.processlist p
LEFT JOIN 
    information_schema.innodb_trx t ON p.id = t.trx_mysql_thread_id
WHERE 
    p.command = 'Sleep' 
    AND p.time > 60  -- Filter for connections idle more than 60 seconds
ORDER BY 
    p.time DESC;

-- Idle summary

-- Summary of idle connections by user
SELECT 
    user, 
    COUNT(*) AS total_connections,
    SUM(IF(command = 'Sleep', 1, 0)) AS idle_connections,
    SUM(IF(command = 'Sleep', time, 0)) AS total_idle_seconds,
    MAX(IF(command = 'Sleep', time, 0)) AS max_idle_seconds,
    host
FROM 
    information_schema.processlist
GROUP BY 
    user, host
HAVING 
    idle_connections > 0
ORDER BY 
    total_idle_seconds DESC;

-- Long running idle

-- Connections idle for more than 10 minutes (600 seconds)
SELECT 
    id, 
    user, 
    host, 
    db, 
    command, 
    time AS idle_seconds,
    SEC_TO_TIME(time) AS idle_time
FROM 
    information_schema.processlist
WHERE 
    command = 'Sleep' 
    AND time > 600  -- 10 minutes
ORDER BY 
    time DESC;


-- Kill

-- Generate KILL commands for connections idle more than 1 hour (3600 seconds)
SELECT 
    CONCAT('KILL ', id, ';') AS kill_command,
    id, 
    user, 
    host, 
    time AS idle_seconds,
    SEC_TO_TIME(time) AS idle_time
FROM 
    information_schema.processlist
WHERE 
    command = 'Sleep' 
    AND time > 3600
ORDER BY 
    time DESC;