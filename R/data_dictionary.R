#' Irish Weather Buoy Network Data Dictionary
#'
#' @description
#' This function returns a comprehensive data dictionary for all variables
#' available in the Irish Weather Buoy Network dataset. Each entry includes
#' the variable name, units, data type, description, and typical range.
#'
#' @return A data frame containing the complete data dictionary with columns:
#' \itemize{
#'   \item variable: Variable name as used in the dataset
#'   \item category: Category (dimension, meteorological, oceanographic, quality)
#'   \item units: Measurement units
#'   \item data_type: R data type
#'   \item description: Detailed description of the variable
#'   \item typical_range: Typical or valid range of values
#' }
#'
#' @export
#' @examples
#' dict <- get_data_dictionary()
#' print(dict)
get_data_dictionary <- function() {
  data.frame(
    variable = c(
      # Dimension Variables
      "station_id",
      "CallSign",
      "longitude",
      "latitude",
      "time",

      # Meteorological Variables
      "AtmosphericPressure",
      "AirTemperature",
      "DewPoint",
      "WindDirection",
      "WindSpeed",
      "Gust",
      "RelativeHumidity",

      # Oceanographic Variables
      "SeaTemperature",
      "salinity",
      "WaveHeight",
      "WavePeriod",
      "MeanWaveDirection",
      "Hmax",
      "Tp",
      "ThTp",
      "SprTp",

      # Quality Control
      "QC_Flag"
    ),
    category = c(
      rep("dimension", 5),
      rep("meteorological", 7),
      rep("oceanographic", 9),
      "quality"
    ),
    units = c(
      # Dimension
      NA, NA, "degrees_east", "degrees_north", "seconds since 1970-01-01",

      # Meteorological
      "millibars", "degrees_C", "degrees_C", "degrees_true",
      "knots", "knots", "percent",

      # Oceanographic
      "degrees_C", "PSU", "meters", "seconds", "degrees_true",
      "meters", "seconds", "degrees_true", "degrees",

      # QC
      NA
    ),
    data_type = c(
      # Dimension
      "character", "character", "numeric", "numeric", "POSIXct",

      # Meteorological
      rep("numeric", 7),

      # Oceanographic
      rep("numeric", 9),

      # QC
      "integer"
    ),
    description = c(
      # Dimension Variables
      "Unique identifier for each weather buoy station (M1-M6, FS1)",
      "International radio call sign for the buoy",
      "Geographic longitude coordinate of buoy position",
      "Geographic latitude coordinate of buoy position",
      "Timestamp of measurement (UTC)",

      # Meteorological Variables
      "Atmospheric pressure at sea level",
      "Air temperature measured 3-4 meters above sea surface",
      "Dew point temperature - temperature at which air becomes saturated",
      "Direction from which wind is blowing relative to True North",
      "Average wind speed over 10-minute period",
      "Maximum wind speed measured over 3-second period",
      "Relative humidity of the atmosphere",

      # Oceanographic Variables
      "Sea surface temperature",
      "Practical salinity of seawater (PSU scale)",
      "Significant wave height (Hs) - mean height of highest 1/3 of waves",
      "Mean wave period - average time between wave crests",
      "Mean direction from which waves are coming",
      "Maximum individual wave height observed",
      "Peak wave period - period of waves with maximum energy",
      "Direction of waves at spectral peak (maximum energy)",
      "Directional spreading at spectral peak - wave direction variability",

      # Quality Control
      "Data quality indicator: 0=unknown, 1=good, 9=missing"
    ),
    typical_range = c(
      # Dimension
      "M1, M2, M3, M4, M5, M6, FS1",
      "Various",
      "-15.88 to -5.43",
      "51.22 to 55.00",
      "2002-present",

      # Meteorological
      "970-1030",
      "-10 to 30",
      "-15 to 25",
      "0-360",
      "0-60",
      "0-80",
      "0-100",

      # Oceanographic
      "0-25",
      "30-36",
      "0-15",
      "0-20",
      "0-360",
      "0-30",
      "0-25",
      "0-360",
      "0-180",

      # QC
      "0, 1, 9"
    ),
    stringsAsFactors = FALSE
  )
}

#' Get Detailed Variable Documentation
#'
#' @description
#' Returns extended documentation for specific variables including
#' scientific context, calculation methods, and usage notes.
#'
#' @param variable Character string specifying the variable name
#' @return List containing detailed documentation
#'
#' @export
#' @examples
#' doc <- get_variable_docs("WaveHeight")
get_variable_docs <- function(variable = NULL) {
  docs <- list(
    WaveHeight = list(
      scientific_name = "Significant Wave Height (Hs or H1/3)",
      definition = "Statistical measure representing the average height of the highest one-third of waves in a given time period",
      calculation = "Calculated from wave spectrum or zero-crossing analysis of surface elevation time series",
      importance = "Primary parameter for marine safety, engineering design, and sea state characterization",
      relationship = "Related to wind speed, duration, and fetch (distance over which wind acts)"
    ),

    Hmax = list(
      scientific_name = "Maximum Wave Height",
      definition = "Highest individual wave height observed during measurement period",
      calculation = "Direct measurement of largest wave from crest to preceding trough",
      importance = "Critical for structural design and extreme event analysis",
      rogue_wave_threshold = "Hmax > 2 * WaveHeight indicates potential rogue wave"
    ),

    WindSpeed = list(
      scientific_name = "10-meter Wind Speed",
      definition = "Horizontal wind speed averaged over 10 minutes at standard height",
      measurement = "Typically measured 3-5 meters above sea surface on buoys, adjusted to 10m reference",
      units_conversion = "1 knot = 0.514 m/s = 1.852 km/h",
      beaufort_scale = "Can be converted to Beaufort scale for sea state estimation"
    ),

    Gust = list(
      scientific_name = "Wind Gust Speed",
      definition = "Maximum 3-second average wind speed in reporting period",
      importance = "Indicates wind variability and potential for damage",
      gust_factor = "Ratio of Gust/WindSpeed typically 1.3-2.0",
      warning_thresholds = "Gust > 48 knots: gale warning, > 63 knots: storm warning"
    ),

    DewPoint = list(
      scientific_name = "Dew Point Temperature",
      definition = "Temperature at which air becomes saturated with water vapor",
      calculation = "Derived from air temperature and relative humidity",
      importance = "Indicates moisture content, fog probability, and comfort level",
      fog_risk = "When DewPoint approaches AirTemperature, fog formation likely"
    ),

    salinity = list(
      scientific_name = "Practical Salinity",
      definition = "Dimensionless measure of dissolved salt content",
      scale = "Practical Salinity Scale (PSS-78)",
      typical_ocean = "~35 PSU for open ocean, varies near coasts and estuaries",
      importance = "Affects water density, ocean circulation, and marine ecosystems"
    ),

    QC_Flag = list(
      definition = "Quality control indicator for data reliability",
      values = c(
        "0" = "Unknown/not quality controlled",
        "1" = "Good data - passed all QC tests",
        "9" = "Missing value - no data available"
      ),
      usage = "Filter data using QC_Flag == 1 for highest quality analyses"
    )
  )

  if (is.null(variable)) {
    return(docs)
  } else if (variable %in% names(docs)) {
    return(docs[[variable]])
  } else {
    cli::cli_warn("Documentation not available for variable: {variable}")
    return(NULL)
  }
}