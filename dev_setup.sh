#!/bin/bash
# MinieSASS Development Environment Helper

PROJECT_DIR="$HOME/MinieSASS"
WEB_DIR="/var/www/html/MinieSASS"

case "$1" in
    "start")
        echo "Starting MinieSASS development environment..."
        sudo systemctl start apache2
        echo "✅ Apache started"
        echo "🌐 Web interface: http://localhost/MinieSASS/"
        echo "📁 Project directory: $PROJECT_DIR"
        ;;
    "stop")
        echo "Stopping development environment..."
        sudo systemctl stop apache2
        echo "✅ Apache stopped"
        ;;
    "test")
        echo "Running system tests..."
        ./pipeline/scripts/test_hello.sh
        ;;
    "sync")
        echo "Syncing web files..."
        rsync -av "$PROJECT_DIR/web/" "$WEB_DIR/"
        echo "✅ Web files synced"
        ;;
    "status")
        echo "=== MinieSASS Development Status ==="
        echo "Apache: $(systemctl is-active apache2)"
        echo "Project: $PROJECT_DIR"
        echo "Web: $WEB_DIR"
        echo "URL: http://localhost/MinieSASS/"
        ;;
    *)
        echo "MinieSASS Development Helper"
        echo "Usage: $0 {start|stop|test|sync|status}"
        echo ""
        echo "Commands:"
        echo "  start  - Start Apache web server"
        echo "  stop   - Stop Apache web server"
        echo "  test   - Run system component tests"
        echo "  sync   - Sync web files to Apache directory"
        echo "  status - Show development environment status"
        ;;
esac
