# irishbuoys Plumber API
#
# Serves pre-built static JSON files from docs/api/v1/.
# Start with: irishbuoys::run_api()

#* @apiTitle irishbuoys API
#* @apiDescription Read-only REST API for Irish Weather Buoy Network data.
#*   Serves pre-computed JSON files updated weekly by the targets pipeline.

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

#* List available stations
#* @get /stations
#* @serializer json
function() {
  read_api_json("stations.json")
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

#* Get seasonal statistics
#* @get /seasonal
#* @serializer json
function() {
  read_api_json("seasonal.json")
}
