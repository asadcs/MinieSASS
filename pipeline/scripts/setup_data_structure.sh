#!/bin/bash
# =============================================================================
# setup_data_structure.sh - MinieSASS Data Directory Setup
# 
# Purpose: Create proper data directory structure for hybrid approach
# Author: Portfolio Project for MPE Software Engineer Position
# Date: July 2025
# =============================================================================

echo "=== MinieSASS Data Structure Setup ==="
echo "Setting up hybrid data approach (simulated + real)..."

# Create main data directories
mkdir -p data/{simulated,real,processed,logs,validation}

# Simulated data subdirectories
mkdir -p data/simulated/{raw,catalog,fits_files}
mkdir -p data/simulated/validation/{known_sources,expected_results}

# Real data subdirectories  
mkdir -p data/real/{chandra,xmm,other}
mkdir -p data/real/metadata

# Processing output directories
mkdir -p data/processed/{simulated,real}
mkdir -p data/processed/images/{field_maps,lightcurves,overlays}
mkdir -p data/processed/catalogs

# Logs and validation
mkdir -p data/logs/{pipeline,web,errors}
mkdir -p data/validation/{unit_tests,integration_tests}

# Create README files for each directory
cat > data/README.md << 'EOF'
# MinieSASS Data Directory Structure

## Hybrid Data Approach

### Simulated Data (Primary - 80%)
- `simulated/raw/` - Generated FITS files with known sources
- `simulated/catalog/` - Source catalogs with ground truth
- `simulated/validation/` - Expected results for pipeline validation

### Real Data (Secondary - 20%) 
- `real/chandra/` - Chandra X-ray Observatory FITS files
- `real/xmm/` - XMM-Newton observations
- `real/metadata/` - Observation logs and source information

### Processing Outputs
- `processed/simulated/` - Results from simulated data processing
- `processed/real/` - Results from real data processing  
- `processed/images/` - Generated visualizations (PNG, plots)
- `processed/catalogs/` - Detected source catalogs

### Validation & Logs
- `validation/` - Test results and accuracy metrics
- `logs/` - Pipeline execution logs and error reports

## Usage
1. Generate simulated data: `python generate_test_fits.py`
2. Download real data: `bash download_real_data.sh` 
3. Process data: `./pipeline_manager.sh <observation_id>`
4. View results: Open web interface at localhost/MinieSASS
EOF

cat > data/simulated/README.md << 'EOF'
# Simulated X-ray Data

## Purpose
Controlled test data with known source positions and fluxes for pipeline validation.

## Generated Files
- `TEST001_events.fits` - 5 point sources, mixed brightnesses
- `TEST002_events.fits` - 3 point sources, different field center
- `source_catalog.txt` - Ground truth source positions and fluxes

## Validation Approach
1. Process FITS files through calibration pipeline
2. Compare detected sources with known catalog
3. Measure position accuracy (arcsec RMS)
4. Measure photometry accuracy (% flux error)
5. Assess completeness and contamination rates

## File Format
Standard FITS binary table with columns:
- TIME, X, Y, RA, DEC, ENERGY, PI, GRADE, STATUS, FRAME, SRC_ID
EOF

cat > data/real/README.md << 'EOF'
# Real X-ray Observatory Data

## Purpose
Demonstrate pipeline capability on authentic astronomical observations.

## Data Sources
- **Chandra**: High-resolution X-ray imaging
- **XMM-Newton**: Large effective area observations
- **Selection criteria**: Well-studied sources, compact field size

## Limitations
- Pipeline not optimized for mission-specific calibrations
- Results are qualitative demonstrations, not scientific analyses
- Instrument response functions not included

## Processing Notes
Real data processing shows:
1. FITS file parsing capability
2. Basic source detection algorithms
3. Coordinate transformation accuracy
4. Web interface functionality with authentic data
EOF

cat > data/processed/README.md << 'EOF'
# Processing Results

## Output Structure
- `simulated/` - Validation results with accuracy metrics
- `real/` - Demonstration results from observatory data
- `images/` - Generated visualizations and field maps
- `catalogs/` - Source detection catalogs in various formats

## File Formats
- `.fits` - Processed event lists and images
- `.txt` - Source catalogs and parameter files
- `.png` - Field visualizations and diagnostic plots
- `.log` - Processing execution logs
EOF

# Create sample validation files
cat > data/simulated/validation/expected_results.txt << 'EOF'
# Expected Results for Pipeline Validation
# Format: OBS_ID  N_SOURCES  AVG_POSITION_ERROR_ARCSEC  AVG_FLUX_ERROR_PERCENT
TEST001  5  <2.0  <15.0
TEST002  3  <2.0  <15.0
EOF

cat > data/validation/acceptance_criteria.txt << 'EOF'
# MinieSASS Pipeline Acceptance Criteria

## Source Detection
- Completeness: >90% for sources with S/N > 5
- Contamination: <10% false positive rate
- Position accuracy: <2 arcsec RMS for bright sources

## Photometry  
- Flux accuracy: <15% for sources with >100 counts
- Background estimation: Within 2-sigma of true value

## Performance
- Processing time: <60 seconds for 10,000 events
- Memory usage: <1GB for typical observation

## Quality Assurance
- No pipeline crashes on valid FITS files
- Proper error handling for corrupted data
- Complete processing logs generated
EOF

# Set proper permissions
chmod -R 755 data/
chmod 644 data/*/README.md

echo "✅ Data directory structure created successfully!"
echo ""
echo "Directory tree:"
tree data/ 2>/dev/null || find data/ -type d | sort

echo ""
echo "Next steps:"
echo "1. Generate simulated FITS files: python generate_test_fits.py"
echo "2. Set up real data downloads: bash download_real_data.sh"
echo "3. Begin pipeline development with known test cases"
echo ""
echo "Structure ready for hybrid data approach! 🚀"