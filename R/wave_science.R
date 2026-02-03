#' Wave Measurement Science Functions
#'
#' @description
#' Functions that explain and calculate wave measurement parameters.
#' This module provides educational documentation alongside computational functions
#' to help users understand wave measurement methodology.
#'
#' @name wave_science
#' @keywords internal
NULL

#' Glossary of Wave Measurement Terms
#'
#' @description
#' Returns a data frame of acronyms and definitions used in wave measurement.
#'
#' @return Data frame with columns: acronym, term, definition, unit
#'
#' @export
#' @examples
#' glossary <- wave_glossary()
#' print(glossary)
wave_glossary <- function() {
  data.frame(
    acronym = c(
      "Hs", "H_1/3", "RMS", "Hmax", "Tp", "Tz", "m0",
      "GEV", "GPD", "EVA", "STL", "QC",
      "ERDDAP", "WMO", "IMO"
    ),
    term = c(
      "Significant Wave Height", "Mean of Highest Third",
      "Root Mean Square", "Maximum Wave Height",
      "Peak Wave Period", "Zero-Crossing Period", "Zeroth Spectral Moment",
      "Generalized Extreme Value", "Generalized Pareto Distribution",
      "Extreme Value Analysis", "Seasonal-Trend using Loess",
      "Quality Control",
      "Environmental Research Division Data Access Program",
      "World Meteorological Organization",
      "International Maritime Organization"
    ),
    definition = c(
      "Average height of the highest one-third of waves; equals 4 times the standard deviation of surface elevation",
      "Traditional definition of significant wave height: mean of the highest 33% of waves",
      "Square root of the mean of squared values; for waves, related to energy content",
      "Maximum individual wave height observed in a measurement period",
      "Wave period corresponding to the peak of the energy spectrum",
      "Average period between successive zero up-crossings of the water surface",
      "Variance of the sea surface elevation; integral of wave spectrum",
      "Family of distributions for modeling block maxima (e.g., annual maximum waves)",
      "Distribution for modeling exceedances over a high threshold",
      "Statistical methods for estimating extreme events and return levels",
      "Decomposition method separating seasonal, trend, and remainder components",
      "Quality control flags indicating data validity",
      "Server protocol for accessing scientific datasets",
      "United Nations agency for weather, climate, and water",
      "United Nations agency for shipping safety"
    ),
    unit = c(
      "meters (m)", "meters (m)", "meters (m)", "meters (m)",
      "seconds (s)", "seconds (s)", "m^2",
      "-", "-", "-", "-", "-",
      "-", "-", "-"
    ),
    stringsAsFactors = FALSE
  )
}

#' Explain Why Hs Equals 4 Times Standard Deviation
#'
#' @description
#' Educational function explaining the physical and statistical basis
#' for the relationship Hs = 4 * sigma.
#'
#' @return Character string with explanation
#'
#' @export
#' @examples
#' cat(explain_hs_formula())
explain_hs_formula <- function() {
  explanation <- "
SIGNIFICANT WAVE HEIGHT (Hs) = 4 * Standard Deviation
======================================================

STEP-BY-STEP CALCULATION
------------------------
1. MEASURE sea surface elevation eta(t) over 17.5 minutes
   - Raw data: elevation in meters at each time point
   - Example: eta = [0.5, -0.3, 1.2, -0.8, ...] meters

2. REMOVE THE MEAN (de-trend to eliminate tidal/ambient level)
   - eta_prime(t) = eta(t) - mean(eta)
   - This centers the data around zero
   - Now we have pure wave-induced fluctuations

3. CALCULATE STANDARD DEVIATION of de-meaned elevations
   - sigma = std(eta_prime)
   - Units: meters
   - This measures the typical amplitude of wave fluctuations

4. MULTIPLY BY 4
   - Hs = 4 * sigma
   - Units: meters

WHY MULTIPLY BY 4? (The Statistical Derivation)
-----------------------------------------------
This comes from Longuet-Higgins (1952) wave spectrum theory:

For a narrow-banded Gaussian random sea:
- Individual wave heights follow a RAYLEIGH DISTRIBUTION
- The Rayleigh PDF is: f(H) = (H/sigma^2) * exp(-H^2 / 2*sigma^2)

The average of the HIGHEST 1/3 of waves (called H_1/3) can be computed
by integrating the Rayleigh PDF from the 67th percentile upward:

  H_1/3 = integral from H_67% to infinity of H * f(H) dH
        = 4.004 * sigma
        ~ 4 * sigma

The factor 4.004 is a MATHEMATICAL CONSTANT from the Rayleigh distribution,
not an arbitrary choice. It rounds to 4 for practical use.

PHYSICAL MEANING
----------------
- Hs approximates what a trained observer visually estimates
- Observers naturally focus on the larger, memorable waves
- They unconsciously average the highest third
- Longuet-Higgins proved this matches H_1/3 = 4*sigma

REFERENCES
----------
1. Longuet-Higgins, M.S. (1952). On the statistical distribution of the
   heights of sea waves. J. Marine Research, 11(3), 245-266.
   [Original derivation of Hs = 4*sigma]

2. Holthuijsen, L.H. (2007). Waves in Oceanic and Coastal Waters.
   Cambridge University Press. Chapter 4.
   [Modern textbook treatment]

3. WMO (2018). Guide to Wave Analysis and Forecasting. WMO-No. 702.
   [Operational standards]

RELATIONSHIP TO RMS WAVE HEIGHT
-------------------------------
RMS wave height: H_rms = sqrt(mean(H^2)) = sqrt(2) * sigma ~ 1.41 * sigma

Therefore:
  Hs = 4 * sigma = (4/sqrt(2)) * (sqrt(2) * sigma) = 2.83 * H_rms

Or: H_rms ~ 0.35 * Hs
"
  return(explanation)
}

