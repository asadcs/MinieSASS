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
