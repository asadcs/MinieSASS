-- =============================================================================
-- schema.sql - MinieSASS Database Schema
-- 
-- Purpose: SQLite database schema for X-ray data processing pipeline
--          Stores processing jobs, results, and user management
--
-- Author: Portfolio Project for MPE Software Engineer Position
-- Date: July 2025
-- =============================================================================

-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- =============================================================================
-- User Management (Basic Authentication)
-- =============================================================================

CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    email TEXT,
    role TEXT DEFAULT 'user' CHECK (role IN ('admin', 'user', 'readonly')),
    created_at TEXT DEFAULT (datetime('now', 'utc')),
    last_login TEXT,
    active INTEGER DEFAULT 1,
    CONSTRAINT valid_username CHECK (length(username) >= 3),
    CONSTRAINT valid_email CHECK (email IS NULL OR email LIKE '%@%.%')
);

-- Default admin user (password should be changed in production)
INSERT INTO users (username, password_hash, email, role) VALUES 
('admin', '$2y$10$example_hash_change_in_production', 'admin@miniesass.local', 'admin'),
('demo', '$2y$10$demo_hash_for_portfolio_demo', 'demo@miniesass.local', 'user');

-- =============================================================================
-- Processing Jobs Management
-- =============================================================================

CREATE TABLE processing_jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_uuid TEXT UNIQUE NOT NULL,
    observation_id TEXT NOT NULL,
    input_filename TEXT NOT NULL,
    processing_mode TEXT DEFAULT 'simulated' CHECK (processing_mode IN ('simulated', 'real')),
    status TEXT DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'completed', 'failed', 'cancelled')),
    priority INTEGER DEFAULT 50,
    
    -- Timestamps (ISO 8601 UTC format)
    submitted_at TEXT DEFAULT (datetime('now', 'utc')),
    started_at TEXT,
    completed_at TEXT,
    
    -- User and system info
    submitted_by INTEGER REFERENCES users(id),
    worker_node TEXT,
    
    -- Processing parameters
    parameters_json TEXT,  -- JSON string with processing parameters
    
    -- Resource usage
    processing_time_seconds REAL,
    memory_usage_mb REAL,
    cpu_usage_percent REAL,
    
    -- Results summary
    events_input INTEGER,
    events_filtered INTEGER,
    events_calibrated INTEGER,
    sources_detected INTEGER,
    background_rate REAL,  -- counts/s/arcsec²
    effective_exposure REAL,  -- seconds
    
    -- Error handling
    error_message TEXT,
    error_code INTEGER,
    retry_count INTEGER DEFAULT 0,
    
    -- Output files
    output_directory TEXT,
    log_filename TEXT,
    
    -- Metadata
    created_at TEXT DEFAULT (datetime('now', 'utc')),
    updated_at TEXT DEFAULT (datetime('now', 'utc'))
);

-- Indexes for performance
CREATE INDEX idx_processing_jobs_status ON processing_jobs(status);
CREATE INDEX idx_processing_jobs_obs_id ON processing_jobs(observation_id);
CREATE INDEX idx_processing_jobs_submitted_at ON processing_jobs(submitted_at);
CREATE INDEX idx_processing_jobs_user ON processing_jobs(submitted_by);

-- =============================================================================
-- Calibration Results
-- =============================================================================

CREATE TABLE calibration_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id INTEGER NOT NULL REFERENCES processing_jobs(id) ON DELETE CASCADE,
    
    -- Parameter identification
    parameter_name TEXT NOT NULL,
    parameter_category TEXT,  -- e.g., 'energy', 'position', 'background', 'detector'
    
    -- Parameter values with units
    parameter_value REAL,
    parameter_unit TEXT,
    parameter_error REAL,
    
    -- Quality assessment
    quality_flag INTEGER DEFAULT 0,  -- 0=good, 1=warning, 2=bad
    significance REAL,  -- Statistical significance
    confidence_level REAL,  -- e.g., 0.95 for 95% confidence
    
    -- Validation info
    reference_value REAL,  -- Expected/known value for validation
    validation_status TEXT CHECK (validation_status IN ('passed', 'failed', 'warning', 'unknown')),
    
    -- Metadata
    timestamp TEXT DEFAULT (datetime('now', 'utc')),
    notes TEXT
);

CREATE INDEX idx_calibration_results_job ON calibration_results(job_id);
CREATE INDEX idx_calibration_results_param ON calibration_results(parameter_name);