#' Explain the 17.5-Minute Measurement Period
#'
#' @description
#' Educational function explaining why wave measurements use
#' specific time periods for statistical validity.
#'
#' @return Character string with explanation
#'
#' @export
#' @examples
#' cat(explain_measurement_period())
explain_measurement_period <- function() {
  explanation <- "
WAVE MEASUREMENT PERIOD: WHY 17.5 MINUTES?
==========================================

STATISTICAL REQUIREMENT
-----------------------
The significant wave height (Hs) is defined as the mean of the highest
1/3 of all waves in a measurement period. For this statistic to be
reliable, you need a sufficient sample size.

TYPICAL WAVE PERIODS
--------------------
- Wind waves: 3-10 seconds
- Swell: 10-25 seconds
- Average ocean: ~8 seconds

NUMBER OF WAVES NEEDED
----------------------
For statistical validity of H_1/3, you need approximately 100-200 waves.

With average period of 8 seconds:
- 100 waves = 800 seconds = 13.3 minutes (minimum)
- 200 waves = 1600 seconds = 26.7 minutes (ideal)

WMO RECOMMENDATIONS
-------------------
The World Meteorological Organization recommends:
- Standard period: 20-30 minutes
- Minimum acceptable: 17 minutes
- Marine Institute uses: 17.5 minutes (lower bound)

TRADE-OFFS
----------
Longer period:
  + Better statistics (more waves sampled)
  + More stable Hs estimates
  - Less temporal resolution
  - May miss rapid changes in sea state

Shorter period:
  + Better temporal resolution
  + Captures rapid changes
  - Higher uncertainty in Hs
  - May not capture full wave variability

17.5 MINUTES RATIONALE
----------------------
The Marine Institute buoys use 17.5 minutes as a pragmatic choice:
- Meets minimum statistical requirements (~100+ waves)
- Provides hourly data with multiple samples
- Standard practice for operational wave buoys
- Consistent with international data sharing protocols
"
  return(explanation)
}

