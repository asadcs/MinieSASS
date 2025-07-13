<?php

/**
 * index.php - MinieSASS Web Dashboard
 * 
 * Purpose: Main web interface for eROSITA-style X-ray data processing pipeline
 *          Provides upload, processing control, and results visualization
 *
 * Author: Portfolio Project for MPE Software Engineer Position
 * Date: July 2025
 */

session_start();
require_once 'config/database.php';
require_once 'includes/auth.php';
require_once 'includes/functions.php';

// Check authentication
if (!is_logged_in()) {
    header('Location: auth/login.php');
    exit;
}

$user_info = get_user_info($_SESSION['user_id']);
$recent_jobs = get_recent_jobs($_SESSION['user_id'], 10);
$system_stats = get_system_statistics();
?>

<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MinieSASS - X-ray Data Processing Pipeline</title>
    <link href="assets/css/bootstrap.min.css" rel="stylesheet">
    <link href="assets/css/fontawesome.min.css" rel="stylesheet">
    <link href="assets/css/miniesass.css" rel="stylesheet">
    <link rel="icon" type="image/x-icon" href="assets/images/favicon.ico">
</head>

<body class="bg-light">

    <!-- Navigation -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-primary">
        <div class="container">
            <a class="navbar-brand" href="#">
                <i class="fas fa-satellite-dish me-2"></i>
                MinieSASS
            </a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item">
                        <a class="nav-link active" href="index.php">
                            <i class="fas fa-dashboard me-1"></i>Dashboard
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="upload.php">
                            <i class="fas fa-upload me-1"></i>Upload Data
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="results.php">
                            <i class="fas fa-chart-line me-1"></i>Results
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="catalog.php">
                            <i class="fas fa-star me-1"></i>Source Catalog
                        </a>
                    </li>
                </ul>
                <ul class="navbar-nav">
                    <li class="nav-item dropdown">
                        <a class="nav-link dropdown-toggle" href="#" id="navbarDropdown" role="button" data-bs-toggle="dropdown">
                            <i class="fas fa-user me-1"></i><?= htmlspecialchars($user_info['username']) ?>
                        </a>
                        <ul class="dropdown-menu">
                            <li><a class="dropdown-item" href="profile.php">Profile</a></li>
                            <li><a class="dropdown-item" href="settings.php">Settings</a></li>
                            <li>
                                <hr class="dropdown-divider">
                            </li>
                            <li><a class="dropdown-item" href="auth/logout.php">Logout</a></li>
                        </ul>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <!-- Main Content -->
    <div class="container mt-4">

        <!-- Welcome Header -->
        <div class="row mb-4">
            <div class="col">
                <div class="card border-0 shadow-sm bg-gradient-primary text-white">
                    <div class="card-body">
                        <div class="d-flex align-items-center">
                            <div class="flex-grow-1">
                                <h2 class="card-title mb-1">
                                    <i class="fas fa-satellite-dish me-2"></i>
                                    Welcome to MinieSASS
                                </h2>
                                <p class="card-text mb-0 opacity-75">
                                    eROSITA-style X-ray Data Processing Pipeline
                                </p>
                                <small class="opacity-75">
                                    Last login: <?= format_datetime($user_info['last_login']) ?>
                                </small>
                            </div>
                            <div class="text-end">
                                <div class="d-flex gap-2">
                                    <a href="upload.php" class="btn btn-light btn-sm">
                                        <i class="fas fa-plus me-1"></i>New Job
                                    </a>
                                    <a href="docs/help.php" class="btn btn-outline-light btn-sm">
                                        <i class="fas fa-question-circle me-1"></i>Help
                                    </a>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- System Status Cards -->
        <div class="row mb-4">
            <div class="col-md-3">
                <div class="card border-0 shadow-sm h-100">
                    <div class="card-body text-center">
                        <div class="text-primary mb-2">
                            <i class="fas fa-tasks fa-2x"></i>
                        </div>
                        <h5 class="card-title"><?= $system_stats['total_jobs'] ?></h5>
                        <p class="card-text text-muted">Total Jobs</p>
                        <small class="text-success">
                            <i class="fas fa-arrow-up me-1"></i>
                            <?= $system_stats['jobs_today'] ?> today
                        </small>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card border-0 shadow-sm h-100">
                    <div class="card-body text-center">
                        <div class="text-success mb-2">
                            <i class="fas fa-check-circle fa-2x"></i>
                        </div>
                        <h5 class="card-title"><?= $system_stats['completed_jobs'] ?></h5>
                        <p class="card-text text-muted">Completed</p>
                        <small class="text-muted">
                            <?= number_format($system_stats['success_rate'], 1) ?>% success rate
                        </small>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card border-0 shadow-sm h-100">
                    <div class="card-body text-center">
                        <div class="text-warning mb-2">
                            <i class="fas fa-star fa-2x"></i>
                        </div>
                        <h5 class="card-title"><?= $system_stats['total_sources'] ?></h5>
                        <p class="card-text text-muted">Sources Detected</p>
                        <small class="text-info">
                            <i class="fas fa-telescope me-1"></i>
                            <?= $system_stats['sources_today'] ?> today
                        </small>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card border-0 shadow-sm h-100">
                    <div class="card-body text-center">
                        <div class="text-info mb-2">
                            <i class="fas fa-clock fa-2x"></i>
                        </div>
                        <h5 class="card-title"><?= format_duration($system_stats['avg_processing_time']) ?></h5>
                        <p class="card-text text-muted">Avg Processing Time</p>
                        <small class="text-muted">
                            Last 30 days
                        </small>
                    </div>
                </div>
            </div>
        </div>

        <!-- Main Content Row -->
        <div class="row">

            <!-- Recent Jobs -->
            <div class="col-md-8">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <div class="d-flex justify-content-between align-items-center">
                            <h5 class="card-title mb-0">
                                <i class="fas fa-history me-2"></i>Recent Processing Jobs
                            </h5>
                            <a href="jobs.php" class="btn btn-outline-primary btn-sm">
                                View All
                            </a>
                        </div>
                    </div>
                    <div class="card-body p-0">
                        <?php if (empty($recent_jobs)): ?>
                            <div class="text-center py-5 text-muted">
                                <i class="fas fa-inbox fa-3x mb-3"></i>
                                <h6>No processing jobs yet</h6>
                                <p>Upload your first FITS file to get started</p>
                                <a href="upload.php" class="btn btn-primary">
                                    <i class="fas fa-upload me-1"></i>Upload Data
                                </a>
                            </div>
                        <?php else: ?>
                            <div class="table-responsive">
                                <table class="table table-hover mb-0">
                                    <thead class="table-light">
                                        <tr>
                                            <th>Observation ID</th>
                                            <th>Status</th>
                                            <th>Mode</th>
                                            <th>Sources</th>
                                            <th>Submitted</th>
                                            <th>Duration</th>
                                            <th>Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <?php foreach ($recent_jobs as $job): ?>
                                            <tr>
                                                <td>
                                                    <strong><?= htmlspecialchars($job['observation_id']) ?></strong>
                                                    <?php if ($job['processing_mode'] == 'simulated'): ?>
                                                        <span class="badge bg-secondary ms-1">SIM</span>
                                                    <?php endif; ?>
                                                </td>
                                                <td>
                                                    <?php
                                                    $status_class = [
                                                        'completed' => 'success',
                                                        'running' => 'primary',
                                                        'failed' => 'danger',
                                                        'queued' => 'warning'
                                                    ];
                                                    $status_icon = [
                                                        'completed' => 'check-circle',
                                                        'running' => 'spinner',
                                                        'failed' => 'times-circle',
                                                        'queued' => 'clock'
                                                    ];
                                                    ?>
                                                    <span class="badge bg-<?= $status_class[$job['status']] ?>">
                                                        <i class="fas fa-<?= $status_icon[$job['status']] ?> me-1"></i>
                                                        <?= ucfirst($job['status']) ?>
                                                    </span>
                                                </td>
                                                <td>
                                                    <span class="text-muted"><?= ucfirst($job['processing_mode']) ?></span>
                                                </td>
                                                <td>
                                                    <?php if ($job['sources_detected'] !== null): ?>
                                                        <span class="badge bg-info"><?= $job['sources_detected'] ?></span>
                                                    <?php else: ?>
                                                        <span class="text-muted">-</span>
                                                    <?php endif; ?>
                                                </td>
                                                <td>
                                                    <small class="text-muted">
                                                        <?= time_ago($job['submitted_at']) ?>
                                                    </small>
                                                </td>
                                                <td>
                                                    <?php if ($job['processing_time_seconds']): ?>
                                                        <small class="text-muted">
                                                            <?= format_duration($job['processing_time_seconds']) ?>
                                                        </small>
                                                    <?php else: ?>
                                                        <span class="text-muted">-</span>
                                                    <?php endif; ?>
                                                </td>
                                                <td>
                                                    <div class="btn-group btn-group-sm">
                                                        <a href="job_details.php?id=<?= $job['id'] ?>"
                                                            class="btn btn-outline-primary btn-sm"
                                                            title="View Details">
                                                            <i class="fas fa-eye"></i>
                                                        </a>
                                                        <?php if ($job['status'] == 'completed'): ?>
                                                            <a href="results.php?job_id=<?= $job['id'] ?>"
                                                                class="btn btn-outline-success btn-sm"
                                                                title="View Results">
                                                                <i class="fas fa-chart-line"></i>
                                                            </a>
                                                        <?php endif; ?>
                                                        <?php if ($job['status'] == 'failed'): ?>
                                                            <a href="reprocess.php?job_id=<?= $job['id'] ?>"
                                                                class="btn btn-outline-warning btn-sm"
                                                                title="Retry">
                                                                <i class="fas fa-redo"></i>
                                                            </a>
                                                        <?php endif; ?>
                                                    </div>
                                                </td>
                                            </tr>
                                        <?php endforeach; ?>
                                    </tbody>
                                </table>
                            </div>
                        <?php endif; ?>
                    </div>
                </div>
            </div>

            <!-- Quick Actions & Status -->
            <div class="col-md-4">

                <!-- Quick Actions -->
                <div class="card border-0 shadow-sm mb-4">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-rocket me-2"></i>Quick Actions
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="d-grid gap-2">
                            <a href="upload.php" class="btn btn-primary">
                                <i class="fas fa-upload me-2"></i>Upload FITS File
                            </a>
                            <a href="simulated_data.php" class="btn btn-outline-secondary">
                                <i class="fas fa-flask me-2"></i>Generate Test Data
                            </a>
                            <a href="catalog.php" class="btn btn-outline-info">
                                <i class="fas fa-star me-2"></i>Browse Source Catalog
                            </a>
                            <a href="validation.php" class="btn btn-outline-success">
                                <i class="fas fa-check-double me-2"></i>Validate Pipeline
                            </a>
                        </div>
                    </div>
                </div>

                <!-- System Status -->
                <div class="card border-0 shadow-sm mb-4">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="card-title mb-0">
                            <i class="fas fa-server me-2"></i>System Status
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="mb-3">
                            <div class="d-flex justify-content-between align-items-center mb-1">
                                <small class="text-muted">Pipeline Status</small>
                                <span class="badge bg-success">Online</span>
                            </div>
                            <div class="d-flex justify-content-between align-items-center mb-1">
                                <small class="text-muted">Queue Length</small>
                                <span class="text-muted"><?= $system_stats['queued_jobs'] ?> jobs</span>
                            </div>
                            <div class="d-flex justify-content-between align-items-center mb-1">
                                <small class="text-muted">Active Workers</small>
                                <span class="text-muted"><?= $system_stats['active_workers'] ?></span>
                            </div>
                            <div class="d-flex justify-content-between align-items-center">
                                <small class="text-muted">Database Size</small>
                                <span class="text-muted"><?= format_filesize($system_stats['db_size_bytes']) ?></span>
                            </div>
                        </div>

                        <hr>

                        <div class="text-center">
                            <small class="text-muted">
                                Last updated: <?= date('H:i:s') ?><br>
                                Pipeline v<?= get_config('pipeline_version') ?>
                            </small>
                        </div>
                    </div>
                </div>

                <!-- Recent Sources -->
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <div class="d-flex justify-content-between align-items-center">
                            <h5 class="card-title mb-0">
                                <i class="fas fa-star me-2"></i>Recent Detections
                            </h5>
                            <a href="catalog.php" class="btn btn-outline-primary btn-sm">
                                View All
                            </a>
                        </div>
                    </div>
                    <div class="card-body">
                        <?php $recent_sources = get_recent_sources(5); ?>
                        <?php if (empty($recent_sources)): ?>
                            <div class="text-center text-muted py-3">
                                <i class="fas fa-star-half-alt fa-2x mb-2"></i>
                                <p class="mb-0">No sources detected yet</p>
                            </div>
                        <?php else: ?>
                            <div class="list-group list-group-flush">
                                <?php foreach ($recent_sources as $source): ?>
                                    <div class="list-group-item px-0 border-0">
                                        <div class="d-flex justify-content-between align-items-start">
                                            <div class="flex-grow-1">
                                                <h6 class="mb-1">
                                                    Source <?= $source['source_id'] ?>
                                                    <small class="text-muted">(<?= $source['observation_id'] ?>)</small>
                                                </h6>
                                                <p class="mb-1 small text-muted">
                                                    RA: <?= number_format($source['ra_deg'], 4) ?>°,
                                                    DEC: <?= number_format($source['dec_deg'], 4) ?>°
                                                </p>
                                                <small class="text-muted">
                                                    <?= number_format($source['flux_counts_per_sec'], 3) ?> cts/s,
                                                    <?= number_format($source['detection_significance'], 1) ?>σ
                                                </small>
                                            </div>
                                            <div class="text-end">
                                                <span class="badge bg-warning">
                                                    <?= number_format($source['detection_significance'], 1) ?>σ
                                                </span>
                                            </div>
                                        </div>
                                    </div>
                                <?php endforeach; ?>
                            </div>
                        <?php endif; ?>
                    </div>
                </div>
            </div>
        </div>

        <!-- Footer Information -->
        <div class="row mt-5">
            <div class="col">
                <div class="card border-0 bg-light">
                    <div class="card-body text-center text-muted">
                        <p class="mb-2">
                            <strong>MinieSASS</strong> - eROSITA-style X-ray Data Processing Pipeline
                        </p>
                        <p class="mb-0 small">
                            Portfolio project demonstrating X-ray astronomy data processing capabilities<br>
                            Built for MPE Software Engineer Position |
                            <a href="docs/about.php" class="text-decoration-none">About</a> |
                            <a href="docs/api.php" class="text-decoration-none">API</a> |
                            <a href="https://github.com/username/miniesass" class="text-decoration-none" target="_blank">
                                <i class="fab fa-github me-1"></i>GitHub
                            </a>
                        </p>
                    </div>
                </div>
            </div>
        </div>

    </div>

    <!-- Real-time Updates (WebSocket or polling) -->
    <div id="notification-container" class="position-fixed top-0 end-0 p-3" style="z-index: 1050;"></div>

    <!-- Scripts -->
    <script src="assets/js/bootstrap.bundle.min.js"></script>
    <script src="assets/js/chart.min.js"></script>
    <script src="assets/js/miniesass.js"></script>

    <script>
        // Auto-refresh for real-time updates
        document.addEventListener('DOMContentLoaded', function() {
            // Refresh page every 30 seconds to show updated job statuses
            setInterval(function() {
                // Only refresh if there are running jobs
                const runningJobs = document.querySelectorAll('.badge.bg-primary').length;
                if (runningJobs > 0) {
                    window.location.reload();
                }
            }, 30000);

            // Initialize tooltips
            var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
            var tooltipList = tooltipTriggerList.map(function(tooltipTriggerEl) {
                return new bootstrap.Tooltip(tooltipTriggerEl);
            });

            // Check for notifications
            checkForNotifications();
        });

        function checkForNotifications() {
            fetch('api/notifications.php')
                .then(response => response.json())
                .then(data => {
                    if (data.notifications && data.notifications.length > 0) {
                        showNotifications(data.notifications);
                    }
                })
                .catch(error => console.log('Notification check failed:', error));
        }

        function showNotifications(notifications) {
            const container = document.getElementById('notification-container');

            notifications.forEach(notification => {
                const toast = document.createElement('div');
                toast.className = `toast align-items-center text-white bg-${notification.type} border-0`;
                toast.setAttribute('role', 'alert');
                toast.innerHTML = `
            <div class="d-flex">
                <div class="toast-body">
                    <strong>${notification.title}</strong><br>
                    ${notification.message}
                </div>
                <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
            </div>
        `;

                container.appendChild(toast);

                const bsToast = new bootstrap.Toast(toast);
                bsToast.show();

                // Remove toast after it's hidden
                toast.addEventListener('hidden.bs.toast', () => {
                    toast.remove();
                });
            });
        }
    </script>

</body>

</html>