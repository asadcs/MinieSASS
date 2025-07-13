<?php

/**
 * database.php - MinieSASS Database Configuration
 * 
 * Purpose: Database connection and configuration for SQLite database
 *
 * Author: Portfolio Project for MPE Software Engineer Position
 * Date: July 2025
 */

// Database configuration
define('DB_PATH', dirname(__DIR__) . '/data/miniesass.sqlite');
define('DB_SCHEMA_FILE', dirname(__DIR__) . '/sql/schema.sql');

// Global database connection
$pdo = null;

/**
 * Get database connection (singleton pattern)
 */
function get_database_connection()
{
    global $pdo;

    if ($pdo === null) {
        try {
            // Create database directory if it doesn't exist
            $db_dir = dirname(DB_PATH);
            if (!is_dir($db_dir)) {
                mkdir($db_dir, 0755, true);
            }

            // Check if database exists
            $db_exists = file_exists(DB_PATH);

            // Create PDO connection
            $pdo = new PDO('sqlite:' . DB_PATH);
            $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

            // Enable foreign key constraints
            $pdo->exec('PRAGMA foreign_keys = ON');
            $pdo->exec('PRAGMA journal_mode = WAL');
            $pdo->exec('PRAGMA synchronous = NORMAL');

            // Initialize database if it doesn't exist
            if (!$db_exists) {
                initialize_database($pdo);
            }
        } catch (PDOException $e) {
            error_log("Database connection failed: " . $e->getMessage());
            throw new Exception("Database connection failed. Please check configuration.");
        }
    }

    return $pdo;
}

/**
 * Initialize database with schema
 */
function initialize_database($pdo)
{
    try {
        // Check if schema file exists
        if (!file_exists(DB_SCHEMA_FILE)) {
            // Create basic schema if file doesn't exist
            create_basic_schema($pdo);
        } else {
            // Execute schema file
            $schema_sql = file_get_contents(DB_SCHEMA_FILE);
            $pdo->exec($schema_sql);
        }

        error_log("Database initialized successfully");
    } catch (PDOException $e) {
        error_log("Database initialization failed: " . $e->getMessage());
        throw new Exception("Failed to initialize database schema");
    }
}

/**
 * Create basic schema if schema.sql file is not available
 */
function create_basic_schema($pdo)
{
    $schema = "
        -- Users table
        CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            email TEXT,
            role TEXT DEFAULT 'user',
            created_at TEXT DEFAULT (datetime('now', 'utc')),
            last_login TEXT,
            active INTEGER DEFAULT 1
        );
        
        -- Processing jobs table
        CREATE TABLE processing_jobs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            job_uuid TEXT UNIQUE NOT NULL,
            observation_id TEXT NOT NULL,
            input_filename TEXT NOT NULL,
            processing_mode TEXT DEFAULT 'simulated',
            status TEXT DEFAULT 'queued',
            submitted_at TEXT DEFAULT (datetime('now', 'utc')),
            started_at TEXT,
            completed_at TEXT,
            submitted_by INTEGER REFERENCES users(id),
            events_input INTEGER,
            events_filtered INTEGER,
            events_calibrated INTEGER,
            sources_detected INTEGER,
            background_rate REAL,
            effective_exposure REAL,
            processing_time_seconds REAL,
            error_message TEXT,
            output_directory TEXT,
            created_at TEXT DEFAULT (datetime('now', 'utc')),
            updated_at TEXT DEFAULT (datetime('now', 'utc'))
        );
        
        -- Detected sources table
        CREATE TABLE detected_sources (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            job_id INTEGER NOT NULL REFERENCES processing_jobs(id) ON DELETE CASCADE,
            source_id INTEGER NOT NULL,
            ra_deg REAL NOT NULL,
            dec_deg REAL NOT NULL,
            ra_error_arcsec REAL,
            dec_error_arcsec REAL,
            det_x_pixel REAL,
            det_y_pixel REAL,
            flux_counts_per_sec REAL NOT NULL,
            flux_error_counts_per_sec REAL,
            net_counts INTEGER,
            total_counts INTEGER,
            detection_significance REAL,
            snr REAL,
            quality_flag INTEGER DEFAULT 0,
            timestamp TEXT DEFAULT (datetime('now', 'utc'))
        );
        
        -- System configuration table
        CREATE TABLE system_config (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            config_key TEXT UNIQUE NOT NULL,
            config_value TEXT NOT NULL,
            config_type TEXT DEFAULT 'string',
            description TEXT,
            updated_at TEXT DEFAULT (datetime('now', 'utc'))
        );
        
        -- Audit log table
        CREATE TABLE audit_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT DEFAULT (datetime('now', 'utc')),
            user_id INTEGER REFERENCES users(id),
            action TEXT NOT NULL,
            resource_type TEXT,
            resource_id TEXT,
            ip_address TEXT,
            user_agent TEXT
        );
        
        -- Indexes
        CREATE INDEX idx_processing_jobs_status ON processing_jobs(status);
        CREATE INDEX idx_processing_jobs_obs_id ON processing_jobs(observation_id);
        CREATE INDEX idx_detected_sources_job ON detected_sources(job_id);
        CREATE INDEX idx_detected_sources_significance ON detected_sources(detection_significance);
        
        -- Default admin user (password: admin123)
        INSERT INTO users (username, password_hash, email, role) VALUES 
        ('admin', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin@miniesass.local', 'admin');
        
        -- Default demo user (password: demo123)
        INSERT INTO users (username, password_hash, email, role) VALUES 
        ('demo', '$2y$10$TKh8H1.PfQx37YgCzwiKb.KjNyWgaHb9cbcoQgdIVFlYg7B77UdFm', 'demo@miniesass.local', 'user');
        
        -- Default system configuration
        INSERT INTO system_config (config_key, config_value, config_type, description) VALUES
        ('pipeline_version', '1.0.0', 'string', 'Current pipeline version'),
        ('max_concurrent_jobs', '2', 'integer', 'Maximum concurrent processing jobs'),
        ('default_detection_threshold', '4.0', 'real', 'Default source detection threshold (sigma)'),
        ('enable_background_estimation', 'true', 'boolean', 'Enable automatic background estimation'),
        ('detector_pixel_size_arcsec', '4.1', 'real', 'Detector pixel size in arcseconds'),
        ('processing_timeout_minutes', '30', 'integer', 'Processing timeout in minutes');
    ";

    $pdo->exec($schema);
}