#' Explain Hourly Averaging Process
#'
#' @description
#' Educational function explaining how raw measurements become hourly values.
#'
#' @return Character string with explanation
#'
#' @export
#' @examples
#' cat(explain_hourly_averaging())
explain_hourly_averaging <- function() {
  explanation <- "
HOURLY DATA: FROM RAW MEASUREMENTS TO REPORTED VALUES
=====================================================

RAW DATA COLLECTION
-------------------
The buoy continuously measures:
- Sea surface elevation (heave sensor)
- Accelerometers for motion
- Other sensors (wind, pressure, temperature)

BURST SAMPLING
--------------
Waves are measured in 'bursts':
- Duration: 17.5 minutes (Irish Weather Buoy Network)
- Sample rate: Typically 1-2 Hz (1-2 samples per second)
- Raw samples per burst: ~1000-2000 measurements

SPECTRAL PROCESSING
-------------------
For each burst:
1. Apply FFT (Fast Fourier Transform) to heave signal
2. Calculate wave energy spectrum S(f)
3. Compute spectral moments: m0, m1, m2, m4
4. Derive parameters:
   - Hs = 4 * sqrt(m0)
   - Tp = period at spectral peak
   - Tz = sqrt(m0/m2)

HMAX DETERMINATION
------------------
Maximum wave height (Hmax) is determined by:
1. Zero-crossing analysis of the time series
2. Identifying individual waves (trough to trough)
3. Recording the maximum crest-to-trough height

HOURLY REPORTING
----------------
The ERDDAP data provides ONE value per hour:
- This is typically the most recent burst analysis
- NOT an average of multiple bursts
- Represents conditions at that hour

DATA TIMELINE
-------------
Example for 12:00 UTC value:
- Burst collected: ~11:40-11:57 UTC
- Processing: ~1-2 minutes
- Reported as: 12:00 UTC timestamp

QUALITY CONTROL
---------------
Each reported value includes a QC flag:
- 1 = Good quality
- 2 = Suspect
- 3-9 = Various quality issues (see Marine Institute documentation)
"
  return(explanation)
}

#' Calculate Significant Wave Height from Raw Elevations
#'
#' @description
#' Calculates Hs from a time series of surface elevation measurements
#' using the spectral method (4 * sigma).
#'
#' @param elevations Numeric vector of surface elevation measurements (m)
#'
#' @return Significant wave height in meters
#'
#' @export
#' @examples
#' # Simulated wave elevation time series
#' t <- seq(0, 1000, by = 0.5)  # 1000 seconds at 2Hz
#' elevation <- 0.5 * sin(2*pi*t/8) + 0.3 * sin(2*pi*t/12) + rnorm(length(t), 0, 0.1)
#' hs <- calculate_hs_from_elevation(elevation)
calculate_hs_from_elevation <- function(elevations) {
  # Remove mean (de-trend)
  eta <- elevations - mean(elevations, na.rm = TRUE)

  # Calculate standard deviation
  sigma <- stats::sd(eta, na.rm = TRUE)

  # Hs = 4 * sigma
  hs <- 4 * sigma

  return(hs)
}

#' Calculate RMS Wave Height
#'
#' @description
#' Calculates the Root Mean Square wave height, which is related to
#' wave energy content.
#'
#' @param wave_heights Numeric vector of individual wave heights (m)
#'
#' @return RMS wave height in meters
#'
#' @details
#' H_rms = sqrt(mean(H^2))
#'
#' Relationship to Hs (for Rayleigh distribution):
#' H_rms = Hs / sqrt(8) ~ 0.707 * Hs
#'
#' @export
#' @examples
#' heights <- c(1.2, 2.1, 0.8, 3.5, 1.9, 2.8)
#' h_rms <- calculate_rms_wave_height(heights)
calculate_rms_wave_height <- function(wave_heights) {
  h_squared <- wave_heights^2
  h_rms <- sqrt(mean(h_squared, na.rm = TRUE))
  return(h_rms)
}

#' Estimate Hs from RMS Wave Height
#'
#' @description
#' Converts RMS wave height to significant wave height using
#' the theoretical relationship for Rayleigh-distributed waves.
#'
#' @param h_rms RMS wave height in meters
#'
#' @return Significant wave height in meters
#'
#' @details
#' For Rayleigh-distributed waves:
#' Hs = H_rms * sqrt(8) ~ 2.83 * H_rms
#'
#' @export
#' @examples
#' h_rms <- 1.5
#' hs <- hs_from_rms(h_rms)  # Returns ~4.24 m
hs_from_rms <- function(h_rms) {
  # Hs = H_rms * sqrt(8) for Rayleigh distribution
  hs <- h_rms * sqrt(8)
  return(hs)
}

