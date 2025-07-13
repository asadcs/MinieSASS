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