/**
 * Execute a query and return results
 */
function db_query($sql, $params = [])
{
    try {
        $pdo = get_database_connection();
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt;
    } catch (PDOException $e) {
        error_log("Database query failed: " . $e->getMessage() . " SQL: " . $sql);
        throw new Exception("Database query failed");
    }
}

/**
 * Execute a query and return single row
 */
function db_query_single($sql, $params = [])
{
    $stmt = db_query($sql, $params);
    return $stmt->fetch();
}

/**
 * Execute a query and return all rows
 */
function db_query_all($sql, $params = [])
{
    $stmt = db_query($sql, $params);
    return $stmt->fetchAll();
}

/**
 * Execute an insert/update/delete query and return affected rows
 */
function db_execute($sql, $params = [])
{
    $stmt = db_query($sql, $params);
    return $stmt->rowCount();
}

/**
 * Get last insert ID
 */
function db_last_insert_id()
{
    $pdo = get_database_connection();
    return $pdo->lastInsertId();
}

/**
 * Begin transaction
 */
function db_begin_transaction()
{
    $pdo = get_database_connection();
    return $pdo->beginTransaction();
}

/**
 * Commit transaction
 */
function db_commit()
{
    $pdo = get_database_connection();
    return $pdo->commit();
}

/**
 * Rollback transaction
 */
function db_rollback()
{
    $pdo = get_database_connection();
    return $pdo->rollBack();
}

/**
 * Check database health
 */
function check_database_health()
{
    try {
        $pdo = get_database_connection();

        // Test basic query
        $stmt = $pdo->query("SELECT COUNT(*) as count FROM users");
        $result = $stmt->fetch();

        // Check file permissions
        $db_file = DB_PATH;
        $readable = is_readable($db_file);
        $writable = is_writable($db_file);
        $size = file_exists($db_file) ? filesize($db_file) : 0;

        return [
            'status' => 'healthy',
            'connection' => true,
            'user_count' => $result['count'],
            'file_readable' => $readable,
            'file_writable' => $writable,
            'file_size_bytes' => $size,
            'database_path' => $db_file
        ];
    } catch (Exception $e) {
        return [
            'status' => 'error',
            'connection' => false,
            'error' => $e->getMessage(),
            'database_path' => DB_PATH
        ];
    }
}

/**
 * Get database statistics
 */
function get_database_stats()
{
    try {
        $stats = [];

        // Table row counts
        $tables = ['users', 'processing_jobs', 'detected_sources', 'audit_log'];
        foreach ($tables as $table) {
            $result = db_query_single("SELECT COUNT(*) as count FROM $table");
            $stats[$table . '_count'] = $result['count'];
        }

        // Database file size
        $stats['file_size_bytes'] = file_exists(DB_PATH) ? filesize(DB_PATH) : 0;

        // Recent activity
        $result = db_query_single(
            "SELECT COUNT(*) as count FROM processing_jobs WHERE submitted_at > datetime('now', '-24 hours', 'utc')"
        );
        $stats['jobs_last_24h'] = $result['count'];

        $result = db_query_single(
            "SELECT COUNT(*) as count FROM detected_sources 
             JOIN processing_jobs ON detected_sources.job_id = processing_jobs.id 
             WHERE processing_jobs.completed_at > datetime('now', '-24 hours', 'utc')"
        );
        $stats['sources_last_24h'] = $result['count'];

        return $stats;
    } catch (Exception $e) {
        error_log("Failed to get database stats: " . $e->getMessage());
        return [];
    }
}

/**
 * Clean up old temporary data
 */
function cleanup_old_data($days_old = 30)
{
    try {
        db_begin_transaction();

        // Clean up old failed jobs
        $deleted_jobs = db_execute(
            "DELETE FROM processing_jobs 
             WHERE status = 'failed' 
             AND submitted_at < datetime('now', '-{$days_old} days', 'utc')"
        );

        // Clean up old audit logs (keep last 6 months)
        $deleted_logs = db_execute(
            "DELETE FROM audit_log 
             WHERE timestamp < datetime('now', '-6 months', 'utc')"
        );

        db_commit();

        return [
            'deleted_jobs' => $deleted_jobs,
            'deleted_logs' => $deleted_logs
        ];
    } catch (Exception $e) {
        db_rollback();
        error_log("Database cleanup failed: " . $e->getMessage());
        throw $e;
    }
}

// Initialize database connection on include
try {
    get_database_connection();
} catch (Exception $e) {
    // Log error but don't stop execution
    error_log("Database initialization warning: " . $e->getMessage());
}
