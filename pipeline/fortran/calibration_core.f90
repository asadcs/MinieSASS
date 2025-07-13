! =============================================================================
! calibration_core.f90 - MinieSASS X-ray Calibration Core Module
! 
! Purpose: Core data structures and calibration routines for eROSITA-style
!          X-ray data processing pipeline
!
! Author: Portfolio Project for MPE Software Engineer Position
! Date: July 2025
! =============================================================================

module calibration_core
    use, intrinsic :: iso_c_binding
    implicit none
    
    ! Module parameters
    integer, parameter :: dp = kind(1.0d0)  ! Double precision
    integer, parameter :: MAX_EVENTS = 1000000  ! Maximum events per observation
    integer, parameter :: MAX_SOURCES = 100     ! Maximum detected sources
    
    ! Physical constants (X-ray astronomy)
    real(dp), parameter :: KEV_TO_ERG = 1.602176634d-9  ! keV to erg conversion
    real(dp), parameter :: ARCSEC_TO_RAD = 4.84813681d-6  ! arcsec to radians
    real(dp), parameter :: PI = 3.141592653589793d0
    
    ! ==========================================================================
    ! Core Data Structures
    ! ==========================================================================
    
    ! Individual X-ray photon event
    type :: photon_event
        real(dp) :: time          ! Event time (seconds since start)
        real(dp) :: energy        ! Photon energy (keV)
        real(dp) :: det_x, det_y  ! Detector coordinates (pixels)
        real(dp) :: ra, dec       ! Sky coordinates (degrees)
        integer  :: pi_channel    ! Pulse Invariant channel
        integer  :: grade         ! Event grade (quality flag)
        integer  :: frame         ! CCD frame number
        integer  :: status        ! Quality status (0=good, 1=bad)
        logical  :: valid         ! Event passes quality cuts
    end type photon_event
    
    ! Detector response and geometry
    type :: detector_config
        real(dp) :: pixel_size    ! Detector pixel size (arcsec)
        real(dp) :: focal_length  ! Telescope focal length (mm)
        integer  :: nx, ny        ! Detector dimensions (pixels)
        real(dp) :: gain          ! Energy calibration gain (keV/channel)
        real(dp) :: offset        ! Energy calibration offset (keV)
        real(dp) :: center_x, center_y  ! Detector center (pixels)
        real(dp), allocatable :: response_matrix(:,:)  ! Energy response
        real(dp), allocatable :: vignetting(:,:)       ! Vignetting correction
    end type detector_config
    
    ! Observation metadata and pointing
    type :: observation_header
        character(len=20) :: obs_id           ! Observation identifier
        real(dp) :: pointing_ra, pointing_dec ! Nominal pointing (degrees)
        real(dp) :: roll_angle                ! Spacecraft roll (degrees)
        real(dp) :: exposure_time             ! Total exposure (seconds)
        real(dp) :: start_time                ! Observation start (MJD)
        integer  :: total_events              ! Number of events
        logical  :: attitude_valid            ! Attitude solution available
        character(len=50) :: telescop         ! Telescope name
        character(len=50) :: instrume         ! Instrument name
    end type observation_header
    
    ! Background estimation parameters
    type :: background_config
        real(dp) :: inner_radius   ! Source exclusion radius (arcsec)
        real(dp) :: outer_radius   ! Background annulus outer radius (arcsec)
        integer  :: min_counts     ! Minimum counts for valid background
        real(dp) :: poisson_limit  ! Poisson confidence level
        logical  :: use_local_bg   ! Use local vs global background
    end type background_config
    
    ! Detected source properties
    type :: detected_source
        integer  :: source_id      ! Unique source identifier
        real(dp) :: ra, dec        ! Source position (degrees)
        real(dp) :: det_x, det_y   ! Detector position (pixels)
        real(dp) :: flux           ! Source flux (counts/s)
        real(dp) :: flux_error     ! Flux uncertainty (counts/s)
        real(dp) :: significance   ! Detection significance (sigma)
        real(dp) :: background     ! Local background (counts/s/arcsec²)
        integer  :: net_counts     ! Background-subtracted counts
        integer  :: total_counts   ! Raw counts in source region
        real(dp) :: snr            ! Signal-to-noise ratio
        logical  :: extended       ! Extended source flag
        logical  :: valid          ! Source passes quality cuts
    end type detected_source
    
    ! Processing status and results
    type :: processing_results
        integer  :: n_events_input     ! Input events
        integer  :: n_events_filtered  ! After quality filtering
        integer  :: n_events_calibrated ! After calibration
        integer  :: n_sources_detected  ! Number of sources found
        real(dp) :: background_rate     ! Global background rate
        real(dp) :: exposure_effective  ! Effective exposure time
        logical  :: processing_success  ! Overall success flag
        character(len=200) :: error_message  ! Error description if failed
    end type processing_results
    
    ! ==========================================================================
    ! Module variables and interfaces
    ! ==========================================================================
    
    type(detector_config), save :: detector
    type(background_config), save :: bg_config
    logical, save :: module_initialized = .false.
    
    ! Interface to C CFITSIO functions
    interface
        function cfitsio_open_file(filename, mode, status) bind(c, name='cfitsio_open_file')
            use iso_c_binding
            character(c_char), intent(in) :: filename(*)
            integer(c_int), value :: mode
            integer(c_int) :: status
            integer(c_int) :: cfitsio_open_file
        end function cfitsio_open_file
        
        subroutine cfitsio_close_file(fitsfile, status) bind(c, name='cfitsio_close_file')
            use iso_c_binding
            integer(c_int), value :: fitsfile
            integer(c_int) :: status
        end subroutine cfitsio_close_file
    end interface
    
