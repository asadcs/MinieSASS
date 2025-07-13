! =============================================================================
! pipeline_main.f90 - MinieSASS Main Calibration Pipeline
! 
! Purpose: Main program for eROSITA-style X-ray data calibration pipeline
!          Orchestrates the complete data processing workflow
!
! Usage: ./pipeline_main <input_fits_file> [output_prefix]
!
! Author: Portfolio Project for MPE Software Engineer Position  
! Date: July 2025
! =============================================================================

program pipeline_main
    use calibration_core
    implicit none
    
    ! Command line arguments
    character(len=200) :: input_filename, output_prefix, arg
    integer :: num_args
    
    ! Data structures
    type(observation_header) :: obs_header
    type(photon_event), allocatable :: events(:)
    type(detected_source), allocatable :: sources(:)
    type(processing_results) :: results
    
    ! Processing variables
    integer :: n_events, n_filtered, n_sources
    integer :: status, i
    real(dp) :: background_rate, processing_start, processing_end
    character(len=100) :: timestamp
    
    ! Initialize
    call cpu_time(processing_start)
    call initialize_calibration_core()
    
    write(*,*) ''
    write(*,*) '=============================================='
    write(*,*) '    MinieSASS X-ray Calibration Pipeline'
    write(*,*) '    eROSITA-style Data Processing System'
    write(*,*) '=============================================='
    write(*,*) ''
    
    ! Parse command line arguments
    num_args = command_argument_count()
    
    if (num_args < 1) then
        write(*,*) 'Usage: ./pipeline_main <input_fits_file> [output_prefix]'
        write(*,*) 'Example: ./pipeline_main data/simulated/TEST001_events.fits TEST001'
        stop 1
    end if
    
    call get_command_argument(1, input_filename)
    
    if (num_args >= 2) then
        call get_command_argument(2, output_prefix)
    else
        ! Generate output prefix from input filename
        output_prefix = 'output'
        if (index(input_filename, 'TEST001') > 0) output_prefix = 'TEST001'
        if (index(input_filename, 'TEST002') > 0) output_prefix = 'TEST002'
    end if
    
    write(*,*) 'Input file: ', trim(input_filename)
    write(*,*) 'Output prefix: ', trim(output_prefix)
    write(*,*) ''
    
    ! Initialize processing results
    results%n_events_input = 0
    results%n_events_filtered = 0  
    results%n_events_calibrated = 0
    results%n_sources_detected = 0
    results%background_rate = 0.0d0
    results%exposure_effective = 0.0d0
    results%processing_success = .false.
    results%error_message = ''
    
    ! ==========================================================================
    ! Step 1: Load FITS file and read header
    ! ==========================================================================
    
    write(*,*) 'Step 1: Reading FITS file header...'
    
    call read_fits_header(input_filename, obs_header, status)
    
    if (status /= 0) then
        results%error_message = 'Failed to read FITS header'
        call write_error_log(results%error_message, status)
        stop 1
    end if
    
    call print_observation_info(obs_header)
    
    ! ==========================================================================
    ! Step 2: Load event data
    ! ==========================================================================
    
    write(*,*) 'Step 2: Loading photon event data...'
    
    ! Allocate memory for events
    allocate(events(MAX_EVENTS))
    
    call load_event_data(input_filename, events, n_events, MAX_EVENTS, status)
    
    if (status /= 0 .or. n_events == 0) then
        results%error_message = 'Failed to load event data'
        call write_error_log(results%error_message, status)
        deallocate(events)
        stop 1
    end if
    
    results%n_events_input = n_events
    write(*,*) 'Loaded ', n_events, ' photon events'
    write(*,*) ''
    
    ! ==========================================================================
    ! Step 3: Apply quality filtering
    ! ==========================================================================
    
    write(*,*) 'Step 3: Applying quality filters...'
    
    call apply_quality_filters(events, n_events, n_filtered)
    results%n_events_filtered = n_filtered
    
    if (n_filtered == 0) then
        results%error_message = 'No events passed quality filtering'
        call write_error_log(results%error_message, 0)
        deallocate(events)
        stop 1
    end if
    
    write(*,*) ''
    
    ! ==========================================================================
    ! Step 4: Energy calibration and coordinate transformation
    ! ==========================================================================
    
    write(*,*) 'Step 4: Applying energy calibration...'
    
    call apply_energy_calibration(events, n_events)
    results%n_events_calibrated = n_filtered
    
    write(*,*) 'Energy calibration applied to ', n_filtered, ' events'
    write(*,*) ''
    
    ! ==========================================================================
    ! Step 5: Background estimation
    ! ==========================================================================
    
    write(*,*) 'Step 5: Estimating background...'
    
    call estimate_global_background(events, n_events, background_rate)
    results%background_rate = background_rate
    results%exposure_effective = obs_header%exposure_time
    
    write(*,*) ''
    
    ! ==========================================================================
    ! Step 6: Source detection
    ! ==========================================================================
    
    write(*,*) 'Step 6: Detecting X-ray sources...'
    
    allocate(sources(MAX_SOURCES))
    
    call detect_sources(events, n_events, background_rate, sources, n_sources)
    results%n_sources_detected = n_sources
    
    if (n_sources > 0) then
        write(*,*) 'Detected ', n_sources, ' X-ray sources'
        call print_source_catalog(sources, n_sources)
    else
        write(*,*) 'No significant sources detected'
    end if
    
    write(*,*) ''
    
    ! ==========================================================================
    ! Step 7: Write output files
    ! ==========================================================================
    
    write(*,*) 'Step 7: Writing output files...'
    
    call write_output_files(output_prefix, obs_header, events, n_events, &
                           sources, n_sources, results)
    
    write(*,*) 'Output files written with prefix: ', trim(output_prefix)
    write(*,*) ''
    
    ! ==========================================================================
    ! Step 8: Processing summary
    ! ==========================================================================
    
    call cpu_time(processing_end)
    results%processing_success = .true.
    
    write(*,*) '=============================================='
    write(*,*) '           PROCESSING SUMMARY'
    write(*,*) '=============================================='
    write(*,*) 'Observation ID: ', trim(obs_header%obs_id)
    write(*,*) 'Input events: ', results%n_events_input
    write(*,*) 'Filtered events: ', results%n_events_filtered
    write(*,*) 'Sources detected: ', results%n_sources_detected
    write(*,*) 'Background rate: ', results%background_rate, ' cts/s/arcsec²'
    write(*,*) 'Processing time: ', processing_end - processing_start, ' seconds'
    write(*,*) 'Status: SUCCESS'
    write(*,*) '=============================================='
    write(*,*) ''
    
    ! Update processing database
    call update_processing_database(obs_header%obs_id, results)
    
    ! Cleanup
    deallocate(events)
    deallocate(sources)
    
    write(*,*) 'Pipeline completed successfully!'
    
