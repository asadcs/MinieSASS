#!/usr/bin/env python3
"""
generate_test_fits.py - MinieSASS Test Data Generator

Purpose: Generate realistic eROSITA-style FITS files with simulated X-ray events
         for testing the calibration pipeline

Features:
- Realistic X-ray event tables with proper columns
- Simulated point sources with known positions and fluxes
- Background events with Poisson statistics
- Proper FITS headers with WCS information
- Multiple energy bands and detector effects

Author: Portfolio Project for MPE Software Engineer Position
Date: July 2025
"""

import numpy as np

try:
    import matplotlib.pyplot as plt
    from astropy.io import fits
    from astropy import wcs
    from astropy.time import Time
    from astropy.coordinates import SkyCoord
    import astropy.units as u
except ImportError as e:
    print(f"Missing required packages: {e}")
    print("Install with: pip install astropy matplotlib")
    exit(1)

from datetime import datetime
import os
import sys


class XRayEventSimulator:
    """Simulate eROSITA-style X-ray event data"""

    def __init__(self, obs_id="TEST001"):
        self.obs_id = obs_id
        self.detector_size = (384, 384)  # eROSITA-like CCD size
        self.pixel_scale = 4.1  # arcsec per pixel (eROSITA-like)
        self.exposure_time = 1000.0  # seconds

        # Energy calibration (simplified)
        self.energy_gain = 0.005  # keV per channel
        self.energy_offset = 0.2  # keV
        self.energy_range = (0.2, 10.0)  # keV

        # Background rate (counts/s/pixel)
        self.background_rate = 1e-4

        # Initialize random seed for reproducible results
        np.random.seed(42)

    def create_simple_events(self, sources, ra_center=30.0, dec_center=10.0):
        """Create simple event list without complex WCS (fallback method)"""

        all_det_x = []
        all_det_y = []
        all_times = []
        all_energies = []
        all_source_ids = []
        all_ra = []
        all_dec = []

        print(f"Simulating {len(sources)} point sources...")

        # Simulate each source
        for i, (ra, dec, flux) in enumerate(sources):
            # Convert RA/DEC to detector pixels (simple linear mapping)
            det_x = 192 + (ra - ra_center) * 3600 / self.pixel_scale
            det_y = 192 + (dec - dec_center) * 3600 / self.pixel_scale

            # Total expected counts
            total_counts = int(np.random.poisson(flux * self.exposure_time))

            if total_counts > 0:
                # PSF spread (2 pixel sigma)
                source_x = np.random.normal(det_x, 2.0, total_counts)
                source_y = np.random.normal(det_y, 2.0, total_counts)

                # Random times
                times = np.random.uniform(0, self.exposure_time, total_counts)

                # Simple energy spectrum
                energies = np.random.exponential(1.5, total_counts) + 0.5
                energies = np.clip(energies, 0.2, 10.0)

                # Convert back to RA/DEC
                ra_vals = ra_center + (source_x - 192) * self.pixel_scale / 3600
                dec_vals = dec_center + (source_y - 192) * self.pixel_scale / 3600

                all_det_x.extend(source_x)
                all_det_y.extend(source_y)
                all_times.extend(times)
                all_energies.extend(energies)
                all_ra.extend(ra_vals)
                all_dec.extend(dec_vals)
                all_source_ids.extend([i + 1] * total_counts)

                print(
                    f"  Source {i+1}: RA={ra:.2f}°, DEC={dec:.2f}°, "
                    f"Flux={flux:.3f} cts/s → {total_counts} events"
                )

        # Add background
        bg_counts = int(
            np.random.poisson(self.background_rate * 384 * 384 * self.exposure_time)
        )
        if bg_counts > 0:
            bg_x = np.random.uniform(0, 384, bg_counts)
            bg_y = np.random.uniform(0, 384, bg_counts)
            bg_times = np.random.uniform(0, self.exposure_time, bg_counts)
            bg_energies = np.random.uniform(0.2, 10.0, bg_counts)
            bg_ra = ra_center + (bg_x - 192) * self.pixel_scale / 3600
            bg_dec = dec_center + (bg_y - 192) * self.pixel_scale / 3600

            all_det_x.extend(bg_x)
            all_det_y.extend(bg_y)
            all_times.extend(bg_times)
            all_energies.extend(bg_energies)
            all_ra.extend(bg_ra)
            all_dec.extend(bg_dec)
            all_source_ids.extend([0] * bg_counts)

            print(f"  Background: {bg_counts} events")

        # Convert to numpy arrays and sort by time
        all_det_x = np.array(all_det_x)
        all_det_y = np.array(all_det_y)
        all_times = np.array(all_times)
        all_energies = np.array(all_energies)
        all_ra = np.array(all_ra)
        all_dec = np.array(all_dec)
        all_source_ids = np.array(all_source_ids)

        # Sort by time
        time_order = np.argsort(all_times)

        return {
            "det_x": all_det_x[time_order],
            "det_y": all_det_y[time_order],
            "time": all_times[time_order],
            "energy": all_energies[time_order],
            "ra": all_ra[time_order],
            "dec": all_dec[time_order],
            "source_id": all_source_ids[time_order],
        }

    def add_realistic_columns(self, events):
        """Add additional realistic eROSITA-like columns"""

        n_events = len(events["time"])

        # PI channels (energy to integer channels)
        events["pi"] = np.round(
            (events["energy"] - self.energy_offset) / self.energy_gain
        ).astype(int)
        events["pi"] = np.clip(events["pi"], 0, 4095)  # 12-bit ADC

        # Event grades (simplified pattern recognition)
        grade_probs = [0.7, 0.2, 0.05, 0.03, 0.02]  # Probability distribution
        events["grade"] = np.random.choice(5, n_events, p=grade_probs)

        # Quality flags (most events are good)
        events["status"] = np.random.choice(
            [0, 1], n_events, p=[0.95, 0.05]
        )  # 0=good, 1=bad

        # Frame time (CCD readout)
        events["frame"] = (events["time"] / 2.6).astype(int)  # 2.6s frame time

        return events

    def write_fits_file(self, events, filename, ra_center=30.0, dec_center=10.0):
        """Write events to FITS file with proper headers"""

        print(f"Writing {len(events['time'])} events to {filename}")

        # Create primary HDU with observation info
        primary_hdu = fits.PrimaryHDU()

        # Add observation metadata
        primary_hdu.header["TELESCOP"] = "eROSITA-SIM"
        primary_hdu.header["INSTRUME"] = "TM1"  # Telescope Module 1
        primary_hdu.header["OBS_ID"] = self.obs_id
        primary_hdu.header["OBJECT"] = "Simulated Field"
        primary_hdu.header["RA_NOM"] = ra_center
        primary_hdu.header["DEC_NOM"] = dec_center
        primary_hdu.header["EXPOSURE"] = self.exposure_time
        primary_hdu.header["TSTART"] = 0.0
        primary_hdu.header["TSTOP"] = self.exposure_time
        primary_hdu.header["DATE-OBS"] = datetime.now().isoformat()
        primary_hdu.header["CREATOR"] = "MinieSASS Test Data Generator"

        # Create columns for event table
        cols = []
        cols.append(
            fits.Column(name="TIME", format="D", array=events["time"], unit="s")
        )
        cols.append(
            fits.Column(name="X", format="E", array=events["det_x"], unit="pixel")
        )
        cols.append(
            fits.Column(name="Y", format="E", array=events["det_y"], unit="pixel")
        )
        cols.append(fits.Column(name="RA", format="D", array=events["ra"], unit="deg"))
        cols.append(
            fits.Column(name="DEC", format="D", array=events["dec"], unit="deg")
        )
        cols.append(
            fits.Column(name="ENERGY", format="E", array=events["energy"], unit="keV")
        )
        cols.append(
            fits.Column(name="PI", format="I", array=events["pi"], unit="channel")
        )
        cols.append(fits.Column(name="GRADE", format="I", array=events["grade"]))
        cols.append(fits.Column(name="STATUS", format="I", array=events["status"]))
        cols.append(fits.Column(name="FRAME", format="J", array=events["frame"]))
        cols.append(fits.Column(name="SRC_ID", format="I", array=events["source_id"]))

        # Create binary table HDU
        events_hdu = fits.BinTableHDU.from_columns(cols, name="EVENTS")
        events_hdu.header["EXTNAME"] = "EVENTS"
        events_hdu.header["HDUCLASS"] = "OGIP"
        events_hdu.header["HDUCLAS1"] = "EVENTS"
        events_hdu.header["TLMIN1"] = 0.0
        events_hdu.header["TLMAX1"] = self.exposure_time

        # Create HDU list and write
        hdul = fits.HDUList([primary_hdu, events_hdu])
        hdul.writeto(filename, overwrite=True)

        print(f"FITS file written successfully: {filename}")
        return filename