#' Explain How Individual Wave Heights Are Measured (Zero-Crossing Method)
#'
#' @description
#' Educational function explaining how individual wave heights like Hmax
#' are measured, and how this differs from the statistical Hs calculation.
#'
#' @return Character string with explanation
#'
#' @export
#' @examples
#' cat(explain_wave_height_measurement())
explain_wave_height_measurement <- function() {
  explanation <- "
HOW INDIVIDUAL WAVE HEIGHTS ARE MEASURED: THE ZERO-CROSSING METHOD
===================================================================

TWO DIFFERENT CONCEPTS - IMPORTANT DISTINCTION
----------------------------------------------
1. Hs (Significant Wave Height) = STATISTICAL parameter from continuous
   surface elevation data (4 * standard deviation)

2. Hmax (Maximum Wave Height) = INDIVIDUAL wave height from discrete
   wave-by-wave analysis using zero-crossing method

THE ZERO-CROSSING METHOD
------------------------
To measure individual wave heights, we need to define what constitutes
a single 'wave'. The standard method is ZERO UP-CROSSING:

1. ZERO UP-CROSSING: A point where the surface elevation rises through
   the mean level (from below to above zero, after de-meaning)

2. ONE WAVE = The segment between two consecutive zero up-crossings

3. Within each wave segment:
   - CREST = maximum elevation (highest point)
   - TROUGH = minimum elevation (lowest point)
   - WAVE HEIGHT H = Crest - Trough (vertical distance)

VISUAL EXAMPLE
--------------
         Crest
          /\\
         /  \\
        /    \\          <- One complete wave
       /      \\
------/--------\\--------  Mean level (zero)
                \\      /
                 \\    /
                  \\  /
                   \\/
                  Trough

^                      ^
|                      |
Zero up-crossing       Zero up-crossing
(wave starts)          (wave ends, next starts)

Wave Height H = Crest elevation - Trough elevation

HOW Hmax IS DETERMINED
----------------------
From a 17.5-minute measurement period:

1. De-mean the surface elevation time series
2. Identify all zero up-crossings
3. For each wave (segment between crossings):
   - Find the maximum (crest)
   - Find the minimum (trough)
   - Calculate H = crest - trough
4. Hmax = maximum of all individual wave heights

TYPICAL RESULTS
---------------
In a 17.5-minute period with 8-second average wave period:
- ~130 individual waves identified
- Each has its own height H_i
- Hmax is the single largest
- H_1/3 (Hs) is the average of the ~43 largest waves

RELATIONSHIP BETWEEN Hs AND Hmax
--------------------------------
For Rayleigh-distributed waves (theoretical):
- Hmax/Hs depends on number of waves N
- Expected Hmax = Hs * sqrt(ln(N)/2) (approximately)
- For N=100 waves: Hmax ~ 1.5 * Hs
- For N=1000 waves: Hmax ~ 1.86 * Hs

ROGUE WAVE CRITERION
--------------------
A rogue wave is defined when:
  Hmax/Hs > 2.0  (or 2.2 in some standards)

This exceeds the statistical expectation, suggesting
non-linear wave interactions (Benjamin-Feir instability,
wave-current interaction, or focusing effects).

WHY TWO METHODS EXIST
---------------------
1. SPECTRAL METHOD (Hs = 4*sigma):
   - Robust to noise
   - Works with short records
   - Standard for operational forecasting
   - Related to wave energy (m0 = sigma^2)

2. ZERO-CROSSING METHOD (Hmax, H_1/3):
   - Direct physical measurement
   - Needed for structural design (maximum loads)
   - Required for rogue wave detection
   - Historical standard before FFT became practical

BOTH METHODS SHOULD AGREE
-------------------------
For a proper Rayleigh sea, both methods give similar Hs:
- Spectral: Hs = 4 * sqrt(m0) = 4 * sigma
- Zero-crossing: Hs = H_1/3 (mean of highest third)

Disagreement suggests:
- Bi-modal sea (swell + wind waves)
- Non-linear effects
- Data quality issues

REFERENCES
----------
1. Tucker, M.J. & Pitt, E.G. (2001). Waves in Ocean Engineering.
   Elsevier. Chapter 5: Wave statistics.

2. Goda, Y. (2010). Random Seas and Design of Maritime Structures.
   World Scientific. Chapter 2: Statistical properties.

3. DNV-RP-C205 (2019). Environmental Conditions and Environmental Loads.
   Section 3.5: Wave parameters.
"
  return(explanation)
}

#' Generate Wave Science Documentation
#'
#' @description
#' Returns a comprehensive markdown document explaining wave measurement
#' science, suitable for inclusion in vignettes.
#'
#' @return Character string with markdown-formatted documentation
#'
#' @export
wave_science_documentation <- function() {
  doc <- paste0(
    explain_hs_formula(), "\n\n",
    explain_wave_height_measurement(), "\n\n",
    explain_measurement_period(), "\n\n",
    explain_hourly_averaging()
  )
  return(doc)
}
