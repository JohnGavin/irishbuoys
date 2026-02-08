#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom dbplyr sql
#' @importFrom rlang .data
#' @importFrom stats complete.cases
#' @importFrom utils capture.output head tail
## usethis namespace: end
NULL

# Global variables for NSE (dplyr)
utils::globalVariables(c("time", "station_id", "max_time", "n"))