def create_test_observations():
    """Create a set of test observations with known sources"""

    observations = [
        {
            "obs_id": "TEST001",
            "ra_center": 30.0,
            "dec_center": 10.0,
            "sources": [
                (30.05, 10.03, 0.150),  # Bright source
                (29.95, 10.08, 0.080),  # Medium source
                (30.08, 9.92, 0.040),  # Faint source
                (29.92, 9.95, 0.025),  # Very faint source
                (30.02, 10.15, 0.200),  # Brightest source
            ],
        },
        {
            "obs_id": "TEST002",
            "ra_center": 45.0,
            "dec_center": -5.0,
            "sources": [
                (45.03, -4.97, 0.120),  # Medium brightness
                (44.98, -5.05, 0.060),  # Fainter source
                (45.12, -4.88, 0.180),  # Bright source
            ],
        },
    ]

    return observations


def main():
    """Generate test FITS files for MinieSASS pipeline"""

    print("=== MinieSASS FITS Test Data Generator ===")
    print("Generating eROSITA-style simulated X-ray observations...\n")

    # Create output directory
    output_dir = "data/simulated/raw"
    os.makedirs(output_dir, exist_ok=True)

    # Generate test observations
    observations = create_test_observations()

    generated_files = []

    for obs_config in observations:
        print(f"\n--- Generating Observation {obs_config['obs_id']} ---")
        print(
            f"Field center: RA={obs_config['ra_center']:.1f}°, DEC={obs_config['dec_center']:.1f}°"
        )
        print(f"Sources: {len(obs_config['sources'])}")

        # Create simulator instance
        simulator = XRayEventSimulator(obs_config["obs_id"])

        # Generate event list (simplified method)
        events = simulator.create_simple_events(
            obs_config["sources"], obs_config["ra_center"], obs_config["dec_center"]
        )

        # Add realistic detector columns
        events = simulator.add_realistic_columns(events)

        # Write FITS file
        filename = os.path.join(output_dir, f"{obs_config['obs_id']}_events.fits")
        simulator.write_fits_file(
            events, filename, obs_config["ra_center"], obs_config["dec_center"]
        )

        generated_files.append(filename)

        # Print summary statistics
        total_events = len(events["time"])
        source_events = np.sum(events["source_id"] > 0)
        bg_events = np.sum(events["source_id"] == 0)

        print(f"Event summary:")
        print(f"  Total events: {total_events}")
        print(
            f"  Source events: {source_events} ({100*source_events/total_events:.1f}%)"
        )
        print(f"  Background events: {bg_events} ({100*bg_events/total_events:.1f}%)")
        print(
            f"  Energy range: {events['energy'].min():.2f} - {events['energy'].max():.2f} keV"
        )

    # Create source catalog file for validation
    catalog_file = os.path.join("data/simulated", "source_catalog.txt")
    with open(catalog_file, "w") as f:
        f.write("# MinieSASS Test Source Catalog\n")
        f.write("# Format: OBS_ID  SOURCE_ID  RA_DEG  DEC_DEG  FLUX_CTS_PER_SEC\n")

        for obs_config in observations:
            for i, (ra, dec, flux) in enumerate(obs_config["sources"]):
                f.write(
                    f"{obs_config['obs_id']}  {i+1:2d}  {ra:8.4f}  {dec:8.4f}  {flux:8.4f}\n"
                )

    print(f"\n=== Generation Complete ===")
    print(f"Generated {len(generated_files)} FITS files:")
    for filename in generated_files:
        print(f"  {filename}")
    print(f"Source catalog: {catalog_file}")
    print("\nFiles ready for pipeline testing!")


if __name__ == "__main__":
    main()
