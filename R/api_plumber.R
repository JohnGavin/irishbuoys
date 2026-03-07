#' Plumber API for irishbuoys
#'
#' @description
#' Functions for running a live REST API that serves pre-built
#' static JSON data from the targets pipeline.
#'
#' @family api
#' @name api_plumber
NULL

#' Run the irishbuoys REST API
#'
#' @description
#' Starts a plumber API server that serves pre-computed JSON files
#' from `docs/api/v1/`. Requires the `plumber` package.
#'
#' @param port Integer port number (default: 8080)
#' @param host Character host address (default: "0.0.0.0")
#'
#' @return Invisibly returns the plumber router (runs until interrupted).
#'
#' @family api
#' @export
#' @examples
#' \dontrun{
#' run_api()
#' # API available at http://localhost:8080
#' # Swagger docs at http://localhost:8080/__docs__/
#' }
run_api <- function(port = 8080, host = "0.0.0.0") {
  rlang::check_installed("plumber", reason = "to run the irishbuoys API")

  api_dir <- system.file("plumber", package = "irishbuoys")
  if (!nzchar(api_dir)) {
    cli::cli_abort(c(
      "x" = "Cannot find plumber API definition.",
      "i" = "Ensure the package is properly installed."
    ))
  }

  pr <- plumber::plumb(file.path(api_dir, "api.R"))
  cli::cli_alert_info("Starting irishbuoys API on {host}:{port}")
  cli::cli_alert_info("Swagger docs: http://{host}:{port}/__docs__/")
  pr$run(host = host, port = port)
}

#' Create the irishbuoys Plumber Router
#'
#' @description
#' Creates and returns a plumber router without starting the server.
#' Useful for testing and programmatic access.
#'
#' @return A plumber router object.
#'
#' @family api
#' @export
#' @examples
#' \dontrun{
#' pr <- create_api_router()
#' # Test endpoints programmatically
#' }
create_api_router <- function() {
  rlang::check_installed("plumber", reason = "to create the irishbuoys API router")

  api_dir <- system.file("plumber", package = "irishbuoys")
  if (!nzchar(api_dir)) {
    cli::cli_abort(c(
      "x" = "Cannot find plumber API definition.",
      "i" = "Ensure the package is properly installed."
    ))
  }

  plumber::plumb(file.path(api_dir, "api.R"))
}
