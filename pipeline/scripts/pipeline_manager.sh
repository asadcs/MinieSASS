            #!/bin/bash
# =============================================================================
# pipeline_manager.sh - MinieSASS Pipeline Orchestration Script
# 
# Purpose: Orchestrate the complete X-ray data processing pipeline
#          from FITS input to final results
#
# Usage: ./pipeline_manager.sh <observation_id> [mode]
#        mode: simulated (default) | real
#
# Author: Portfolio Project for MPE Software Engineer Position
# Date: July 2025
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"  # Fixed: Go up two levels
PIPELINE_DIR="$PROJECT_ROOT/pipeline"
DATA_DIR="$PROJECT_ROOT/data"
WEB_DIR="$PROJECT_ROOT/web"

# Pipeline executables
FORTRAN_PIPELINE="$PIPELINE_DIR/fortran/pipeline_main"
FITS_GENERATOR="$PIPELINE_DIR/python/generate_test_fits.py"

# Default configuration
DEFAULT_MODE="simulated"
VERBOSE=1
LOG_LEVEL="INFO"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Utility Functions
# =============================================================================

log_info() {
    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_header() {
    echo ""
    echo "=============================================="
    echo "    MinieSASS Pipeline Manager"
    echo "    eROSITA-style X-ray Processing"
    echo "=============================================="
    echo ""
}

print_usage() {
    echo "Usage: $0 <observation_id> [mode]"
    echo ""
    echo "Arguments:"
    echo "  observation_id    Observation identifier (e.g., TEST001, TEST002)"
    echo "  mode             Processing mode: simulated (default) | real"
    echo ""
    echo "Examples:"
    echo "  $0 TEST001                    # Process simulated observation TEST001"
    echo "  $0 TEST002 simulated          # Process simulated observation TEST002"
    echo "  $0 chandra_obs real           # Process real data observation"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -v, --verbose    Enable verbose output"
    echo "  -q, --quiet      Suppress non-essential output"
    echo ""
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    # Debug: Print paths being checked
    log_info "PROJECT_ROOT: $PROJECT_ROOT"
    log_info "FORTRAN_PIPELINE: $FORTRAN_PIPELINE"
    
    # Check if Fortran pipeline is compiled
    if [[ ! -x "$FORTRAN_PIPELINE" ]]; then
        log_error "Fortran pipeline not found or not executable: $FORTRAN_PIPELINE"
        log_info "Compile with: cd $PIPELINE_DIR/fortran && gfortran -o pipeline_main calibration_core.f90 pipeline_main.f90"
        return 1
    fi
    
    # Check if Python is available for FITS generation
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 not found. Required for FITS file generation."
        return 1
    fi
    
    # Check if required Python packages are available
    if ! python3 -c "import astropy" &> /dev/null; then
        log_warning "Astropy not available. Some features may not work."
    fi
    
    # Check directory structure
    for dir in "$DATA_DIR/simulated" "$DATA_DIR/real" "$DATA_DIR/processed" "$DATA_DIR/logs"; do
        if [[ ! -d "$dir" ]]; then
            log_info "Creating directory: $dir"
            mkdir -p "$dir"
        fi
    done
    
    log_success "Dependencies check passed"
    return 0
}

# =============================================================================
# Data Management Functions
# =============================================================================

find_input_file() {
    local obs_id="$1"
    local mode="$2"
    local input_file=""
    
    if [[ "$mode" == "simulated" ]]; then
        # Look for simulated data - corrected path
        input_file="$DATA_DIR/simulated/raw/${obs_id}_events.fits"
        
        if [[ ! -f "$input_file" ]]; then
            log_error "Simulated FITS file not found: $input_file"
            log_info "Available files:"
            ls -la "$DATA_DIR/simulated/raw/" 2>/dev/null || log_warning "Directory not found"
            return 1
        fi
        
    elif [[ "$mode" == "real" ]]; then
        # Look for real data
        for ext in fits fit fts; do
            for subdir in chandra xmm other; do
                candidate="$DATA_DIR/real/$subdir/${obs_id}.$ext"
                if [[ -f "$candidate" ]]; then
                    input_file="$candidate"
                    break 2
                fi
            done
        done
        
        if [[ -z "$input_file" ]]; then
            log_error "Real data file not found for observation: $obs_id"
            log_info "Expected locations:"
            log_info "  $DATA_DIR/real/chandra/${obs_id}.fits"
            log_info "  $DATA_DIR/real/xmm/${obs_id}.fits"
            log_info "  $DATA_DIR/real/other/${obs_id}.fits"
            return 1
        fi
        
    else
        log_error "Unknown processing mode: $mode"
        return 1
    fi
    
    echo "$input_file"
    return 0
}

# =============================================================================
# Pipeline Execution Functions
# =============================================================================

run_calibration_pipeline() {
    local input_file="$1"
    local obs_id="$2"
    local mode="$3"
    
    log_info "Running calibration pipeline..."
    log_info "Input file: $input_file"
    log_info "Observation ID: $obs_id"
    log_info "Mode: $mode"
    
    # Set up environment
    export OMP_NUM_THREADS=1  # Single-threaded for now
    
    # Create processing directory
    local proc_dir="$DATA_DIR/processed/$mode"
    mkdir -p "$proc_dir"
    
    # Set up logging
    local log_file="$DATA_DIR/logs/${obs_id}_$(date +%Y%m%d_%H%M%S).log"
    
    log_info "Pipeline log: $log_file"
    
    # Run the Fortran calibration pipeline
    cd "$proc_dir"
    
    if "$FORTRAN_PIPELINE" "$input_file" "$obs_id" 2>&1 | tee "$log_file"; then
        log_success "Calibration pipeline completed successfully"
        
        # Check for output files
        if [[ -f "${obs_id}_sources.txt" ]]; then
            log_success "Source catalog generated: ${obs_id}_sources.txt"
            
            # Count detected sources
            local n_sources=$(grep -v '^#' "${obs_id}_sources.txt" | wc -l)
            log_info "Detected sources: $n_sources"
        fi
        
        if [[ -f "${obs_id}_processing.log" ]]; then
            log_success "Processing log generated: ${obs_id}_processing.log"
        fi
        
        return 0
    else
        log_error "Calibration pipeline failed"
        return 1
    fi
}

validate_results() {
    local obs_id="$1"
    local mode="$2"
    
    if [[ "$mode" != "simulated" ]]; then
        log_info "Skipping validation for non-simulated data"
        return 0
    fi
    
    log_info "Validating results against known sources..."
    
    local catalog_file="$DATA_DIR/processed/$mode/${obs_id}_sources.txt"
    local reference_file="$DATA_DIR/simulated/source_catalog.txt"
    
    if [[ ! -f "$catalog_file" ]]; then
        log_error "Output catalog not found: $catalog_file"
        return 1
    fi
    
    if [[ ! -f "$reference_file" ]]; then
        log_warning "Reference catalog not found: $reference_file"
        return 0
    fi
    
    # Simple validation: check if we detected the expected number of sources
    local detected_sources=$(grep -v '^#' "$catalog_file" | wc -l)
    local expected_sources=$(grep "^$obs_id" "$reference_file" | wc -l)
    
    log_info "Expected sources: $expected_sources"
    log_info "Detected sources: $detected_sources"
    
    if [[ $detected_sources -eq $expected_sources ]]; then
        log_success "Source count validation passed"
    elif [[ $detected_sources -gt 0 ]]; then
        log_warning "Source count mismatch (expected: $expected_sources, detected: $detected_sources)"
    else
        log_error "No sources detected (expected: $expected_sources)"
        return 1
    fi
    
    return 0
}

update_web_database() {
    local obs_id="$1"
    local mode="$2"
    local status="$3"
    
    log_info "Updating web database..."
    
    # Create simple database entry
    local db_file="$DATA_DIR/logs/web_database.txt"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "$timestamp|$obs_id|$mode|$status" >> "$db_file"
    
    # Copy results to web-accessible location
    if [[ "$status" == "SUCCESS" ]]; then
        local web_results_dir="$WEB_DIR/results"
        mkdir -p "$web_results_dir"
        
        local proc_dir="$DATA_DIR/processed/$mode"
        if [[ -f "$proc_dir/${obs_id}_sources.txt" ]]; then
            cp "$proc_dir/${obs_id}_sources.txt" "$web_results_dir/"
            log_info "Results copied to web directory"
        fi
    fi
}

generate_summary_report() {
    local obs_id="$1"
    local mode="$2"
    
    log_info "Generating summary report..."
    
    local report_file="$DATA_DIR/processed/$mode/${obs_id}_summary.txt"
    local proc_log="$DATA_DIR/processed/$mode/${obs_id}_processing.log"
    
    {
        echo "=== MinieSASS Processing Summary ==="
        echo "Observation ID: $obs_id"
        echo "Processing Mode: $mode"
        echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        echo ""
        
        if [[ -f "$proc_log" ]]; then
            echo "=== Pipeline Results ==="
            cat "$proc_log"
            echo ""
        fi
        
        local catalog_file="$DATA_DIR/processed/$mode/${obs_id}_sources.txt"
        if [[ -f "$catalog_file" ]]; then
            echo "=== Source Detection Summary ==="
            echo "Total sources detected: $(grep -v '^#' "$catalog_file" | wc -l)"
            echo ""
            echo "Source catalog preview:"
            head -n 20 "$catalog_file"
        fi
        
    } > "$report_file"
    
    log_success "Summary report generated: $report_file"
}

# =============================================================================
# Main Processing Function
# =============================================================================

process_observation() {
    local obs_id="$1"
    local mode="$2"
    
    log_info "Starting processing for observation: $obs_id (mode: $mode)"
    
    # Find input file
    local input_file
    if ! input_file=$(find_input_file "$obs_id" "$mode"); then
        return 1
    fi
    
    log_success "Input file found: $input_file"
    
    # Run calibration pipeline
    if ! run_calibration_pipeline "$input_file" "$obs_id" "$mode"; then
        update_web_database "$obs_id" "$mode" "FAILED"
        return 1
    fi
    
    # Validate results (for simulated data)
    if ! validate_results "$obs_id" "$mode"; then
        log_warning "Validation failed, but continuing..."
    fi
    
    # Generate summary report
    generate_summary_report "$obs_id" "$mode"
    
    # Update web database
    update_web_database "$obs_id" "$mode" "SUCCESS"
    
    log_success "Processing completed successfully for observation: $obs_id"
    return 0
}

# =============================================================================
# Main Script Logic
# =============================================================================

main() {
    # Parse command line arguments
    local obs_id=""
    local mode="$DEFAULT_MODE"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -q|--quiet)
                VERBOSE=0
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
            *)
                if [[ -z "$obs_id" ]]; then
                    obs_id="$1"
                elif [[ -z "$mode" || "$mode" == "$DEFAULT_MODE" ]]; then
                    mode="$1"
                else
                    log_error "Too many arguments"
                    print_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate arguments
    if [[ -z "$obs_id" ]]; then
        log_error "Observation ID is required"
        print_usage
        exit 1
    fi
    
    if [[ "$mode" != "simulated" && "$mode" != "real" ]]; then
        log_error "Invalid mode: $mode (must be 'simulated' or 'real')"
        print_usage
        exit 1
    fi
    
    # Print header
    print_header
    
    # Check dependencies
    if ! check_dependencies; then
        log_error "Dependency check failed"
        exit 1
    fi
    
    # Process the observation
    if process_observation "$obs_id" "$mode"; then
        echo ""
        log_success "Pipeline execution completed successfully!"
        echo ""
        echo "Results available in:"
        echo "  Data: $DATA_DIR/processed/$mode/"
        echo "  Logs: $DATA_DIR/logs/"
        echo "  Web:  $WEB_DIR/results/"
        echo ""
    else
        echo ""
        log_error "Pipeline execution failed!"
        echo ""
        echo "Check logs in: $DATA_DIR/logs/"
        exit 1
    fi
}

# =============================================================================
# Script Entry Point
# =============================================================================

# Ensure we're in the right directory
cd "$PROJECT_ROOT"

# Run main function
main "$@"