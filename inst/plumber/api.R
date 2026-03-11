# irishbuoys Plumber API
#
# Serves pre-built static JSON files from docs/api/v1/.
# Start with: irishbuoys::run_api()

#* @apiTitle irishbuoys API
#* @apiDescription Read-only REST API for Irish Weather Buoy Network data.
#*   Serves pre-computed JSON files updated weekly by the targets pipeline.
#*   16 endpoints covering station metadata, observations, extreme values,
#*   trends, decomposition, spatial correlations, and methods documentation.

# CORS filter — allow cross-origin requests
#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    return(list())
  }
  plumber::forward()
}

# Helper: read a JSON file from docs/api/v1/
read_api_json <- function(filename) {
  # Look for docs/api/v1/ relative to package root
  paths <- c(
    file.path("docs", "api", "v1", filename),
    file.path("..", "..", "docs", "api", "v1", filename),
    system.file("docs", "api", "v1", filename, package = "irishbuoys")
  )
  for (p in paths) {
    if (file.exists(p)) {
      return(jsonlite::fromJSON(p, simplifyVector = FALSE))
    }
  }
  list(error = paste0("File not found: ", filename))
}

# ==========================================================================
# Existing endpoints
# ==========================================================================

#* API index — catalogue of all endpoints
#* @get /index
#* @serializer json
function() {
  read_api_json("index.json")
}

#* List available stations
#* @get /stations
#* @serializer json
function() {
  read_api_json("stations.json")
}

#* Get summary statistics
#* @get /stats
#* @serializer json
function() {
  read_api_json("stats.json")
}

#* Get rogue wave events
#* @get /rogue-waves
#* @serializer json
function() {
  read_api_json("rogue-waves.json")
}

#* Get return level estimates
#* @get /return-levels
#* @serializer json
function() {
  read_api_json("return-levels.json")
}

#* Get data dictionary
#* @get /data-dictionary
#* @serializer json
function() {
  read_api_json("data-dictionary.json")
}

#* Get latest observations
#* @get /latest
#* @serializer json
function() {
  read_api_json("latest.json")
}

#* Get seasonal statistics
#* @get /seasonal
#* @serializer json
function() {
  read_api_json("seasonal.json")
}

#* Get inter-station correlations
#* @get /correlations
#* @serializer json
function() {
  read_api_json("correlations.json")
}

# ==========================================================================
# Tier 1 endpoints (PR 1 / Issue #53)
# ==========================================================================

#* Get data sources and provenance
#* @get /sources
#* @serializer json
function() {
  read_api_json("sources.json")
}

#* Get per-station operational status
#* @get /status
#* @serializer json
function() {
  read_api_json("status.json")
}

#* Get trend analysis results
#* @get /trends
#* @serializer json
function() {
  read_api_json("trends.json")
}

#* Get extreme value analysis
#* @get /extremes
#* @serializer json
function() {
  read_api_json("extremes.json")
}

# ==========================================================================
# Tier 2 endpoints (PR 2 / Issue #53)
# ==========================================================================

#* Get STL decomposition results
#* @get /decomposition
#* @serializer json
function() {
  read_api_json("decomposition.json")
}

#* Get spatial correlation matrices
#* @get /spatial
#* @serializer json
function() {
  read_api_json("spatial.json")
}

#* Get gust factor analysis
#* @get /gust-factors
#* @serializer json
function() {
  read_api_json("gust-factors.json")
}

# ==========================================================================
# Tier 3 endpoints (PR 3 / Issue #53)
# ==========================================================================

#* Get statistical methods documentation
#* @get /methods
#* @serializer json
function() {
  read_api_json("methods.json")
}