contains

    ! ==========================================================================
    ! Supporting Subroutines
    ! ==========================================================================
    
    subroutine print_observation_info(obs_header)
        ! Print observation metadata
        implicit none
        type(observation_header), intent(in) :: obs_header
        
        write(*,*) '--- Observation Information ---'
        write(*,*) 'Observation ID: ', trim(obs_header%obs_id)
        write(*,*) 'Telescope: ', trim(obs_header%telescop)
        write(*,*) 'Instrument: ', trim(obs_header%instrume)
        write(*,*) 'Pointing: RA =', obs_header%pointing_ra, '°, DEC =', obs_header%pointing_dec, '°'
        write(*,*) 'Roll angle: ', obs_header%roll_angle, '°'
        write(*,*) 'Exposure time: ', obs_header%exposure_time, ' s'
        write(*,*) 'Start time (MJD): ', obs_header%start_time
        write(*,*) '-----------------------------'
        write(*,*) ''
        
    end subroutine print_observation_info
    
    subroutine apply_energy_calibration(events, n_events)
        ! Apply energy calibration to event list
        implicit none
        type(photon_event), intent(inout) :: events(:)
        integer, intent(in) :: n_events
        
        integer :: i, calibrated_count
        real(dp) :: corrected_energy
        
        calibrated_count = 0
        
        do i = 1, n_events
            if (events(i)%valid) then
                ! Apply gain and offset correction
                corrected_energy = events(i)%pi_channel * detector%gain + detector%offset
                
                ! Update energy if reasonable
                if (corrected_energy > 0.1d0 .and. corrected_energy < 15.0d0) then
                    events(i)%energy = corrected_energy
                    calibrated_count = calibrated_count + 1
                else
                    events(i)%valid = .false.  ! Mark as bad energy
                end if
            end if
        end do
        
        write(*,*) 'Energy calibration applied to ', calibrated_count, ' events'
        
    end subroutine apply_energy_calibration
    
    subroutine detect_sources(events, n_events, background_rate, sources, n_sources)
        ! Simple source detection algorithm
        implicit none
        type(photon_event), intent(in) :: events(:)
        integer, intent(in) :: n_events
        real(dp), intent(in) :: background_rate
        type(detected_source), intent(out) :: sources(:)
        integer, intent(out) :: n_sources
        
        ! Detection parameters
        real(dp), parameter :: detection_threshold = 3.0d0  ! sigma
        real(dp), parameter :: source_radius = 10.0d0       ! arcsec
        integer, parameter :: min_counts = 3
        
        ! Grid search parameters
        integer, parameter :: grid_size = 20  ! Grid points per dimension
        real(dp) :: grid_step_ra, grid_step_dec
        real(dp) :: grid_ra_min, grid_ra_max, grid_dec_min, grid_dec_max
        
        ! Working variables
        integer :: i, j, k, counts_in_circle
        real(dp) :: test_ra, test_dec, distance
        real(dp) :: expected_bg, significance
        real(dp) :: total_flux, flux_error
        
        n_sources = 0
        
        ! Determine search grid based on valid events
        call determine_search_grid(events, n_events, grid_ra_min, grid_ra_max, &
                                  grid_dec_min, grid_dec_max)
        
        grid_step_ra = (grid_ra_max - grid_ra_min) / real(grid_size)
        grid_step_dec = (grid_dec_max - grid_dec_min) / real(grid_size)
        
        write(*,*) 'Source detection grid:'
        write(*,*) '  RA range: ', grid_ra_min, ' to ', grid_ra_max, '°'
        write(*,*) '  DEC range: ', grid_dec_min, ' to ', grid_dec_max, '°'
        write(*,*) '  Grid step: ', grid_step_ra, '° x ', grid_step_dec, '°'
        
        ! Grid search for sources
        do i = 1, grid_size
            do j = 1, grid_size
                test_ra = grid_ra_min + (i-1) * grid_step_ra
                test_dec = grid_dec_min + (j-1) * grid_step_dec
                
                ! Count events within source radius
                counts_in_circle = 0
                total_flux = 0.0d0
                
                do k = 1, n_events
                    if (events(k)%valid) then
                        distance = calculate_distance(test_ra, test_dec, &
                                                    events(k)%ra, events(k)%dec)
                        
                        if (distance <= source_radius) then
                            counts_in_circle = counts_in_circle + 1
                        end if
                    end if
                end do
                
                ! Calculate expected background in source circle
                expected_bg = background_rate * PI * (source_radius**2) * 1000.0d0  ! 1000s exposure
                
                ! Calculate significance (simple Poisson)
                if (expected_bg > 0.0d0) then
                    significance = (counts_in_circle - expected_bg) / sqrt(expected_bg)
                else
                    significance = 0.0d0
                end if
                
                ! Check detection criteria
                if (significance >= detection_threshold .and. &
                    counts_in_circle >= min_counts .and. &
                    n_sources < MAX_SOURCES) then
                    
                    n_sources = n_sources + 1
                    
                    ! Fill source information
                    sources(n_sources)%source_id = n_sources
                    sources(n_sources)%ra = test_ra
                    sources(n_sources)%dec = test_dec
                    sources(n_sources)%total_counts = counts_in_circle
                    sources(n_sources)%net_counts = counts_in_circle - int(expected_bg)
                    sources(n_sources)%flux = real(counts_in_circle) / 1000.0d0  ! cts/s
                    sources(n_sources)%flux_error = sqrt(real(counts_in_circle)) / 1000.0d0
                    sources(n_sources)%significance = significance
                    sources(n_sources)%background = background_rate
                    sources(n_sources)%snr = significance
                    sources(n_sources)%extended = .false.
                    sources(n_sources)%valid = .true.
                    
                    ! Convert to detector coordinates
                    call sky_to_detector(test_ra, test_dec, &
                                        sources(n_sources)%det_x, &
                                        sources(n_sources)%det_y)
                    
                end if
            end do
        end do
        
        write(*,*) 'Grid search completed: ', n_sources, ' sources detected'
        
    end subroutine detect_sources
    
    subroutine determine_search_grid(events, n_events, ra_min, ra_max, dec_min, dec_max)
        ! Determine search boundaries from valid event coordinates
        implicit none
        type(photon_event), intent(in) :: events(:)
        integer, intent(in) :: n_events
        real(dp), intent(out) :: ra_min, ra_max, dec_min, dec_max
        
        integer :: i, valid_count
        real(dp) :: margin
        
        ! Initialize with extreme values
        ra_min = 999.0d0
        ra_max = -999.0d0
        dec_min = 999.0d0
        dec_max = -999.0d0
        valid_count = 0
        
        ! Find coordinate bounds from valid events
        do i = 1, n_events
            if (events(i)%valid) then
                ra_min = min(ra_min, events(i)%ra)
                ra_max = max(ra_max, events(i)%ra)
                dec_min = min(dec_min, events(i)%dec)
                dec_max = max(dec_max, events(i)%dec)
                valid_count = valid_count + 1
            end if
        end do
        
        ! Add small margin
        margin = 0.01d0  ! degrees
        ra_min = ra_min - margin
        ra_max = ra_max + margin
        dec_min = dec_min - margin
        dec_max = dec_max + margin
        
        write(*,*) 'Search grid determined from ', valid_count, ' valid events'
        
    end subroutine determine_search_grid
    
    subroutine print_source_catalog(sources, n_sources)
        ! Print detected source catalog
        implicit none
        type(detected_source), intent(in) :: sources(:)
        integer, intent(in) :: n_sources
        
        integer :: i
        
        write(*,*) ''
        write(*,*) '--- DETECTED SOURCE CATALOG ---'
        write(*,*) 'ID    RA(deg)    DEC(deg)   Flux(cts/s)  Sigma  Counts'
        write(*,*) '----------------------------------------------------'
        
        do i = 1, n_sources
            if (sources(i)%valid) then
                write(*,'(I2,2X,F9.4,2X,F9.4,2X,F10.4,2X,F5.1,2X,I6)') &
                    sources(i)%source_id, sources(i)%ra, sources(i)%dec, &
                    sources(i)%flux, sources(i)%significance, sources(i)%total_counts
            end if
        end do
        
        write(*,*) '----------------------------------------------------'
        write(*,*) ''
        
    end subroutine print_source_catalog
    
    subroutine write_output_files(prefix, obs_header, events, n_events, sources, n_sources, results)
        ! Write processing results to output files
        implicit none
        character(len=*), intent(in) :: prefix
        type(observation_header), intent(in) :: obs_header
        type(photon_event), intent(in) :: events(:)
        integer, intent(in) :: n_events
        type(detected_source), intent(in) :: sources(:)
        integer, intent(in) :: n_sources
        type(processing_results), intent(in) :: results
        
        character(len=200) :: filename
        integer :: unit_num, i
        
        ! Write source catalog
        filename = '' // trim(prefix) // '_sources.txt'
        open(newunit=unit_num, file=filename, status='replace')
        
        write(unit_num, '(A)') '# MinieSASS Source Catalog'
        write(unit_num, '(A)') '# Observation: ' // trim(obs_header%obs_id)
        write(unit_num, '(A)') '# Columns: ID RA(deg) DEC(deg) DetX DetY Flux(cts/s) FluxErr Sigma NetCounts TotalCounts'
        
        do i = 1, n_sources
            if (sources(i)%valid) then
                write(unit_num, '(I3,1X,F10.5,1X,F10.5,1X,F8.2,1X,F8.2,1X,F10.5,1X,F10.5,1X,F6.2,1X,I6,1X,I6)') &
                    sources(i)%source_id, sources(i)%ra, sources(i)%dec, &
                    sources(i)%det_x, sources(i)%det_y, &
                    sources(i)%flux, sources(i)%flux_error, sources(i)%significance, &
                    sources(i)%net_counts, sources(i)%total_counts
            end if
        end do
        
        close(unit_num)
        
        ! Write processing log
        filename = '' // trim(prefix) // '_processing.log'
        open(newunit=unit_num, file=filename, status='replace')
        
        write(unit_num, '(A)') '=== MinieSASS Processing Log ==='
        write(unit_num, '(A)') 'Observation ID: ' // trim(obs_header%obs_id)
        write(unit_num, '(A)') 'Telescope: ' // trim(obs_header%telescop)
        write(unit_num, '(A,I0)') 'Input events: ', results%n_events_input
        write(unit_num, '(A,I0)') 'Filtered events: ', results%n_events_filtered
        write(unit_num, '(A,I0)') 'Calibrated events: ', results%n_events_calibrated
        write(unit_num, '(A,I0)') 'Sources detected: ', results%n_sources_detected
        write(unit_num, '(A,ES12.5)') 'Background rate (cts/s/arcsec²): ', results%background_rate
        write(unit_num, '(A,F8.1)') 'Effective exposure (s): ', results%exposure_effective
        write(unit_num, '(A,L1)') 'Processing success: ', results%processing_success
        
        if (len_trim(results%error_message) > 0) then
            write(unit_num, '(A)') 'Error message: ' // trim(results%error_message)
        end if
        
        close(unit_num)
        
        write(*,*) 'Source catalog written: ', trim(filename)
        
    end subroutine write_output_files
    
    subroutine update_processing_database(obs_id, results)
        ! Update SQLite database with processing results (placeholder)
        implicit none
        character(len=*), intent(in) :: obs_id
        type(processing_results), intent(in) :: results
        
        ! TODO: Implement SQLite database update
        ! For now, just write to a simple log file
        
        character(len=200) :: db_log_file
        integer :: unit_num
        
        db_log_file = 'data/logs/processing_database.log'
        open(newunit=unit_num, file=db_log_file, status='unknown', position='append')
        
        write(unit_num, '(A,1X,A,1X,I0,1X,I0,1X,I0,1X,ES12.5,1X,L1)') &
            trim(obs_id), 'COMPLETED', &
            results%n_events_input, results%n_events_filtered, results%n_sources_detected, &
            results%background_rate, results%processing_success
        
        close(unit_num)
        
    end subroutine update_processing_database
    
    subroutine write_error_log(error_msg, error_code)
        ! Write error information to log file
        implicit none
        character(len=*), intent(in) :: error_msg
        integer, intent(in) :: error_code
        
        character(len=200) :: error_log_file
        integer :: unit_num
        
        error_log_file = 'data/logs/pipeline_errors.log'
        open(newunit=unit_num, file=error_log_file, status='unknown', position='append')
        
        write(unit_num, '(A,1X,I0,1X,A)') 'ERROR', error_code, trim(error_msg)
        close(unit_num)
        
        write(*,*) 'ERROR: ', trim(error_msg), ' (Code: ', error_code, ')'
        
    end subroutine write_error_log

end program pipeline_main