-- =============================================================================
-- Detected Sources
-- =============================================================================

CREATE TABLE detected_sources (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id INTEGER NOT NULL REFERENCES processing_jobs(id) ON DELETE CASCADE,
    
    -- Source identification
    source_id INTEGER NOT NULL,  -- Source ID within observation
    source_name TEXT,  -- Optional name if cross-matched
    
    -- Position (J2000 coordinates)
    ra_deg REAL NOT NULL,
    dec_deg REAL NOT NULL,
    ra_error_arcsec REAL,
    dec_error_arcsec REAL,
    position_confidence REAL,
    
    -- Detector coordinates
    det_x_pixel REAL,
    det_y_pixel REAL,
    
    -- Photometry
    flux_counts_per_sec REAL NOT NULL,
    flux_error_counts_per_sec REAL,
    net_counts INTEGER,
    total_counts INTEGER,
    background_counts REAL,
    
    -- Detection statistics
    detection_significance REAL,  -- Sigma detection level
    snr REAL,  -- Signal-to-noise ratio
    detection_likelihood REAL,  -- Statistical likelihood
    
    -- Source properties
    extent_arcsec REAL DEFAULT 0.0,  -- 0 for point sources
    is_extended INTEGER DEFAULT 0,
    variability_flag INTEGER DEFAULT 0,
    
    -- Energy information
    hardness_ratio REAL,  -- Simple hardness ratio
    mean_energy_kev REAL,
    energy_range_min_kev REAL,
    energy_range_max_kev REAL,
    
    -- Quality flags
    quality_flag INTEGER DEFAULT 0,  -- 0=good, 1=warning, 2=bad
    contamination_flag INTEGER DEFAULT 0,  -- Potential false detection
    
    -- Cross-matching
    catalog_match_name TEXT,  -- Name from reference catalog
    catalog_match_separation_arcsec REAL,
    catalog_match_confidence REAL,
    
    -- Metadata
    timestamp TEXT DEFAULT (datetime('now', 'utc')),
    notes TEXT
);

CREATE INDEX idx_detected_sources_job ON detected_sources(job_id);
CREATE INDEX idx_detected_sources_position ON detected_sources(ra_deg, dec_deg);
CREATE INDEX idx_detected_sources_flux ON detected_sources(flux_counts_per_sec);
CREATE INDEX idx_detected_sources_significance ON detected_sources(detection_significance);

-- =============================================================================
-- Observations Metadata
-- =============================================================================

CREATE TABLE observations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    observation_id TEXT UNIQUE NOT NULL,
    
    -- Observation details
    telescope TEXT,
    instrument TEXT,
    observation_mode TEXT,
    
    -- Pointing information
    ra_pointing_deg REAL,
    dec_pointing_deg REAL,
    roll_angle_deg REAL,
    
    -- Timing
    start_time_mjd REAL,
    end_time_mjd REAL,
    exposure_time_sec REAL,
    live_time_sec REAL,
    
    -- Data quality
    data_quality TEXT CHECK (data_quality IN ('excellent', 'good', 'fair', 'poor', 'unusable')),
    background_level TEXT CHECK (background_level IN ('low', 'medium', 'high', 'variable')),
    
    -- File information
    original_filename TEXT,
    file_size_bytes INTEGER,
    file_checksum TEXT,
    
    -- Processing history
    ingestion_date TEXT DEFAULT (datetime('now', 'utc')),
    last_processed TEXT,
    processing_count INTEGER DEFAULT 0,
    
    -- Metadata
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now', 'utc'))
);

CREATE INDEX idx_observations_obs_id ON observations(observation_id);
CREATE INDEX idx_observations_pointing ON observations(ra_pointing_deg, dec_pointing_deg);

-- =============================================================================
-- System Configuration
-- =============================================================================

CREATE TABLE system_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_key TEXT UNIQUE NOT NULL,
    config_value TEXT NOT NULL,
    config_type TEXT DEFAULT 'string' CHECK (config_type IN ('string', 'integer', 'real', 'boolean', 'json')),
    description TEXT,
    is_editable INTEGER DEFAULT 1,
    updated_at TEXT DEFAULT (datetime('now', 'utc')),
    updated_by INTEGER REFERENCES users(id)
);