contains

    ! ==========================================================================
    ! Initialization and Configuration
    ! ==========================================================================
    
    subroutine initialize_calibration_core()
        ! Initialize the calibration module with default parameters
        implicit none
        
        if (module_initialized) return
        
        ! Set default detector configuration (eROSITA-like)
        detector%pixel_size = 4.1d0          ! arcsec per pixel
        detector%focal_length = 1600.0d0     ! mm
        detector%nx = 384
        detector%ny = 384
        detector%gain = 0.005d0              ! keV per channel
        detector%offset = 0.2d0              ! keV
        detector%center_x = 192.0d0          ! pixels
        detector%center_y = 192.0d0          ! pixels
        
        ! Set default background configuration
        bg_config%inner_radius = 15.0d0      ! arcsec
        bg_config%outer_radius = 60.0d0      ! arcsec  
        bg_config%min_counts = 10
        bg_config%poisson_limit = 0.95d0     ! 95% confidence
        bg_config%use_local_bg = .true.
        
        module_initialized = .true.
        
        write(*,*) 'MinieSASS Calibration Core initialized'
        write(*,*) 'Detector: ', detector%nx, 'x', detector%ny, ' pixels'
        write(*,*) 'Pixel scale: ', detector%pixel_size, ' arcsec/pixel'
        
    end subroutine initialize_calibration_core
    
    ! ==========================================================================
    ! FITS File I/O Routines
    ! ==========================================================================
    
    subroutine read_fits_header(filename, obs_header, status)
        ! Read observation header from FITS file
        implicit none
        character(len=*), intent(in) :: filename
        type(observation_header), intent(out) :: obs_header
        integer, intent(out) :: status
        
        integer :: fitsfile, hdutype, nkeys, i
        character(len=80) :: card, keyword, comment
        character(len=80) :: value_str
        real(dp) :: value_real
        
        status = 0
        
        ! Open FITS file (placeholder - would use CFITSIO)
        write(*,*) 'Reading FITS header from: ', trim(filename)
        
        ! Initialize header with defaults
        obs_header%obs_id = 'UNKNOWN'
        obs_header%telescop = 'eROSITA-SIM'
        obs_header%instrume = 'TM1'
        obs_header%pointing_ra = 0.0d0
        obs_header%pointing_dec = 0.0d0
        obs_header%roll_angle = 0.0d0
        obs_header%exposure_time = 1000.0d0
        obs_header%start_time = 58000.0d0  ! MJD
        obs_header%total_events = 0
        obs_header%attitude_valid = .true.
        
        ! TODO: Implement actual CFITSIO calls
        ! For now, parse filename for basic info
        if (index(filename, 'TEST001') > 0) then
            obs_header%obs_id = 'TEST001'
            obs_header%pointing_ra = 30.0d0
            obs_header%pointing_dec = 10.0d0
        else if (index(filename, 'TEST002') > 0) then
            obs_header%obs_id = 'TEST002'
            obs_header%pointing_ra = 45.0d0
            obs_header%pointing_dec = -5.0d0
        end if
        
        write(*,*) 'Header parsed: OBS_ID=', trim(obs_header%obs_id)
        write(*,*) 'Pointing: RA=', obs_header%pointing_ra, ' DEC=', obs_header%pointing_dec
        
    end subroutine read_fits_header
    
    subroutine load_event_data(filename, events, n_events, max_events, status)
        ! Load photon events from FITS binary table
        implicit none
        character(len=*), intent(in) :: filename
        type(photon_event), intent(out) :: events(max_events)
        integer, intent(out) :: n_events
        integer, intent(in) :: max_events
        integer, intent(out) :: status
        
        integer :: i, fitsfile
        
        status = 0
        n_events = 0
        
        write(*,*) 'Loading event data from: ', trim(filename)
        
        ! TODO: Implement actual CFITSIO binary table reading
        ! For now, simulate some events for testing
        if (index(filename, 'TEST001') > 0) then
            call simulate_test_events(events, n_events, max_events, 1)
        else if (index(filename, 'TEST002') > 0) then
            call simulate_test_events(events, n_events, max_events, 2)
        else
            write(*,*) 'Warning: Unknown test file, using default events'
            call simulate_test_events(events, n_events, max_events, 0)
        end if
        
        write(*,*) 'Loaded ', n_events, ' events'
        
    end subroutine load_event_data
    
    subroutine simulate_test_events(events, n_events, max_events, test_case)
        ! Generate test events for development (placeholder for real FITS data)
        implicit none
        type(photon_event), intent(out) :: events(max_events)
        integer, intent(out) :: n_events
        integer, intent(in) :: max_events, test_case
        
        integer :: i
        real(dp) :: random_val
        
        ! Generate different test cases
        select case(test_case)
        case(1)  ! TEST001 - 5 sources
            n_events = min(5000, max_events)
        case(2)  ! TEST002 - 3 sources  
            n_events = min(300, max_events)
        case default
            n_events = min(100, max_events)
        end select
        
        ! Create mock events
        do i = 1, n_events
            call random_number(random_val)
            events(i)%time = random_val * 1000.0d0  ! 0-1000 seconds
            
            call random_number(random_val)
            events(i)%det_x = random_val * 384.0d0  ! detector pixels
            
            call random_number(random_val)
            events(i)%det_y = random_val * 384.0d0
            
            call random_number(random_val)
            events(i)%energy = 0.5d0 + random_val * 8.0d0  ! 0.5-8.5 keV
            
            events(i)%pi_channel = int((events(i)%energy - detector%offset) / detector%gain)
            events(i)%grade = 0  ! Single pixel events
            events(i)%frame = int(events(i)%time / 2.6d0)  ! 2.6s frame time
            events(i)%status = 0  ! Good event
            events(i)%valid = .true.
            
            ! Convert detector to sky coordinates (simplified)
            call detector_to_sky(events(i)%det_x, events(i)%det_y, &
                                events(i)%ra, events(i)%dec)
        end do
        
    end subroutine simulate_test_events
    
    ! ==========================================================================
    ! Coordinate Transformations
    ! ==========================================================================
    
    subroutine detector_to_sky(det_x, det_y, ra, dec)
        ! Convert detector pixel coordinates to sky coordinates
        ! Simplified linear transformation for testing
        implicit none
        real(dp), intent(in) :: det_x, det_y
        real(dp), intent(out) :: ra, dec
        
        real(dp) :: delta_x, delta_y, scale
        
        ! Offset from detector center
        delta_x = det_x - detector%center_x
        delta_y = det_y - detector%center_y
        
        ! Convert to arcseconds, then degrees
        scale = detector%pixel_size / 3600.0d0  ! degrees per pixel
        
        ! Simple tangent plane projection (no rotation for now)
        ra = 30.0d0 + delta_x * scale  ! Assume pointing at 30,10
        dec = 10.0d0 + delta_y * scale
        
    end subroutine detector_to_sky
    
    subroutine sky_to_detector(ra, dec, det_x, det_y)
        ! Convert sky coordinates to detector pixels
        implicit none
        real(dp), intent(in) :: ra, dec
        real(dp), intent(out) :: det_x, det_y
        
        real(dp) :: delta_ra, delta_dec, scale
        
        scale = 3600.0d0 / detector%pixel_size  ! pixels per degree
        
        delta_ra = ra - 30.0d0   ! Assume pointing center
        delta_dec = dec - 10.0d0
        
        det_x = detector%center_x + delta_ra * scale
        det_y = detector%center_y + delta_dec * scale
        
    end subroutine sky_to_detector
    
    ! ==========================================================================
    ! Quality Filtering
    ! ==========================================================================
    
    subroutine apply_quality_filters(events, n_events, n_filtered)
        ! Apply quality cuts to event list
        implicit none
        type(photon_event), intent(inout) :: events(:)
        integer, intent(in) :: n_events
        integer, intent(out) :: n_filtered
        
        integer :: i, good_count
        
        good_count = 0
        
        do i = 1, n_events
            ! Apply quality cuts
            events(i)%valid = .true.
            
            ! Energy range check
            if (events(i)%energy < 0.2d0 .or. events(i)%energy > 10.0d0) then
                events(i)%valid = .false.
            end if
            
            ! Grade check (single and double pixel events only)
            if (events(i)%grade > 2) then
                events(i)%valid = .false.
            end if
            
            ! Status check
            if (events(i)%status /= 0) then
                events(i)%valid = .false.
            end if
            
            ! Detector boundary check
            if (events(i)%det_x < 1.0d0 .or. events(i)%det_x > 383.0d0 .or. &
                events(i)%det_y < 1.0d0 .or. events(i)%det_y > 383.0d0) then
                events(i)%valid = .false.
            end if
            
            if (events(i)%valid) good_count = good_count + 1
        end do
        
        n_filtered = good_count
        
        write(*,*) 'Quality filtering: ', n_events, ' → ', n_filtered, ' events'
        write(*,*) 'Filtering efficiency: ', real(n_filtered)/real(n_events)*100.0, '%'
        
    end subroutine apply_quality_filters
    
    ! ==========================================================================
    ! Background Estimation
    ! ==========================================================================
    
    subroutine estimate_global_background(events, n_events, background_rate)
        ! Estimate global background rate from event distribution
        implicit none
        type(photon_event), intent(in) :: events(:)
        integer, intent(in) :: n_events
        real(dp), intent(out) :: background_rate
        
        integer :: valid_events, i
        real(dp) :: detector_area, exposure_time
        
        ! Count valid events
        valid_events = 0
        exposure_time = 1000.0d0  ! Default exposure
        
        do i = 1, n_events
            if (events(i)%valid) then
                valid_events = valid_events + 1
                exposure_time = max(exposure_time, events(i)%time)
            end if
        end do
        
        ! Calculate detector area in square arcseconds
        detector_area = (detector%nx * detector%pixel_size) * &
                       (detector%ny * detector%pixel_size)
        
        ! Background rate in counts/s/arcsec²
        background_rate = real(valid_events) / (exposure_time * detector_area)
        
        write(*,*) 'Global background rate: ', background_rate, ' cts/s/arcsec²'
        write(*,*) 'Total valid events: ', valid_events
        write(*,*) 'Effective exposure: ', exposure_time, ' s'
        
    end subroutine estimate_global_background
    
    ! ==========================================================================
    ! Utility Functions
    ! ==========================================================================
    
    function calculate_distance(ra1, dec1, ra2, dec2) result(distance)
        ! Calculate angular distance between two sky positions (arcsec)
        implicit none
        real(dp), intent(in) :: ra1, dec1, ra2, dec2
        real(dp) :: distance
        
        real(dp) :: dra, ddec, a, c
        real(dp) :: deg_to_rad
        
        deg_to_rad = PI / 180.0d0
        
        ! Haversine formula for small angles
        dra = (ra1 - ra2) * deg_to_rad * cos(dec1 * deg_to_rad)
        ddec = (dec1 - dec2) * deg_to_rad
        
        distance = sqrt(dra*dra + ddec*ddec) * 180.0d0 / PI * 3600.0d0  ! arcsec
        
    end function calculate_distance
    
    subroutine print_module_status()
        ! Print current module configuration
        implicit none
        
        write(*,*) '=== MinieSASS Calibration Core Status ==='
        write(*,*) 'Module initialized: ', module_initialized
        if (module_initialized) then
            write(*,*) 'Detector configuration:'
            write(*,*) '  Size: ', detector%nx, ' x ', detector%ny, ' pixels'
            write(*,*) '  Pixel scale: ', detector%pixel_size, ' arcsec/pixel'
            write(*,*) '  Energy calibration: ', detector%gain, ' keV/channel + ', detector%offset, ' keV'
            write(*,*) 'Background configuration:'
            write(*,*) '  Annulus: ', bg_config%inner_radius, ' - ', bg_config%outer_radius, ' arcsec'
            write(*,*) '  Min counts: ', bg_config%min_counts
        end if
        write(*,*) '========================================'
        
    end subroutine print_module_status

end module calibration_core