-- Default system configuration
INSERT INTO system_config (config_key, config_value, config_type, description) VALUES
('pipeline_version', '1.0.0', 'string', 'Current pipeline version'),
('max_concurrent_jobs', '2', 'integer', 'Maximum concurrent processing jobs'),
('default_detection_threshold', '4.0', 'real', 'Default source detection threshold (sigma)'),
('enable_background_estimation', 'true', 'boolean', 'Enable automatic background estimation'),
('detector_pixel_size_arcsec', '4.1', 'real', 'Detector pixel size in arcseconds'),
('energy_calibration_gain', '0.005', 'real', 'Energy calibration gain (keV/channel)'),
('energy_calibration_offset', '0.2', 'real', 'Energy calibration offset (keV)'),
('processing_timeout_minutes', '30', 'integer', 'Processing timeout in minutes'),
('web_interface_theme', 'light', 'string', 'Web interface color theme'),
('enable_email_notifications', 'false', 'boolean', 'Send email notifications for job completion');

-- =============================================================================
-- Processing Queue Management
-- =============================================================================

CREATE TABLE processing_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id INTEGER UNIQUE NOT NULL REFERENCES processing_jobs(id) ON DELETE CASCADE,
    queue_priority INTEGER DEFAULT 50,
    estimated_duration_minutes REAL,
    dependencies TEXT,  -- JSON array of job IDs this job depends on
    queued_at TEXT DEFAULT (datetime('now', 'utc')),
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    next_retry_at TEXT,
    worker_assigned TEXT,
    assigned_at TEXT
);

CREATE INDEX idx_processing_queue_priority ON processing_queue(queue_priority DESC, queued_at);
CREATE INDEX idx_processing_queue_worker ON processing_queue(worker_assigned);

-- =============================================================================
-- File Management
-- =============================================================================

CREATE TABLE file_registry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT NOT NULL,
    filepath TEXT UNIQUE NOT NULL,
    file_type TEXT NOT NULL,  -- 'input', 'output', 'log', 'temporary'
    file_format TEXT,  -- 'fits', 'txt', 'png', 'json', etc.
    file_size_bytes INTEGER,
    checksum_md5 TEXT,
    
    -- Associations
    job_id INTEGER REFERENCES processing_jobs(id) ON DELETE SET NULL,
    observation_id TEXT,
    
    -- Lifecycle
    created_at TEXT DEFAULT (datetime('now', 'utc')),
    accessed_at TEXT,
    expires_at TEXT,  -- For temporary files
    is_archived INTEGER DEFAULT 0,
    
    -- Metadata
    description TEXT,
    tags TEXT  -- JSON array of tags
);

CREATE INDEX idx_file_registry_job ON file_registry(job_id);
CREATE INDEX idx_file_registry_obs ON file_registry(observation_id);
CREATE INDEX idx_file_registry_type ON file_registry(file_type);

-- =============================================================================
-- Audit Log
-- =============================================================================

CREATE TABLE audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT (datetime('now', 'utc')),
    user_id INTEGER REFERENCES users(id),
    username TEXT,  -- Denormalized for performance
    action TEXT NOT NULL,
    resource_type TEXT,  -- 'job', 'user', 'config', etc.
    resource_id TEXT,
    old_values TEXT,  -- JSON
    new_values TEXT,  -- JSON
    ip_address TEXT,
    user_agent TEXT,
    session_id TEXT,
    success INTEGER DEFAULT 1,
    error_message TEXT
);

CREATE INDEX idx_audit_log_timestamp ON audit_log(timestamp);
CREATE INDEX idx_audit_log_user ON audit_log(user_id);
CREATE INDEX idx_audit_log_action ON audit_log(action);

-- =============================================================================
-- Views for Common Queries
-- =============================================================================

-- Recent processing jobs with user information
CREATE VIEW recent_jobs AS
SELECT 
    pj.id,
    pj.observation_id,
    pj.status,
    pj.submitted_at,
    pj.completed_at,
    pj.sources_detected,
    u.username as submitted_by_username,
    pj.processing_time_seconds,
    pj.error_message
FROM processing_jobs pj
LEFT JOIN users u ON pj.submitted_by = u.id
ORDER BY pj.submitted_at DESC;

-- Source catalog with job information
CREATE VIEW source_catalog AS
SELECT 
    ds.id,
    ds.job_id,
    pj.observation_id,
    ds.source_id,
    ds.ra_deg,
    ds.dec_deg,
    ds.flux_counts_per_sec,
    ds.detection_significance,
    ds.quality_flag,
    pj.completed_at as detection_date
FROM detected_sources ds
JOIN processing_jobs pj ON ds.job_id = pj.id
WHERE pj.status = 'completed'
ORDER BY ds.detection_significance DESC;

-- Processing statistics
CREATE VIEW processing_stats AS
SELECT 
    DATE(submitted_at) as date,
    COUNT(*) as total_jobs,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_jobs,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_jobs,
    AVG(processing_time_seconds) as avg_processing_time,
    SUM(sources_detected) as total_sources_detected
FROM processing_jobs
GROUP BY DATE(submitted_at)
ORDER BY date DESC;

-- =============================================================================
-- Triggers for Data Integrity
-- =============================================================================

-- Update timestamps automatically
CREATE TRIGGER update_processing_jobs_timestamp 
    AFTER UPDATE ON processing_jobs
    FOR EACH ROW
BEGIN
    UPDATE processing_jobs 
    SET updated_at = datetime('now', 'utc')
    WHERE id = NEW.id;
END;

-- Log processing job status changes
CREATE TRIGGER log_job_status_change
    AFTER UPDATE OF status ON processing_jobs
    FOR EACH ROW
    WHEN OLD.status != NEW.status
BEGIN
    INSERT INTO audit_log (action, resource_type, resource_id, old_values, new_values)
    VALUES (
        'status_change',
        'processing_job',
        NEW.id,
        json_object('status', OLD.status),
        json_object('status', NEW.status)
    );
END;

-- =============================================================================
-- Sample Data for Development/Demo
-- =============================================================================

-- Sample processing jobs
INSERT INTO processing_jobs (
    job_uuid, observation_id, input_filename, processing_mode, status,
    submitted_by, events_input, events_filtered, sources_detected,
    background_rate, effective_exposure, processing_time_seconds,
    completed_at
) VALUES 
(
    'demo-job-001', 'TEST001', 'data/simulated/TEST001_events.fits', 'simulated', 'completed',
    2, 1245, 1156, 5, 1.23e-4, 1000.0, 12.5,
    datetime('now', '-1 hour', 'utc')
),
(
    'demo-job-002', 'TEST002', 'data/simulated/TEST002_events.fits', 'simulated', 'completed',
    2, 987, 923, 3, 1.45e-4, 1000.0, 9.8,
    datetime('now', '-30 minutes', 'utc')
);

-- Sample detected sources
INSERT INTO detected_sources (
    job_id, source_id, ra_deg, dec_deg, ra_error_arcsec, dec_error_arcsec,
    flux_counts_per_sec, flux_error_counts_per_sec, net_counts, total_counts,
    detection_significance, snr, quality_flag
) VALUES
(1, 1, 30.0542, 10.0312, 1.2, 1.1, 0.156, 0.015, 142, 156, 8.7, 12.3, 0),
(1, 2, 29.9508, 10.0789, 1.8, 1.6, 0.089, 0.012, 81, 89, 6.2, 8.9, 0),
(1, 3, 30.0823, 9.9187, 2.1, 2.3, 0.045, 0.009, 41, 45, 4.8, 5.2, 0),
(2, 1, 45.0287, -4.9734, 1.4, 1.3, 0.123, 0.013, 118, 123, 7.9, 11.1, 0),
(2, 2, 44.9834, -5.0512, 2.0, 1.9, 0.067, 0.011, 62, 67, 5.4, 6.8, 0);

-- =============================================================================
-- Database Maintenance
-- =============================================================================

-- Cleanup old temporary files (run periodically)
-- DELETE FROM file_registry WHERE file_type = 'temporary' AND expires_at < datetime('now', 'utc');

-- Cleanup old audit logs (keep last 6 months)
-- DELETE FROM audit_log WHERE timestamp < datetime('now', '-6 months', 'utc');

-- =============================================================================
-- Database Information
-- =============================================================================

-- Store schema version for future migrations
CREATE TABLE schema_info (
    version TEXT PRIMARY KEY,
    applied_at TEXT DEFAULT (datetime('now', 'utc')),
    description TEXT
);

INSERT INTO schema_info (version, description) VALUES 
('1.0.0', 'Initial MinieSASS database schema');

-- Final pragma settings
PRAGMA journal_mode = WAL;  -- Write-Ahead Logging for better concurrency
PRAGMA synchronous = NORMAL;  -- Good balance of safety and performance
PRAGMA cache_size = -2000;  -- 2MB cache
PRAGMA temp_store = MEMORY;  -- Store temporary tables in memory

-- =============================================================================
-- End of schema.sql
-- =============================================================================